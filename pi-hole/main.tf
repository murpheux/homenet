# main.tf


# -----------------------------
# Docker Network (required for static MAC)
# -----------------------------
resource "docker_network" "pihole_ipvlan" {
  name   = "pihole_ipvlan"
  driver = "ipvlan"

  # Enable IPv6 support
  ipv6 = true

  options = {
    parent = "enp3s0f0"
    mode   = "l2"
  }

  # IPv4 subnet
  ipam_config {
    subnet  = "10.10.2.0/24"
    gateway = "10.10.2.1"
  }

  # IPv6 subnet (example ULA prefix)
  ipam_config {
    subnet  = "fd00:10:10:2::/64"
    gateway = "fd00:10:10:2::1"
  }
}

# -----------------------------
# Pi-hole Image
# -----------------------------
resource "docker_image" "pihole" {
  name = "pihole/pihole:latest"
}

# -----------------------------
# Pi-hole Container
# -----------------------------
resource "docker_container" "pihole" {
  name     = "softcraftjim" # Container name
  hostname = "softcraftjim" # Hostname inside container
  image    = docker_image.pihole.name
  # user  = "1000:1000" # UID:GID

  # -----------------------------
  # Port mappings
  # -----------------------------
  ports {
    internal = 53
    external = 53
    protocol = "tcp"
  }

  ports {
    internal = 53
    external = 53
    protocol = "udp"
  }

  ports {
    internal = 80
    external = 80
  }

  ports {
    internal = 443
    external = 443
  }

  # -----------------------------
  # Persistent volumes
  # -----------------------------
  volumes {
    host_path      = "/home/murpheux/HomeNet/pihole/etc-pihole"
    container_path = "/etc/pihole"
  }

  volumes {
    host_path      = "/home/murpheux/HomeNet/pihole/etc-dnsmasq.d"
    container_path = "/etc/dnsmasq.d"
  }

  volumes {
    host_path      = "/home/murpheux/HomeNet/pihole/log-pihole"
    container_path = "/var/log/pihole"
  }

  # Private in-memory /tmp; never share the host's (sockets, symlink races).
  tmpfs = {
    "/tmp" = "rw,noexec,nosuid,size=256m"
  }

  # -----------------------------
  # Environment variables
  # -----------------------------
  # Docker splits on the first "=" verbatim: no spaces around it.
  env = [
    "TZ=America/Edmonton",
    "PIHOLE_WEBPASSWORD=${var.pihole_password}",
    "PIHOLE_INTERFACE=eth0",
    "PIHOLE_USE_IPV6=false",
    "FTLCONF_webserver_api_password=${var.pihole_password}",
    "FTLCONF_dns_listeningMode=ALL",
    "PIHOLE_UID=1000",
    "PIHOLE_GID=1000",
    "FTLCONF_misc_check_load=false",
  ]

  # Docker default capabilities only. NET_ADMIN is needed solely for Pi-hole's
  # DHCP server; DHCP is served by router1, and NET_ADMIN on an ipvlan LAN
  # interface would allow spoofing other LAN addresses.

  # -----------------------------
  # Networking
  # -----------------------------
  networks_advanced {
    name         = docker_network.pihole_ipvlan.name
    ipv4_address = "10.10.2.7"       # Set Static IP
    ipv6_address = "fd00:10:10:2::5" # Set Static IPv6
  }

  restart = "unless-stopped"
}
