# Database tier

Five single-replica Docker Swarm services on the overlay network `db_net`, each pinned to one node: MySQL, MongoDB and SQL Server on `softcraftscarlet`, PostgreSQL on `softcraftcassandra`, Redis on `softcraftgru`. MySQL, MongoDB, PostgreSQL and Redis keep their data on node-local volumes on their node; SQL Server keeps its data and config on NFS; the other four have no NFS mounts at all.

| Database | Swarm service (alias) | Image | Port (Swarm ingress) | Data volume → mount |
|---|---|---|---|---|
| MySQL | `softcraftdave` (`mysql`) | `mysql:8.0` | `3306` | `mysql_data_local` (scarlet) → `/var/lib/mysql` |
| MongoDB | `softcraftjerry` (`mongodb`) | `mongo:7` | `27017` | `mongodb_data_local` (scarlet) → `/data/db` |
| PostgreSQL | `softcraftmark` (`postgresql`) | `postgres:16` | `5432` | `postgresql_data_local` (cass) → `/var/lib/postgresql/data` |
| SQL Server | `softcraftjorge` (`sqlserver`) | `mcr.microsoft.com/mssql/server:2022-latest` (`MSSQL_PID=Developer`) | `1433` | `sqlserver_data_nfs` (NFS) → `/var/opt/mssql/data` |
| Redis | `softcraftron` (`redis`) | `redis:7-alpine` (AOF on) | `6379` | `redis_data_local` (gru) → `/data` |

The MySQL, MongoDB and PostgreSQL services also create a database named `appdb`.

| Item | Value |
|---|---|
| Terraform state | Terraform Cloud, org `softcraft`, workspace `homenet-database` (Local execution mode: the Docker context is on `medusa`) |
| Docker context | `murpheux-scarlet` |
| NFS export | `10.10.2.100:/System/Volumes/Data/Users/Shared/nfs_share/docker_volumes/database/<db>/{data,config}`, NFSv3, `rw,resvport,nolock,soft` |
| Placement | `local.db_nodes` in `main.tf`: `softcraftscarlet` (MySQL, MongoDB, SQL Server), `softcraftcassandra` (PostgreSQL), `softcraftgru` (Redis); restart delay 10 s |
| Service names | `softcraftdave` (MySQL), `softcraftjerry` (MongoDB), `softcraftmark` (PostgreSQL), `softcraftjorge` (SQL Server), `softcraftron` (Redis). Each keeps its former name (`mysql`, `mongodb`, `postgresql`, `sqlserver`, `redis`) as a `db_net` network alias, so existing connection strings keep resolving |
| Credentials | 1Password item `homenet-database` in vault `private`, referenced by `op.env` |

## Files

| Path | Tracked | Purpose |
|---|---|---|
| `main.tf` | yes | Network, the ten NFS volumes (`for_each` over `local.nfs_volumes`), module wiring |
| `modules/<db>/main.tf` | yes | One service per database, plus its Swarm secret |
| `variables.tf` | yes | Inputs, with validation |
| `op.env` | yes | `TF_VAR_*=op://private/homenet-database/<field>` references only |
| `Makefile` | yes | `check-secrets` / `plan` / `apply` wrappers |
| `scripts/import-tfvars-to-op.sh` | yes | One-time migration of `secrets.tfvars` into 1Password |
| `secrets.tfvars`, `plan.tfplan`, `main.tf.backup` | no | **Legacy; delete after migrating** (see below) |

## Credentials

| Variable | 1Password field | Delivered to the container as | Visible in `docker service inspect`? |
|---|---|---|---|
| `mysql_root_password` | `mysql-root-password` | Swarm secret `/run/secrets/mysql_root_password`, via `MYSQL_ROOT_PASSWORD_FILE` | No |
| `mongo_user` | `user` (shared) | `MONGO_INITDB_ROOT_USERNAME` | Yes (not secret) |
| `mongo_password` | `mongo-password` | Swarm secret `/run/secrets/mongodb_root_password`, via `MONGO_INITDB_ROOT_PASSWORD_FILE` | No |
| `postgres_user` | `user` (shared) | `POSTGRES_USER` | Yes (not secret) |
| `postgres_password` | `postgres-password` | Swarm secret `/run/secrets/postgresql_password`, via `POSTGRES_PASSWORD_FILE` | No |
| `sqlserver_sa_password` | `sqlserver-sa-password` | `MSSQL_SA_PASSWORD` env var | **Yes**: the mssql image has no `*_FILE` option |
| `redis_password` | `redis-password` | `requirepass` in a `redis.conf` Swarm secret at `/run/secrets/redis.conf` | No |

