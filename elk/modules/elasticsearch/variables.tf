# modules/elasticsearch/variables.tf

variable "image" {
  description = "Elasticsearch image (exact version)."
  type        = string
}

variable "network" {
  description = "Overlay network ID (not name): networks_advanced.id is compared with the ID Swarm stores, and a mismatch forces the service to be replaced."
  type        = string
}

variable "elastic_password" {
  description = "Password of the built-in elastic superuser."
  type        = string
  sensitive   = true
}

variable "java_opts" {
  description = "JVM heap settings."
  type        = string
  default     = "-Xms1g -Xmx1g"
}

variable "memory_limit_bytes" {
  description = "Container memory limit (heap plus off-heap)."
  type        = number
  default     = 2147483648 # 2 GiB
}

variable "placement_constraints" {
  description = "Swarm placement constraints. Must keep the service on the node holding es_data."
  type        = list(string)
  default     = []
}
