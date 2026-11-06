# modules/postgresql/main.tf

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = ">= 4.6.0"
    }
  }
}

variable "postgres_user" {
  type = string
}

variable "postgres_password" {
  type      = string
  sensitive = true
}

variable "postgres_db" {
  type    = string
  default = "appdb"
}

variable "data_volume" {
  type = string
}

variable "network" {
  description = "Overlay network ID (not name): networks_advanced.id is compared with the ID Swarm stores, and a mismatch forces the service to be replaced."
  type        = string
}

variable "placement_constraints" {
  description = "Swarm placement constraints for the service."
  type        = list(string)
  default     = []
}

# Swarm secrets are immutable: the content hash in the name makes a new value create a
# new secret, swapped in by create_before_destroy.
resource "docker_secret" "password" {
  name = "postgresql_password_${substr(sha256(var.postgres_password), 0, 12)}"
  data = base64encode(var.postgres_password)

  lifecycle {
    create_before_destroy = true
  }
}

resource "docker_service" "postgresql" {
  name = "softcraftmark"

  task_spec {
    container_spec {
      image = "postgres:16"

      # *_FILE keeps the password out of `docker service inspect`.
      env = {
        POSTGRES_USER          = var.postgres_user
        POSTGRES_PASSWORD_FILE = "/run/secrets/postgresql_password"
        POSTGRES_DB            = var.postgres_db
      }

      secrets {
        secret_id   = docker_secret.password.id
        secret_name = docker_secret.password.name
        file_name   = "/run/secrets/postgresql_password"
      }

      mounts {
        target = "/var/lib/postgresql/data"
        source = var.data_volume
        type   = "volume"
      }
    }

    networks_advanced {
      id = var.network
      # Former service name, so clients that still use it keep resolving.
      aliases = ["postgresql"]
    }

    placement {
      constraints = var.placement_constraints
    }

    # Wait between restarts instead of a tight crash loop.
    restart_policy {
      condition = "any"
      delay     = "10s"
      window    = "60s"
    }
  }

  endpoint_spec {
    ports {
      target_port    = 5432
      published_port = 5432
      protocol       = "tcp"
      publish_mode   = "ingress"
    }
  }

  mode {
    replicated {
      replicas = 1
    }
  }
}
