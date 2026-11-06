# variables.tf
#
# All values come from 1Password via op.env (`make plan` / `make apply`).
# MySQL, MongoDB, PostgreSQL and SQL Server only apply these at FIRST initialisation of
# an empty data directory; changing them later does not change the live password
# (rotate with ALTER USER / db.changeUserPassword / ALTER LOGIN, then update 1Password).
# Redis applies redis_password on every start.

variable "mysql_root_password" {
  description = "MySQL root password (initialisation only)."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.mysql_root_password) >= 12
    error_message = "mysql_root_password must be at least 12 characters."
  }
}

variable "mongo_user" {
  description = "MongoDB root username (initialisation only)."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+$", var.mongo_user))
    error_message = "mongo_user must be non-empty and use only letters, digits, '_', '.', '-'."
  }
}

variable "mongo_password" {
  description = "MongoDB root password (initialisation only)."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.mongo_password) >= 12
    error_message = "mongo_password must be at least 12 characters."
  }
}

variable "postgres_user" {
  description = "PostgreSQL superuser name (initialisation only)."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z_][A-Za-z0-9_]*$", var.postgres_user))
    error_message = "postgres_user must be a valid identifier (letter or '_' first, then letters, digits, '_')."
  }
}

variable "postgres_password" {
  description = "PostgreSQL superuser password (initialisation only)."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.postgres_password) >= 12
    error_message = "postgres_password must be at least 12 characters."
  }
}

variable "sqlserver_sa_password" {
  description = "SQL Server SA password (initialisation only). SQL Server requires 8+ characters from 3 of: upper, lower, digit, symbol."
  type        = string
  sensitive   = true

  validation {
    condition = length(var.sqlserver_sa_password) >= 8 && length([
      for re in ["[A-Z]", "[a-z]", "[0-9]", "[^A-Za-z0-9]"] : re
      if can(regex(re, var.sqlserver_sa_password))
    ]) >= 3
    error_message = "sqlserver_sa_password must be 8+ characters using at least 3 of: uppercase, lowercase, digits, symbols."
  }
}

variable "redis_password" {
  description = "Redis requirepass, applied on every start (written into a redis.conf Swarm secret)."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.redis_password) >= 12 && !can(regex("[\"\\\\\\s]", var.redis_password))
    error_message = "redis_password must be at least 12 characters and contain no quotes, backslashes or whitespace (it is written into redis.conf)."
  }
}