Each secret name ends in a hash of its value (`mysql_root_password_<12 hex>`). A changed value therefore creates a new secret, and `create_before_destroy` swaps it in before the old one is removed. The values are also stored in Terraform Cloud state, so keep that workspace's access restricted.

### When a password change takes effect

| Database | Behaviour |
|---|---|
| MySQL, MongoDB, PostgreSQL, SQL Server | The password is applied **only when the data directory is first initialised**. Changing it in 1Password and running `make apply` does **not** change the live password. Change it in the database first, then update 1Password so both match |
| Redis | `requirepass` is applied on every start. Changing it in 1Password and running `make apply` changes the live password at once, so update clients at the same time |

Rotation commands, run against each service:

```sql
-- MySQL
ALTER USER 'root'@'%' IDENTIFIED BY '<new>';
-- PostgreSQL
ALTER ROLE <postgres_user> WITH PASSWORD '<new>';
-- SQL Server
ALTER LOGIN sa WITH PASSWORD = '<new>';
```

```javascript
// MongoDB
db.getSiblingDB("admin").changeUserPassword("<mongo_user>", "<new>")
```

### Validation

`variables.tf` rejects:
- MySQL, MongoDB and PostgreSQL passwords shorter than 12 characters;
- SQL Server SA passwords that don't meet SQL Server's own rule (8+ characters from 3 of: uppercase, lowercase, digits, symbols);
- Redis passwords shorter than 12 characters, or containing quotes, backslashes or whitespace (it's written into `redis.conf`);
- usernames that aren't valid identifiers.

## Storage and placement

| Choice | Why |
|---|---|
| Each service pinned to one node (`local.db_nodes`) | A local volume exists only on its node, so the service must always run there. MySQL and MongoDB need `scarlet`: `gru` (Core 2 Duo) and `cass` lack x86-64-v2 / AVX, which `mysql:8.0` (Oracle Linux 9 base) and `mongo:7` require. PostgreSQL and Redis run on any x86-64 CPU, so they use the idle workers to take load off `scarlet` |
| Volumes created through each node's own daemon | `providers.tf` has `docker.gru` and `docker.cass` aliases (contexts `murpheux-gru`, `murpheux-cass`). The manager can only create volumes on itself; without the aliases, Docker would silently create an unmanaged volume on the worker |
| MySQL, MongoDB, PostgreSQL and Redis data on **local** volumes | The NFS export is `-mapall=nobody`: every client, root included, acts as `nobody`. Each of these images `chown`s its data directory at startup, which fails over this export, so the task exits and Swarm restarts it. PostgreSQL also refuses a data directory it doesn't own. Their NFS data directories were empty: none had ever initialised |
| SQL Server data stays on NFS | It already holds data, and the mssql image runs as uid 10001 without `chown`ing its directory |
| No config volumes for MySQL, MongoDB, PostgreSQL, Redis | Docker copies an image directory's permissions onto an empty volume mounted over it. Over the `-mapall=nobody` export that `chmod` fails (`failed to chmod on /var/lib/docker/volumes/mysql_config_nfs/_data: permission denied`), and Swarm rejects the task. The config directories were empty, and dropping them also means these databases no longer depend on `medusa` being up |
| `network = docker_network.db_net.id` | `networks_advanced.id` must be the network **ID**. Passing the name made every plan replace all five services |
| `restart_policy` delay 10 s, window 60 s | A failing service retries every 10 s instead of looping as fast as Docker can restart it |

Consequences:
- **No failover.** If a node is down, the databases pinned to it are down; Swarm can't move them, because their data is local to that node.
- **Moving a database to another node starts it empty.** Change `local.db_nodes`, then dump and restore the data. Terraform creates a new empty volume on the target node.
- **Back up every database node.** The data lives only in Docker volumes on its node (`/var/lib/docker/volumes/<name>_local`). Use `mysqldump`, `pg_dumpall`, `mongodump` and Redis AOF copies to the NFS share or MinIO.

## Moving PostgreSQL to `cass` and Redis to `gru`

Both start **empty** on their new node: the new volumes are separate from the `scarlet` volumes they used before.

1. **Keep anything you've stored since 2026-11-04** (skip if nothing was written). Dumps are written on `medusa`:
   ```zsh
   docker --context=murpheux-scarlet exec "$(docker --context=murpheux-scarlet ps -qf name=softcraftmark)" sh -c 'pg_dumpall -U "$POSTGRES_USER"' > ~/AI_Workspace/Work_Files/postgresql-$(date +%F).sql
   ```
   Redis is a cache here, so its data is usually expendable. Ask before relying on it.
2. **Plan.** Expect a new `docker_volume.postgresql_data` (on `cass`) and `docker_volume.redis_data` (on `gru`), the `postgresql` and `redis` services updated in place, and the old `docker_volume.local["postgresql_data"]` / `["redis_data"]` on `scarlet` destroyed:
   ```zsh
   cd ~/AI_Workspace/Projects/HomeNet/database && op run --env-file=op.env -- terraform plan -input=false -no-color | grep -E '^  # |^Plan:'
   ```
3. **Apply in two steps.** A plain apply would try to delete the old `scarlet` volumes while the running tasks still use them, and time out (`last state: 'in_use'`). Move the services first, then delete:
   ```zsh
   op run --env-file=op.env -- terraform apply -input=false -auto-approve -target=module.postgresql -target=module.redis
   ```
   ```zsh
   make apply
   ```
4. **Verify:**
   ```zsh
   for s in softcraftmark softcraftron; do echo "== $s"; docker --context=murpheux-scarlet service ps "$s" --format '{{.Node}} {{.CurrentState}} {{.Error}}' | head -2; done
   ```
   Expect `softcraftcassandra Running` and `softcraftgru Running`.
5. **Restore** the step 1 dump, if you made one:
   ```zsh
   docker --context=murpheux-cass exec -i "$(docker --context=murpheux-cass ps -qf name=softcraftmark)" sh -c 'psql -U "$POSTGRES_USER" -d postgres' < ~/AI_Workspace/Work_Files/postgresql-YYYY-MM-DD.sql
   ```

## Rolling out the storage and placement fix

1. **Check for stray data on `gru` and `cass`.** Without a placement constraint, tasks that ran there used auto-created *local* volumes with the old `*_data_nfs` names. Any data in them stays there, but the new deployment won't use it:
   ```zsh
   for c in $(docker context ls --format '{{.Name}}'); do echo "== $c"; docker --context="$c" volume ls --filter name=_data_nfs --format '{{.Name}}' 2>/dev/null; done
   ```
   If a volume on `gru` or `cass` holds a database you need, dump it before continuing.
2. **Confirm the diagnosis** (optional). This shows the last task errors and each database's log:
   ```zsh
   for s in softcraftdave softcraftjerry softcraftmark softcraftjorge softcraftron; do echo "===== $s"; docker --context=murpheux-scarlet service ps "$s" --no-trunc --format '{{.Node}} {{.CurrentState}} {{.Error}}' | head -4; docker --context=murpheux-scarlet service logs --tail 5 "$s" 2>&1 | tail -5; done
   ```
   Expect `chown: ... Operation not permitted`, PostgreSQL's `data directory ... has wrong ownership`, or `Illegal instruction` / `CPU does not support x86-64-v2` on `gru` or `cass`.
3. **Plan:**
   ```zsh
   cd ~/AI_Workspace/Projects/HomeNet/database && make check-secrets && make plan
   ```
   Expected:
   - 4 new `docker_volume.local[...]` (`*_data_local`);
   - the old `*_data_nfs` and `*_config_nfs` volume definitions for MySQL, MongoDB, PostgreSQL and Redis destroyed. This removes only the Docker volume definitions; the NFS directories on `medusa` are untouched, and they're empty;
   - the services updated in place (placement, restart policy, mounts);
   - `sqlserver` data and config volumes unchanged.

   To list exactly which resources change: `op run --env-file=op.env -- terraform plan -input=false -no-color | grep -E '^  # '`
4. **Apply.** `make apply` doesn't prompt, so read the plan first:
   ```zsh
   make apply
   ```
   If it stops with `volume is in use`, stopped crash-loop containers on `scarlet` still reference an old volume. Remove only those, then apply again:
   ```zsh
   for v in mysql_data_nfs mongodb_data_nfs postgresql_data_nfs redis_data_nfs mysql_config_nfs mongodb_config_nfs postgresql_config_nfs redis_config_nfs; do docker --context=murpheux-scarlet ps -aq --filter volume="$v" --filter status=exited | xargs docker --context=murpheux-scarlet rm; done
   ```
5. **Verify.** After a minute, every service should show `1/1`, with recent tasks on `softcraftscarlet` and no new restarts:
   ```zsh
   docker --context=murpheux-scarlet service ls --filter name=softcraftdave --filter name=softcraftjerry --filter name=softcraftmark --filter name=softcraftjorge --filter name=softcraftron
   ```
   ```zsh
   for s in softcraftdave softcraftjerry softcraftmark softcraftjorge softcraftron; do echo "== $s"; docker --context=murpheux-scarlet service ps "$s" --format '{{.Node}} {{.CurrentState}} {{.Error}}' | head -3; done
   ```
6. **Verify the passwords no longer appear in the service specs** (this prints only the variable names):
   ```zsh
   for s in softcraftdave softcraftjerry softcraftmark softcraftron; do printf '%s: ' "$s"; docker --context=murpheux-scarlet service inspect "$s" --format '{{range .Spec.TaskTemplate.ContainerSpec.Env}}{{println .}}{{end}}{{range .Spec.TaskTemplate.ContainerSpec.Args}}{{println .}}{{end}}' | cut -d= -f1 | tr '\n' ' '; echo; done
   ```
7. **Delete the legacy plaintext files.** `plan.tfplan` is a saved plan from June and contains **all five passwords in plaintext**:
   ```zsh
   rm ~/AI_Workspace/Projects/HomeNet/database/secrets.tfvars ~/AI_Workspace/Projects/HomeNet/database/plan.tfplan ~/AI_Workspace/Projects/HomeNet/database/main.tf.backup
   ```

Because these four databases never initialised, they start **fresh**. The passwords from 1Password are applied on this first start, along with the `appdb` database.

`scripts/import-tfvars-to-op.sh` created the original item from `secrets.tfvars`. It defaults to an item named `database` with separate `mongo-user` / `postgres-user` fields; `op.env` now uses your `homenet-database` item and its shared `user` field instead.

## Operations

| Target | What it does |
|---|---|
| `make init` | `terraform init` |
| `make check-secrets` | Shape of each 1Password value (length, whitespace, hash-like, duplicates); values never printed |
| `make plan` | `terraform plan` through `op run`. No saved plan file |
| `make apply` | `terraform apply -auto-approve` through `op run`. **No confirmation prompt**: read `make plan` first |
| `make lint` | `terraform fmt`, `validate`, `shellcheck` |
| `make destroy-services` | Removes the five services and their secrets, **keeps every volume** and the network. The next `make apply` starts the databases on their existing data. Prompts for `yes` |
| `make destroy` | Removes everything, **including the local data volumes: MySQL, MongoDB, PostgreSQL and Redis data is deleted.** The SQL Server NFS directories on `medusa` stay. Prompts for `yes`. Dump the databases first |

Health checks:

```zsh
docker --context=murpheux-scarlet service ls --filter name=softcraftdave --filter name=softcraftjerry --filter name=softcraftmark --filter name=softcraftjorge --filter name=softcraftron
```

```zsh
docker --context=murpheux-scarlet service ps softcraftron --no-trunc | head -3
```

## Known issues (not yet changed)

These need a maintenance window or a decision about clients, so they're documented rather than applied:

| Issue | Risk | Recommendation |
|---|---|---|
| SQL Server data on NFS `soft,nolock` | An NFS timeout (for example `medusa` asleep or rebooting) returns I/O errors that can corrupt SQL Server data files. Microsoft doesn't support SQL Server on NFSv3 | Dump it (`BACKUP DATABASE`) and move it to a local volume like the others, in a maintenance window |
| Data on one node, no backups | Losing `scarlet`'s disk loses all five databases | Schedule dumps to the NFS share or MinIO (`mysqldump`, `pg_dumpall`, `mongodump`, `BACKUP DATABASE`, Redis AOF copy) |
| All five ports are published on the Swarm **ingress** | Every database is reachable on every node's IP from the whole LAN (S-10 in the root README) | Remove published ports and have clients join `db_net`, or use `publish_mode = "host"` with a placement constraint. This changes client connection strings |
| Images float (`mysql:8.0`, `mongo:7`, `postgres:16`, `2022-latest`, `redis:7-alpine`) | A restart can pull a newer minor or patch release unannounced. MySQL doesn't support downgrades, so pinning to an *older* patch than the one running would break it | Pin to the digest Swarm is running now. Read it with `docker --context=murpheux-scarlet service inspect <svc> --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}'` |
| No healthchecks or `update_config` | Rolling updates can't detect a failed start | Add `healthcheck` (for example `pg_isready`, `mysqladmin ping`, `redis-cli ping`) and `update_config { failure_action = "rollback" }` |
| `.terraform.lock.hcl` is git-ignored repo-wide | Provider versions aren't reproducible across machines | Remove `**/.terraform.lock.hcl` from the root `.gitignore` and commit the lock files |
| SQL Server SA password is an env var | Visible in `docker service inspect` | Accepted for now: no `*_FILE` support. A wrapper entrypoint shipped as a `docker_config` could read a secret instead |
| `outputs.tf` is empty and git-ignored | No outputs for scripts or other stacks | Add service names and ports once `**/outputs.tf` is un-ignored (T-1) |
