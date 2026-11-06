# nebula_sync.tf
#
# Replicates Pi-hole config from dns2 (primary, this stack) to dns (replica).
# Attached to the ipvlan network: an ipvlan parent host cannot reach its own
# ipvlan children, so a bridge-networked container on scarlet couldn't reach dns2.

# Both Pi-holes serve the API on 443 (HTTPS) and 8080 (HTTP), not 80
# (webserver.port = 8080o,443os). HTTPS keeps the admin password off the LAN in cleartext.
locals {
  pihole_primary_url = "https://10.10.2.7" # dns2 (docker_container.pihole)
  pihole_replica_url = "https://10.10.2.9" # dns
  nebula_sync_ip     = "10.10.2.201"
}

resource "docker_image" "nebula_sync" {
  name = var.nebula_sync_image
}

resource "docker_container" "nebula_sync" {
  name     = "nebula-sync"
  hostname = "nebula-sync"
  image    = docker_image.nebula_sync.image_id
  restart  = "unless-stopped"

  env = [
    "TZ=America/Edmonton",
    "PRIMARY=${local.pihole_primary_url}|${var.pihole_app_password_primary}",
    "REPLICAS=${local.pihole_replica_url}|${var.pihole_app_password_replica}",
    "CRON=${var.nebula_sync_cron}",
    "RUN_GRAVITY=true",

    # Selective sync, not FULL_SYNC: a Teleporter import can carry webserver.api (admin
    # password, TOTP secret, app password, app_sudo) and break the replica's login.
    # Selective sync has no webserver section, so each Pi-hole keeps its own auth.
    "FULL_SYNC=false",
    "SYNC_GRAVITY_GROUP=true",
    "SYNC_GRAVITY_AD_LIST=true",
    "SYNC_GRAVITY_AD_LIST_BY_GROUP=true",
    "SYNC_GRAVITY_DOMAIN_LIST=true",
    "SYNC_GRAVITY_DOMAIN_LIST_BY_GROUP=true",
    "SYNC_GRAVITY_CLIENT=true",
    "SYNC_GRAVITY_CLIENT_BY_GROUP=true",
    "SYNC_CONFIG_DNS=true",
    # dns2's values are container-specific (eth0 inside docker, env-forced listening mode).
    "SYNC_CONFIG_DNS_EXCLUDE=interface,listeningMode",
    "SYNC_CONFIG_RESOLVER=true",
    # Pi-hole's self-signed certs. Encrypted but unauthenticated: remove once both
    # Pi-holes serve a cert from a trusted internal CA.
    "CLIENT_SKIP_TLS_VERIFICATION=true",
    "CLIENT_RETRY_DELAY_SECONDS=5",
  ]

  networks_advanced {
    name         = docker_network.pihole_ipvlan.name
    ipv4_address = local.nebula_sync_ip
  }

  depends_on = [docker_container.pihole]
}
