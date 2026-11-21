# outputs.tf - Pi-hole Container IDs

# Pi-hole Container
output "pihole_container_id" {
  description = "Pi-hole container ID (not a swarm service)"
  value       = docker_container.pihole.id
}

output "pihole_container_name" {
  description = "Pi-hole container name (softcraftjim)"
  value       = docker_container.pihole.name
}

output "pihole_container_image_id" {
  description = "Pi-hole container image ID"
  value       = docker_container.pihole.image
}

output "pihole_network_id" {
  description = "Pi-hole ipvlan network ID"
  value       = docker_network.pihole_ipvlan.id
}

output "pihole_network_name" {
  description = "Pi-hole ipvlan network name"
  value       = docker_network.pihole_ipvlan.name
}

output "pihole_ipv4_address" {
  description = "Pi-hole static IPv4 address (10.10.2.7)"
  value       = docker_container.pihole.networks_advanced[0].ipv4_address
}

output "pihole_ipv6_address" {
  description = "Pi-hole static IPv6 address"
  value       = docker_container.pihole.networks_advanced[0].ipv6_address
}

output "pihole_image_id" {
  description = "Pi-hole Docker image ID"
  value       = docker_image.pihole.id
}

output "pihole_image_repo_digest" {
  description = "Pi-hole image repository digest (content hash)"
  value       = docker_image.pihole.repo_digest
}
