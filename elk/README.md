# ELK stack

Elasticsearch, Kibana and Filebeat **8.19.23** as Docker Swarm services on the overlay network `elk_net`, with security enabled. Filebeat ships every node's container logs straight to Elasticsearch. Logstash is optional and off.

| Service | Swarm name | Node | Port (ingress) | Data |
|---|---|---|---|---|
| Elasticsearch | `softcraftotto` (alias `elasticsearch`) | `softcraftscarlet` | `9200` | `es_data` (scarlet), 1 GiB heap, 2 GiB limit |
| Kibana | `softcraftcarl` | `softcraftgru` | `5601` | `kibana_data_local` (gru) |
| Filebeat | `softcraftphil` | **global** (every node) | — | none (reads `/var/lib/docker/containers` read-only) |
| Logstash (optional) | `softcraftjerrry` | `softcraftscarlet` | — | `logstash_pipeline`; `enable_logstash = true` to deploy |

| Item | Value |
|---|---|
| Terraform state | Terraform Cloud, org `softcraft`, workspace `homenet-elk` (Local execution mode) |
| Credentials | 1Password item `homenet-elk` (vault `private`), referenced by `op.env`; created with generated values by `make create-secrets` |
| Providers | `kreuzwerker/docker` (services, secrets, volumes), `elastic/elasticstack` (`kibana_system` password, `filebeat_writer` role and user) |
| Version | `elastic_version` in `variables.tf`, one value for all images; must be an exact `8.19.x` |

## Security

| Identity | Used by | How it's set |
|---|---|---|
| `elastic` (superuser) | You, and the `elasticstack` provider | `ELASTIC_PASSWORD_FILE` from a Swarm secret: the bootstrap password on the first secured start |
| `kibana_system` (built-in) | Kibana. Kibana 8 refuses `elastic` | `elasticstack_elasticsearch_security_system_user` |
| `filebeat_writer` (role and user) | Filebeat | `elasticstack_elasticsearch_security_role` / `_user`. Cluster: `monitor`, `read_ilm`, `read_pipeline`, `manage_ilm`, `manage_index_templates`; indices `filebeat-*`: `create_doc`, `view_index_metadata`, `auto_configure`, `manage`. No read access to other indices |

- `kibana.yml` and `filebeat.yml` are rendered from `config/` with `templatefile()` and ship as **Swarm secrets**, because they contain passwords. Nothing comes from host paths.
- HTTP is plain on the LAN (`xpack.security.http.ssl.enabled=false`) but authenticated. Single-node mode needs no transport TLS.
- Passwords are also stored in Terraform Cloud state (`homenet-elk`), so keep that workspace's access restricted.

| 1Password field | Variable |
|---|---|
| `elastic-password` | `TF_VAR_elastic_password` |
| `kibana-system-password` | `TF_VAR_kibana_system_password` |
| `kibana-encryption-key` | `TF_VAR_kibana_encryption_key` (encrypted saved objects, sessions, reports) |
| `filebeat-password` | `TF_VAR_filebeat_password` |

## What changed from the 7.17 setup

| Before | Now |
|---|---|
| 7.17.18 (out of support) | 8.19.23, one variable |
| `xpack.security.enabled=false`, `9200` open to the LAN | Security on; `elastic` / `kibana_system` / `filebeat_writer` from 1Password |
| Kibana and Filebeat pointed at `elasticsearch:9200`, a name that didn't resolve (the service is `softcraftotto`) | `elasticsearch` is now a network alias of the Elasticsearch service |
| Filebeat config bind-mounted from a host path that only existed on one node | Rendered config as a Swarm secret on every node; Filebeat runs as root (read-only mounts) so it can read the logs |
| `container` input | `filestream` with the `container` parser, plus Docker and host metadata |
| Kibana on any node, with a volume created only on `scarlet` | Pinned to `gru` with a volume created there |
| Logstash always on, with no pipeline | Optional, off |
| Backend blocks in every module; networks passed by name; `cloud` block pointing at `homenet-prometheus` | One `cloud` block (`homenet-elk`); networks by ID |

## First deployment

1. **Back up the existing data.** The 7.17 → 8.19 upgrade of `es_data` can't be undone. This streams the volume from `scarlet` into a tarball on `medusa`:
   ```zsh
   docker --context=murpheux-scarlet run --rm -v es_data:/src:ro alpine tar -C /src -czf - . > ~/AI_Workspace/Work_Files/es_data-7.17-$(date +%F).tgz
   ```
