# Monitoring stack

Prometheus, Grafana, Loki and cAdvisor as Docker Swarm services on the overlay network `monitoring_network`, placed on the worker nodes to keep load off `scarlet`.

| Service | Swarm name | Image | Node | Port (ingress) | Data |
|---|---|---|---|---|---|
| Prometheus | `softcraftbelle` | `prom/prometheus:latest` | `softcraftcassandra` | `9090` | `prometheus_data_local` (cass), 30 d / 10 GB retention |
| Grafana | `softcraftbob` | `grafana/grafana:latest` | `softcraftgru` | `3000` | `grafana_data_local` (gru) |
| Loki | `softcraftmel` | `grafana/loki:3.0.0` | `softcraftgru` | `3100` | `loki_data_local` (gru) |
| cAdvisor | `softcraftchow` | `gcr.io/cadvisor/cadvisor:latest` | **global** (every node) | `8080` | none |

| Item | Value |
|---|---|
| Terraform state | Terraform Cloud, org `softcraft`, workspace `homenet-prometheus` (Local execution mode: the Docker contexts and `op run` only exist on `medusa`) |
| Credentials | 1Password item `homenet-grafana` (vault `private`), referenced by `op.env` |
| Grafana datasources | `Prometheus` (default) and `Loki`, managed by the `grafana` provider (admin basic auth, or a service-account token if `TF_VAR_grafana_auth_token` is set) |
| Placement | `local.monitoring_nodes` in `main.tf` |

## Design

| Choice | Why |
|---|---|
| Configs as Swarm configs | `config/prometheus.yaml` and `config/config.yaml` (Loki) ship from the repo instead of host bind mounts under `/home/murpheux/HomeNet/...`. The services can run on any node, and a config change creates a new content-hashed config and rolls the service |
| Node-local data volumes, created through each node's daemon | Provider aliases `docker.gru` / `docker.cass` in `main.tf` create the volumes on the node that runs the service. Same pattern as `database/` |
| Off `scarlet` | `scarlet` runs MySQL, MongoDB, SQL Server and agentgateway. These images are plain amd64 builds, so the x86-64-v1 workers run them |
| cAdvisor `global` | One task per node; Prometheus scrapes each one through `tasks.softcraftchow`. Port `8080` on the ingress reaches a random node's cAdvisor (UI only) |
| No `--web.enable-lifecycle` | Without authentication it let anyone on the LAN `POST /-/quit`. Config reloads come from the service update `make apply` does |
| Grafana admin password as a Swarm secret | Read through `GF_SECURITY_ADMIN_PASSWORD__FILE`, so it's not in `docker service inspect` |
| Admin email from 1Password | It's personal information and was committed as a variable default |
| `networks_advanced.id` gets the network **ID** | Passing the name made every apply replace every service |

## Credentials

| `op.env` variable | 1Password reference | Used for |
|---|---|---|
| `TF_VAR_grafana_admin_password` | `op://private/homenet-grafana/grafana-admin-password` | Grafana admin (first start only) |
| `TF_VAR_grafana_auth_token` (optional, commented out) | `op://private/homenet-grafana/auth-token` | `grafana` provider. Unset: the provider logs in with the admin user and password, which works on a brand-new Grafana |
| `TF_VAR_grafana_admin_email` | `op://private/homenet-grafana/grafana-admin-email` | Grafana admin (first start only) |

`GF_SECURITY_ADMIN_*` apply only when Grafana's database is first created. Afterwards, change the admin password in Grafana itself and update 1Password to match.

## First deployment

1. **Move the secrets into 1Password.** Values travel through stdin only and are never printed:
   ```zsh
   cd ~/AI_Workspace/Projects/HomeNet && bash scripts/import-tfvars-to-op.sh private homenet-grafana prometheus/secrets.tfvars
   ```
   Then add the admin email. It isn't secret, so an argument is fine:
   ```zsh
   op item edit homenet-grafana --vault private 'grafana-admin-email[text]=<your-email>'
   ```
   `secrets.tfvars` also contains `prometheus_admin_password` (a bcrypt hash), which nothing uses. It's imported as an extra field and is harmless.
2. **Check every reference resolves:**
   ```zsh
   cd prometheus && make check-secrets
   ```
