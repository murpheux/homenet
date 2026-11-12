# Pi-hole (dns2)

Terraform-managed Pi-hole container, `softcraftjim`, running on `scarlet` as `dns2` (`10.10.2.7`). It is the **nebula-sync primary**: its gravity, group and DNS config are synced hourly to `dns` (`10.10.2.9`), the secondary Pi-hole, by a companion `nebula-sync` container deployed in the same stack.

| Item | Value |
|---|---|
| Container | `docker_container.pihole` (`main.tf`), image `pihole/pihole:latest` |
| Host | `scarlet` (provider context `murpheux-scarlet`, `providers.tf`) |
| Network | `pihole_ipvlan` — ipvlan (`l2` mode) on parent interface `enp3s0f0`, IPv4 `10.10.2.0/24` + IPv6 ULA `fd00:10:10:2::/64` |
| Static address | `10.10.2.7` / `fd00:10:10:2::5` (`dns2`) |
| Ports | `53/tcp`, `53/udp` (DNS), `80/tcp`, `443/tcp` (admin/API) |
| Config volumes | `/home/murpheux/HomeNet/pihole/{etc-pihole,etc-dnsmasq.d,log-pihole}` on `scarlet` (bind mounts, not Terraform-managed) |
| Terraform state | Terraform Cloud, org `softcraft`, workspace `homenet-pihole` (`terraform.tf`) |
| Credentials | 1Password vault `private`, item `pi-hole`, referenced by `op.env` |

## nebula-sync

`nebula_sync.tf` deploys [`nebula-sync`](https://github.com/lovelaze/nebula-sync) (`ghcr.io/lovelaze/nebula-sync`) alongside Pi-hole on the same `pihole_ipvlan` network, attached directly so it can reach `dns2` — an ipvlan parent (`scarlet`) cannot reach its own ipvlan children, so a bridge-networked container on `scarlet` couldn't talk to `dns2` over the ipvlan address.

| Item | Value |
|---|---|
| Direction | `dns2` (`10.10.2.7`, primary) → `dns` (`10.10.2.9`, replica) |
| Image | Pinned release tag, `var.nebula_sync_image` (default `ghcr.io/lovelaze/nebula-sync:v0.11.3`). Bump deliberately after reading the release notes |
| Schedule | `var.nebula_sync_cron`, default `0 * * * *` (hourly, `America/Edmonton`) |
| Transport | HTTPS to both Pi-holes' API (`443`), not HTTP (`8080`) — keeps the admin app password off the LAN in cleartext |
| TLS | `CLIENT_SKIP_TLS_VERIFICATION=true` — both Pi-holes serve self-signed certs, encrypted but unauthenticated. Remove once both serve a cert from a trusted internal CA |
| Auth | App passwords (`var.pihole_app_password_primary` / `_replica`), not the admin password — both Pi-holes have 2FA on and nebula-sync can't supply a TOTP code. `dns` (the replica) additionally needs `webserver.api.app_sudo = true` set in its own Pi-hole config for nebula-sync to apply changes there |
| Sync mode | Selective (`FULL_SYNC=false`), gravity + groups + DNS + resolver config, **not** `webserver.api` (no full Teleporter import) — a full sync would carry `dns2`'s admin password, TOTP secret, app password and `app_sudo` flag onto `dns` and break its login |
| DNS exclusions | `SYNC_CONFIG_DNS_EXCLUDE=interface,listeningMode` — `dns2`'s values (`eth0`, `ALL`) are container-specific env overrides, not meant for the replica |

## Design

| Choice | Why |
|---|---|
| ipvlan network, not bridge | Pi-hole needs a real LAN-routable address (`10.10.2.7`) to serve DNS and DHCP-adjacent traffic directly; a bridge would require host-level port mapping tricks for port 53 and would break client-IP visibility in Pi-hole's logs |
| No `NET_ADMIN` capability | Default Docker capabilities only. `NET_ADMIN` is needed solely for Pi-hole's built-in DHCP server; DHCP is served by `router1`, and granting `NET_ADMIN` on an ipvlan LAN interface would let the container spoof other LAN addresses |
| Private in-memory `/tmp` (`tmpfs`) | Never shares the host's `/tmp` — avoids socket collisions and symlink-race risk from other containers/processes on `scarlet` |
| App passwords for nebula-sync, not the admin password | Both Pi-holes have 2FA enabled; app-password sessions skip 2FA, which a cron-driven sync tool can't satisfy interactively |
| Selective sync, not `FULL_SYNC` | Keeps `webserver.api` (admin password, TOTP secret, app password, `app_sudo`) local to each Pi-hole so the replica's own login/API auth is never overwritten |
| Pi-hole admin password validated non-empty | `variables.tf` fails fast with a clear message if Terraform isn't run through `op run --env-file=op.env` |
| App passwords forbid `\|` and `,` | Those are nebula-sync's `PRIMARY=url\|password` / `REPLICAS=...` delimiters; a password containing either would corrupt the env value it's interpolated into |

## Credentials

| `op.env` variable | 1Password reference | Used for |
|---|---|---|
| `TF_VAR_pihole_password` | `op://private/pi-hole/password` | Pi-hole web/API admin password (`PIHOLE_WEBPASSWORD`, `FTLCONF_webserver_api_password`) |
| `TF_VAR_pihole_app_password_primary` | `op://private/pi-hole/app-password-dns2` | nebula-sync auth against `dns2` (primary) |
| `TF_VAR_pihole_app_password_replica` | `op://private/pi-hole/app-password-dns` | nebula-sync auth against `dns` (replica) |

## Operations

| Target | What it does |
|---|---|
| `make init` | `terraform init -input=false` |
| `make fmt` / `make validate` | `terraform fmt -recursive` / `terraform validate` |
| `make lint` | `fmt` + `validate` + `shellcheck scripts/*.sh` |
| `make check-secrets` | Shape of the `op.env` secrets (length, whitespace, hash-like, duplicates) via `describe-secrets.sh`; values never printed |
| `make check-auth` | Confirms `dns2` and `dns` both accept their app passwords, via `scripts/check-pihole-auth.sh` (logs in and immediately logs out, so it doesn't burn one of Pi-hole's limited API sessions) |
| `make plan` | `terraform plan` through `op run`. No saved plan file — a `tfplan` would contain the admin password in plaintext |
| `make apply` | `terraform apply -auto-approve` through `op run` |
| `make destroy` | Removes `dns2`, `nebula-sync` and the `pihole_ipvlan` network. Prompts for `yes`. Takes `dns2` offline — clients fall back to `dns` (`10.10.2.9`). Bind-mounted config under `/home/murpheux/HomeNet/pihole` on `scarlet` is kept |

## Known issues

| Issue | Recommendation |
|---|---|
| Pi-hole image floats (`latest`) | Pin to the digest Docker runs after the first deploy: `docker --context=murpheux-scarlet inspect softcraftjim --format '{{.Image}}'` |
| Self-signed TLS between Pi-hole and nebula-sync | Encrypted but unauthenticated (`CLIENT_SKIP_TLS_VERIFICATION=true`). Issue both Pi-holes a cert from a trusted internal CA and drop the skip-verify flag |
| Config volumes are host bind mounts, not Terraform-managed | `/home/murpheux/HomeNet/pihole/*` on `scarlet` survives `make destroy` but isn't tracked by state; back it up separately |
