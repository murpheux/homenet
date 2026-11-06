# modules/logstash/variables.tf

variable "image" {
  description = "Logstash image (exact version, same as Elasticsearch)."
  type        = string
}

variable "network" {
  description = "Overlay network ID (not name): networks_advanced.id is compared with the ID Swarm stores, and a mismatch forces the service to be replaced."
  type        = string
}

variable "placement_constraints" {
  description = "Swarm placement constraints. Must keep the service on the node holding its pipeline volume."
  type        = list(string)
  default     = []
}
