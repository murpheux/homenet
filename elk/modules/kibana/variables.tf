# modules/kibana/variables.tf

variable "image" {
  description = "Kibana image (exact version, same as Elasticsearch)."
  type        = string
}

variable "config" {
  description = "Rendered kibana.yml (contains secrets)."
  type        = string
  sensitive   = true
}

variable "network" {
  description = "Overlay network ID (not name): networks_advanced.id is compared with the ID Swarm stores, and a mismatch forces the service to be replaced."
  type        = string
}

variable "data_volume" {
  description = "Name of the node-local volume for /usr/share/kibana/data."
  type        = string
}

variable "memory_limit_bytes" {
  description = "Container memory limit. Kibana 8 needs about 1 GiB."
  type        = number
  default     = 1073741824 # 1 GiB
}

variable "placement_constraints" {
  description = "Swarm placement constraints. Must keep the service on the node holding its data volume."
  type        = list(string)
  default     = []
}
