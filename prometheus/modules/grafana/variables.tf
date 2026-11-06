# modules/grafana/variables.tf

variable "grafana_admin_user" {
  description = "Grafana admin username (first start only)."
  type        = string
  default     = "admin"
}

variable "grafana_admin_password" {
  description = "Grafana admin password (first start only)."
  type        = string
  sensitive   = true
}

variable "grafana_admin_email" {
  description = "Grafana admin email (first start only)."
  type        = string
  sensitive   = true
}

variable "network" {
  description = "Overlay network ID (not name): networks_advanced.id is compared with the ID Swarm stores, and a mismatch forces the service to be replaced."
  type        = string
}

variable "data_volume" {
  description = "Name of the node-local volume holding grafana.db, plugins and dashboards."
  type        = string
}

variable "image" {
  description = "Grafana image. Pin to the digest Swarm runs once deployed."
  type        = string
  default     = "grafana/grafana:latest"
}

variable "placement_constraints" {
  description = "Swarm placement constraints for the service."
  type        = list(string)
  default     = []
}