3. **Initialise Terraform Cloud and migrate the state.** If a local `terraform.tfstate` exists from an earlier run, `terraform init` offers to copy it into the `homenet-prometheus` workspace; answer `yes`. It needs a terminal, so run it without `-input=false`:
   ```zsh
   terraform init
   ```
   Then set the workspace to **Local** execution (`https://app.terraform.io/app/softcraft/workspaces/homenet-prometheus/settings/general` → Execution Mode → Local). In Remote mode, plans run on HCP Terraform's servers and fail with `Error loading Docker context`.
4. **Copy existing data, if you want to keep it** (optional). Earlier deployments kept Prometheus and Grafana data in bind mounts on `scarlet`. Create the new volumes first, copy into them over Docker contexts (no SSH needed), then deploy:
   ```zsh
   op run --env-file=op.env -- terraform apply -input=false -auto-approve -target=docker_volume.prometheus_data -target=docker_volume.grafana_data -target=docker_volume.loki_data
   ```
   ```zsh
   docker --context=murpheux-scarlet run --rm -v /home/murpheux/HomeNet/grafana/grafana-data:/src:ro alpine tar -C /src -cf - . | docker --context=murpheux-gru run --rm -i -v grafana_data_local:/dst alpine tar -C /dst --numeric-owner -xpf -
   ```
   ```zsh
   docker --context=murpheux-scarlet run --rm -v /home/murpheux/HomeNet/prometheus/prometheus-data:/src:ro alpine tar -C /src -cf - . | docker --context=murpheux-cass run --rm -i -v prometheus_data_local:/dst alpine tar -C /dst --numeric-owner -xpf -
   ```
   Skip this to start with an empty TSDB and a fresh Grafana. The bind-mount directories on `scarlet` aren't touched either way.
5. **Plan and apply.** `make apply` doesn't prompt:
   ```zsh
   make plan
   ```
   ```zsh
   make apply
   ```
   Terraform waits for Grafana to be healthy (`converge_config`) before creating the datasources. The `grafana` provider logs in as the admin user Terraform created, so no token is needed on a fresh install. A `401 invalid API key` means `TF_VAR_grafana_auth_token` is set to a token from a different Grafana database: comment it out in `op.env`, or replace it with a token created in this Grafana.
6. **Verify:**
   ```zsh
   for s in softcraftbelle softcraftbob softcraftmel softcraftchow; do echo "== $s"; docker --context=murpheux-scarlet service ps "$s" --format '{{.Node}} {{.CurrentState}} {{.Error}}' | head -3; done
   ```
   Then check Prometheus's targets at `http://cass:9090/targets`: `cadvisor` should show one target per node.
7. **Delete the plaintext files** once the plan works without them:
   ```zsh
   rm ~/AI_Workspace/Projects/HomeNet/prometheus/backend.tfvars ~/AI_Workspace/Projects/HomeNet/prometheus/secrets.tfvars ~/AI_Workspace/Projects/HomeNet/prometheus/keep.bak ~/AI_Workspace/Projects/HomeNet/prometheus/terraform.tfstate ~/AI_Workspace/Projects/HomeNet/prometheus/terraform.tfstate.backup
   ```
   The two local `terraform.tfstate*` files hold Grafana's admin password in plaintext; delete them only after `make plan` works against Terraform Cloud. `backend.tfvars` holds MinIO keys this stack no longer uses.

## Operations

| Target | What it does |
|---|---|
| `make init` | `terraform init -input=false` (the first, migrating init is interactive: see step 3) |
| `make check-secrets` | Shape of each 1Password value; never printed |
| `make plan` / `make apply` | Through `op run`; `apply` is `-auto-approve` |
| `make destroy` | Removes everything, **including the Prometheus, Grafana and Loki data volumes**. Prompts for `yes` |

## Known issues

| Issue | Recommendation |
|---|---|
| Images float (`latest`) | Pin to the digests Swarm runs after the first deploy: `docker --context=murpheux-scarlet service inspect <svc> --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}'` |
| Prometheus, Grafana, Loki and cAdvisor UIs have no authentication beyond Grafana's login | `config/web-config.yml` (placeholder hash) is a starting point for Prometheus basic auth, but it isn't wired in: the Grafana datasource, the health check and the self-scrape would all need the credentials |
| cAdvisor mounts `/`, `/sys`, `/var/lib/docker` and the Docker socket (read-only) | Standard for cAdvisor, but it gives broad host visibility. Consider a docker-socket-proxy |
| Old Loki volume `loki_data_volume` on `scarlet` | Not managed by Terraform (left over from the old layout). Remove it when unneeded: `docker --context=murpheux-scarlet volume rm loki_data_volume` |
