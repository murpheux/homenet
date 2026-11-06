# variables.tf
#
# Secrets come from 1Password via op.env (`make plan` / `make apply`); create them once
# with `make create-secrets`.

# Characters that would break a double-quoted value in the kibana.yml / filebeat.yml
# templates: ", \, line breaks, and ${ (Kibana and Filebeat expand ${VAR} references).
locals {
  unsafe_in_yaml_template = "[\"\\\\\\n\\r]|\\$\\{"
}

variable "elastic_version" {
  description = "Elastic Stack version for Elasticsearch, Kibana, Filebeat and Logstash (exact patch). All four must match."
  type        = string
  default     = "8.19.23"

  validation {
    condition     = can(regex("^8\\.19\\.[0-9]+$", var.elastic_version))
    error_message = "elastic_version must be an exact 8.19.x patch (8.x reads the existing 7.17 indices; 9.x can't)."
  }
}

variable "elasticsearch_url" {
  description = "Elasticsearch URL the elasticstack provider uses (any Swarm node; 9200 is on the ingress)."
  type        = string
  default     = "http://10.10.2.80:9200"
}

variable "elastic_password" {
  description = "Password of the built-in elastic superuser (bootstrap password on first secured start)."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.elastic_password) >= 16
    error_message = "elastic_password must be at least 16 characters."
  }
}

variable "kibana_system_password" {
  description = "Password of the built-in kibana_system user Kibana signs in with."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.kibana_system_password) >= 16 && !can(regex(local.unsafe_in_yaml_template, var.kibana_system_password))
    error_message = "kibana_system_password must be 16+ characters with no double quote, backslash, line break or $${ (it's written into kibana.yml)."
  }
}

variable "kibana_encryption_key" {
  description = "Key for Kibana's encrypted saved objects, sessions and reports (32+ characters)."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.kibana_encryption_key) >= 32 && !can(regex(local.unsafe_in_yaml_template, var.kibana_encryption_key))
    error_message = "kibana_encryption_key must be 32+ characters with no double quote, backslash, line break or $${ (it's written into kibana.yml)."
  }
}

variable "filebeat_password" {
  description = "Password of the filebeat_writer user Filebeat ships with."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.filebeat_password) >= 16 && !can(regex(local.unsafe_in_yaml_template, var.filebeat_password))
    error_message = "filebeat_password must be 16+ characters with no double quote, backslash, line break or $${ (it's written into filebeat.yml)."
  }
}

variable "enable_logstash" {
  description = "Deploy Logstash. Off: nothing sends to it (Filebeat writes to Elasticsearch directly)."
  type        = bool
  default     = false
}
