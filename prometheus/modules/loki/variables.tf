# modules/loki/variables.tf

variable "network" {
  description = "Overlay network ID (not name): networks_advanced.id is compared with the ID Swarm stores, and a mismatch forces the service to be replaced."
  type        = string
}

variable "data_volume" {
  description = "Name of the node-local volume holding chunks and the TSDB index."
  type        = string
}

variable "config_file" {
  description = "Path to the Loki config in the repo."
  type        = string
}

variable "image" {
  description = "Loki image."
  type        = string
  default     = "grafana/loki:3.0.0"
}

variable "placement_constraints" {
  description = "Swarm placement constraints for the service."
  type        = list(string)
  default     = []
}
