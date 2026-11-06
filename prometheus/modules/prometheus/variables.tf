# modules/prometheus/variables.tf

variable "network" {
  description = "Overlay network ID (not name): networks_advanced.id is compared with the ID Swarm stores, and a mismatch forces the service to be replaced."
  type        = string
}

variable "data_volume" {
  description = "Name of the node-local volume holding the TSDB."
  type        = string
}

variable "config_file" {
  description = "Path to prometheus.yml in the repo."
  type        = string
}

variable "image" {
  description = "Prometheus image. Pin to the digest Swarm runs once deployed."
  type        = string
  default     = "prom/prometheus:latest"
}

variable "retention_time" {
  description = "TSDB retention by age."
  type        = string
  default     = "30d"
}

variable "retention_size" {
  description = "TSDB retention by size; whichever limit is hit first applies."
  type        = string
  default     = "10GB"
}

variable "placement_constraints" {
  description = "Swarm placement constraints for the service."
  type        = list(string)
  default     = []
}