2. **Create the secrets** (generated, never shown), and check them:
   ```zsh
   cd ~/AI_Workspace/Projects/HomeNet/elk && make create-secrets && make check-secrets
   ```
3. **Initialise Terraform Cloud** (installs the new `elasticstack` provider too):
   ```zsh
   make init
   ```
   Then set the new workspace to **Local** execution: `https://app.terraform.io/app/softcraft/workspaces/homenet-elk/settings/general` → Execution Mode → Local. In Remote mode, plans fail with `Error loading Docker context`.
4. **Start Elasticsearch on its own first.** The `elasticstack` provider needs a running Elasticsearch to create users. `make bootstrap` applies only that module, then `scripts/wait-for-service.sh` polls `http://scarlet:9200` for up to 15 minutes, printing the task state every 10 s. If it doesn't come up, the script prints the task errors and the last 40 log lines. To save time, pull the image first: `docker --context=murpheux-scarlet pull docker.elastic.co/elasticsearch/elasticsearch:8.19.23`.
   ```zsh
   make bootstrap
   ```
   On the first start, 8.19 upgrades any 7.17 indices in `es_data`. Follow it with `docker --context=murpheux-scarlet service logs -f softcraftotto`.
5. **Deploy the rest:**
   ```zsh
   make plan
   ```
   ```zsh
   make apply
   ```
6. **Verify.** The cluster health uses the `elastic` password from 1Password, without printing it:
   ```zsh
   op run --env-file=op.env -- sh -c 'curl -s -u "elastic:$TF_VAR_elastic_password" http://scarlet:9200/_cluster/health?pretty' | grep -E '"status"|number_of_nodes'
   ```
   ```zsh
   for s in softcraftotto softcraftcarl softcraftphil; do echo "== $s"; docker --context=murpheux-scarlet service ps "$s" --format '{{.Node}} {{.CurrentState}} {{.Error}}' | head -3; done
   ```
   Then log in to Kibana at `http://gru:5601` as `elastic`, and check Discover for a `filebeat-*` data view.
7. **Delete the old MinIO credentials:** this stack no longer uses MinIO.
   ```zsh
   rm ~/AI_Workspace/Projects/HomeNet/elk/backend.tfvars
   ```

## Operations

| Target | What it does |
|---|---|
| `make create-secrets` | One-time: creates `homenet-elk` with four generated values (`scripts/create-op-item.sh`; values on stdin only) |
| `make check-secrets` | Shape of each value; never printed |
| `make init` | `terraform init -input=false` |
| `make bootstrap` | First deploy only: applies just Elasticsearch and waits for it to answer HTTP (`scripts/wait-for-service.sh`; prints errors and logs on timeout) |
| `make wait-es` | Re-checks Elasticsearch (60 s) and prints the same diagnostics, without applying |
| `make plan` / `make apply` | Through `op run`; `apply` is `-auto-approve` |
| `make destroy` | Removes everything, **including `es_data` (all indices)**. Prompts for `yes` |

Changing a template or password creates a new content-hashed secret and rolls the service. To rotate `elastic`'s password after the first start, change it in Elasticsearch (`POST /_security/user/elastic/_password`), then update 1Password: `ELASTIC_PASSWORD_FILE` is only a bootstrap value.

**Upgrading:** set `elastic_version` to a newer `8.19.x` patch and `make apply`. All images move together. Elasticsearch restarts first, because the other modules depend on it.

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| `make plan` fails connecting to `10.10.2.80:9200` on the first deploy | Elasticsearch isn't up yet: run `make bootstrap` first |
| `make bootstrap` times out | Read the diagnostics it prints: `Preparing` for minutes means the image is still downloading; an exception in the log means Elasticsearch failed to start. The service stays in place, so `make wait-es` and `docker service logs softcraftotto` keep working |
| Kibana logs `Unable to retrieve version information` or `security_exception` | `kibana_system`'s password isn't set yet (apply order), or 1Password changed without an apply |
| Kibana exits at once on `gru` (`Illegal instruction`, `x86-64-v2`) | `gru`'s CPU can't run this build: set `kibana = "softcraftscarlet"` in `local.elk_nodes` and apply |
| Filebeat on `cass` rejected with `network sandbox join failed` | The same overlay problem as `database/` on `cass`; it's a node issue, not the config |
| `Rejected` / `No such image` | Check `elastic_version` exists for all four images on `docker.elastic.co` |
