# modules/mongodb/main.tf

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = ">= 4.6.0"
    }
  }
}

variable "mongo_user" {
  type = string
}

variable "mongo_password" {
  type      = string
  sensitive = true
}

variable "mongo_database" {
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
  name = "mongodb_root_password_${substr(sha256(var.mongo_password), 0, 12)}"
  data = base64encode(var.mongo_password)

  lifecycle {
    create_before_destroy = true
  }
}

resource "docker_service" "mongodb" {
  name = "softcraftjerry"

  task_spec {
    container_spec {
      image = "mongo:7"

      # *_FILE keeps the password out of `docker service inspect`.
      env = {
        MONGO_INITDB_ROOT_USERNAME      = var.mongo_user
        MONGO_INITDB_ROOT_PASSWORD_FILE = "/run/secrets/mongodb_root_password"
        MONGO_INITDB_DATABASE           = var.mongo_database
      }

      secrets {
        secret_id   = docker_secret.root_password.id
        secret_name = docker_secret.root_password.name
        file_name   = "/run/secrets/mongodb_root_password"
      }

      mounts {
        target = "/data/db"
        source = var.data_volume
        type   = "volume"
      }
    }

    networks_advanced {
      id = var.network
      # Former service name, so clients that still use it keep resolving.
      aliases = ["mongodb"]
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
      target_port    = 27017
      published_port = 27017
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
