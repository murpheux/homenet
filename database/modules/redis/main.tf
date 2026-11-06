# modules/redis/main.tf

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = ">= 4.6.0"
    }
  }
}

variable "redis_password" {
  type      = string
  sensitive = true
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

# Redis has no *_FILE variable, so requirepass lives in a config file delivered as a Swarm
# secret instead of a --requirepass argument (visible in `docker service inspect` and ps).
# The root module's validation rejects quotes, backslashes and whitespace in the password.
resource "docker_secret" "config" {
  name = "redis_conf_${substr(sha256(var.redis_password), 0, 12)}"
  data = base64encode("requirepass \"${var.redis_password}\"\n")

  lifecycle {
    create_before_destroy = true
  }
}

resource "docker_service" "redis" {
  name = "softcraftron"

  task_spec {
    container_spec {
      image = "redis:7-alpine"

      args = [
        "redis-server",
        "/run/secrets/redis.conf",
        "--appendonly", "yes",
      ]

      # Default mode 0444: the entrypoint drops to the redis user before reading it.
      secrets {
        secret_id   = docker_secret.config.id
        secret_name = docker_secret.config.name
        file_name   = "/run/secrets/redis.conf"
      }

      mounts {
        target = "/data"
        source = var.data_volume
        type   = "volume"
      }
    }

    networks_advanced {
      id = var.network
      # Former service name, so clients that still use it keep resolving.
      aliases = ["redis"]
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
      target_port    = 6379
      published_port = 6379
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
