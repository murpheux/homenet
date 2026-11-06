variable "tomcat_image" {
  description = "Tomcat image as an exact patch tag (11.0.NN-...), so the running build only changes when this does."
  type        = string
  default     = "tomcat:11.0.27-jre21-temurin-noble"

  validation {
    condition     = can(regex(":[0-9]+\\.[0-9]+\\.[0-9]+-", var.tomcat_image))
    error_message = "tomcat_image must use an exact patch tag such as tomcat:11.0.27-jre21-temurin-noble, not a floating one like 11.0-...."
  }
}

variable "service_replicas" {
  description = "Number of service replicas."
  type        = number
  default     = 1

  validation {
    condition     = var.service_replicas >= 1 && var.service_replicas <= 3
    error_message = "service_replicas must be between 1 and 3 (one per Swarm node)."
  }
}

# 8080 is cAdvisor's published port (prometheus stack); both use the Swarm ingress.
variable "http_port" {
  description = "Tomcat HTTP connector port, published on the Swarm ingress."
  type        = number
  default     = 8085

  validation {
    condition     = var.http_port >= 1024 && var.http_port <= 65535 && var.http_port != 8080
    error_message = "http_port must be 1024-65535 and not 8080 (cAdvisor)."
  }
}

variable "health_check_port" {
  description = "Tomcat dedicated health-check connector port, published on the Swarm ingress."
  type        = number
  default     = 8081

  validation {
    condition     = var.health_check_port >= 1024 && var.health_check_port <= 65535 && var.health_check_port != var.http_port
    error_message = "health_check_port must be 1024-65535 and differ from http_port."
  }
}

variable "shutdown_port" {
  description = "Tomcat shutdown port (container-internal, not published)."
  type        = number
  default     = 8005
}

variable "app_db_url" {
  description = "JDBC URL written to application.properties. `softcraftmark` is the database stack's PostgreSQL service on db_net (`postgresql` also resolves, as an alias)."
  type        = string
  default     = "jdbc:postgresql://softcraftmark:5432/appdb"
}

variable "app_db_user" {
  description = "Database username written to application.properties."
  type        = string
  default     = "tomcat_user"
}

variable "app_db_password" {
  description = "Database password written to application.properties. From 1Password via op.env."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.app_db_password) >= 12 && !can(regex("[\\\\\\n\\r]", var.app_db_password))
    error_message = "app_db_password must be at least 12 characters with no backslashes or line breaks (Java .properties escapes)."
  }
}

variable "db_network_name" {
  description = "Overlay network of the database stack that Tomcat joins."
  type        = string
  default     = "db_net"
}

variable "placement_constraints" {
  description = "Swarm placement constraints. Workers by default, to keep load off scarlet."
  type        = list(string)
  default     = ["node.role == worker"]
}
