# variables.tf

variable "pihole_password" {
  description = "Pi-hole web/API admin password. Injected from 1Password via op.env (TF_VAR_pihole_password)."
  type        = string
  sensitive   = true

  validation {
    condition     = length(trimspace(var.pihole_password)) > 0
    error_message = "pihole_password is empty. Run through 'op run --env-file=op.env -- terraform ...' (see Makefile)."
  }
}

# App passwords: 2FA is on for both Pi-holes and nebula-sync can't supply a TOTP code.
# App-password sessions skip 2FA. Each Pi-hole generates its own (Settings > Web interface
# / API > Configure app password).
variable "pihole_app_password_primary" {
  description = "App password of dns2 (10.10.2.7), the nebula-sync primary."
  type        = string
  sensitive   = true

  validation {
    condition     = length(trimspace(var.pihole_app_password_primary)) > 0 && !can(regex("[|,]", var.pihole_app_password_primary))
    error_message = "pihole_app_password_primary must be non-empty and contain no '|' or ',' (nebula-sync delimiters)."
  }
}

variable "pihole_app_password_replica" {
  description = "App password of dns (10.10.2.9), the nebula-sync replica. That Pi-hole needs webserver.api.app_sudo = true."
  type        = string
  sensitive   = true

  validation {
    condition     = length(trimspace(var.pihole_app_password_replica)) > 0 && !can(regex("[|,]", var.pihole_app_password_replica))
    error_message = "pihole_app_password_replica must be non-empty and contain no '|' or ',' (nebula-sync delimiters)."
  }
}

variable "nebula_sync_image" {
  description = "nebula-sync image, pinned to a release tag. Bump deliberately after reading the release notes."
  type        = string
  default     = "ghcr.io/lovelaze/nebula-sync:v0.11.3"
}

variable "nebula_sync_cron" {
  description = "Cron schedule (America/Edmonton) for syncing dns2 -> dns."
  type        = string
  default     = "0 * * * *"
}
