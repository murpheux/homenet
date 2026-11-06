# modules/mysql/main.tf

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = ">= 4.6.0"
    }
  }
}

variable "mysql_root_password" {
  type      = string
  sensitive = true
}

variable "mysql_database" {
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
resource "docker_secret" "root_password" {
  name = "mysql_root_password_${substr(sha256(var.mysql_root_password), 0, 12)}"
  data = base64encode(var.mysql_root_password)

  lifecycle {
    create_before_destroy = true
  }
}

resource "docker_service" "mysql" {
  name = "softcraftdave"

  task_spec {
    container_spec {
      image = "mysql:8.0"

      # *_FILE keeps the password out of `docker service inspect`.
      env = {
        MYSQL_ROOT_PASSWORD_FILE = "/run/secrets/mysql_root_password"
        MYSQL_DATABASE           = var.mysql_database
      }

      secrets {
        secret_id   = docker_secret.root_password.id
        secret_name = docker_secret.root_password.name
        file_name   = "/run/secrets/mysql_root_password"
      }

      mounts {
        target = "/var/lib/mysql"
        source = var.data_volume
        type   = "volume"
      }
    }

    networks_advanced {
      id = var.network
      # Former service name, so clients that still use it keep resolving.
      aliases = ["mysql"]
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
      target_port    = 3306
      published_port = 3306
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
