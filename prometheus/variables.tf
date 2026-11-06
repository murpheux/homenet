# variables.tf
#
# Secrets and the admin email come from 1Password via op.env (`make plan` / `make apply`).

variable "grafana_url" {
  description = "Grafana URL the grafana provider uses (any Swarm node's IP; port 3000 is on the ingress)."
  type        = string
  default     = "http://10.10.2.80:3000"
}

variable "grafana_admin_user" {
  description = "Grafana admin username (first start only)."
  type        = string
  default     = "admin"
}

variable "grafana_admin_password" {
  description = "Grafana admin password. Applied only when Grafana's database is first created; later changes are made in Grafana."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.grafana_admin_password) >= 12
    error_message = "grafana_admin_password must be at least 12 characters."
  }
}

variable "grafana_admin_email" {
  description = "Grafana admin email (first start only). Kept in 1Password so it isn't committed."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.grafana_admin_email))
    error_message = "grafana_admin_email must be an email address."
  }
}

variable "grafana_auth_token" {
  description = "Optional Grafana service-account token (glsa_...) for the grafana provider. Empty: the provider uses the admin user and password instead."
  type        = string
  sensitive   = true
  default     = ""
}
