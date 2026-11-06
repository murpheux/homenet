# modules/sqlserver/main.tf

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = ">= 4.6.0"
    }
  }
}

variable "sqlserver_sa_password" {
  type      = string
  sensitive = true
}

variable "data_volume" {
  type = string
}

variable "config_volume" {
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

resource "docker_service" "sqlserver" {
  name = "softcraftjorge"

  task_spec {
    container_spec {
      image = "mcr.microsoft.com/mssql/server:2022-latest"

      # The mssql image has no *_FILE variant, so the SA password stays an env var and is
      # visible in `docker service inspect`. It is only used when the data directory is
      # first initialised.
      env = {
        ACCEPT_EULA       = "Y"
        MSSQL_SA_PASSWORD = var.sqlserver_sa_password
        MSSQL_PID         = "Developer"
      }

      mounts {
        target = "/var/opt/mssql/data"
        source = var.data_volume
        type   = "volume"
      }

      mounts {
        target = "/var/opt/mssql/secrets"
        source = var.config_volume
        type   = "volume"
      }
    }

    networks_advanced {
      id = var.network
      # Former service name, so clients that still use it keep resolving.
      aliases = ["sqlserver"]
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
      target_port    = 1433
      published_port = 1433
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
