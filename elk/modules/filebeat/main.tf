# modules/filebeat/main.tf

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = ">= 4.6.0"
    }
  }
}

# filebeat.yml contains the filebeat_writer password, so it ships as a secret rather than
# a host bind mount (which only existed on one node).
resource "docker_secret" "filebeat_yml" {
  name = "filebeat_yml_${substr(sha256(var.config), 0, 12)}"
  data = base64encode(var.config)

  lifecycle {
    create_before_destroy = true
  }
}

# Global: one task per node, so every host's container logs are shipped.
resource "docker_service" "filebeat" {
  name = "softcraftphil"

  task_spec {
    container_spec {
      image = var.image

      # Root: Docker's container log files are readable by root only. Every host mount
      # below is read-only.
      user = "root"

      args = [
        "-e",
        "-strict.perms=false",
      ]

      secrets {
        secret_id   = docker_secret.filebeat_yml.id
        secret_name = docker_secret.filebeat_yml.name
        file_name   = "/usr/share/filebeat/filebeat.yml"
        file_mode   = 256 # 0400
      }

      mounts {
        target    = "/var/lib/docker/containers"
        source    = "/var/lib/docker/containers"
        type      = "bind"
        read_only = true
      }

      mounts {
        target    = "/var/run/docker.sock"
        source    = "/var/run/docker.sock"
        type      = "bind"
        read_only = true
      }
    }

    networks_advanced {
      id = var.network
    }

    resources {
      limits {
        memory_bytes = var.memory_limit_bytes
      }
    }

    restart_policy {
      condition = "any"
      delay     = "10s"
      window    = "60s"
    }
  }

  mode {
    global = true
  }
}
