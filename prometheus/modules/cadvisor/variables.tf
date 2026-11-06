# modules/cadvisor/variables.tf

variable "network" {
  description = "Overlay network ID (not name): networks_advanced.id is compared with the ID Swarm stores, and a mismatch forces the service to be replaced."
  type        = string
}

variable "image" {
  description = "cAdvisor image. Pin to the digest Swarm runs once deployed."
  type        = string
  default     = "gcr.io/cadvisor/cadvisor:latest"
}
