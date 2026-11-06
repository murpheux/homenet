# modules/filebeat/variables.tf

variable "image" {
  description = "Filebeat image (exact version, same as Elasticsearch)."
  type        = string
}

variable "config" {
  description = "Rendered filebeat.yml (contains the filebeat_writer password)."
  type        = string
  sensitive   = true
}

variable "network" {
  description = "Overlay network ID (not name): networks_advanced.id is compared with the ID Swarm stores, and a mismatch forces the service to be replaced."
  type        = string
}

variable "memory_limit_bytes" {
  description = "Per-node container memory limit."
  type        = number
  default     = 268435456 # 256 MiB
}
