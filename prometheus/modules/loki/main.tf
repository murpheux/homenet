# modules/loki/main.tf

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = ">= 4.6.0"
    }
  }
}

# Loki's config ships as a Swarm config from the repo (config/config.yaml) instead of a
# host bind mount, so the service can run on any node.
resource "docker_config" "loki_yaml" {
  name = "loki-config-${substr(filesha256(var.config_file), 0, 12)}"
  data = filebase64(var.config_file)

  lifecycle {
    create_before_destroy = true
  }
}

resource "docker_service" "loki" {
  name = "softcraftmel"

  task_spec {
    container_spec {
      image = var.image

      args = ["-config.file=/etc/loki/local-config.yaml"]

      configs {
        config_id   = docker_config.loki_yaml.id
        config_name = docker_config.loki_yaml.name
        file_name   = "/etc/loki/local-config.yaml"
      }

      mounts {
        target = "/loki"
        source = var.data_volume
        type   = "volume"
      }
    }

    networks_advanced {
      id = var.network
    }

    placement {
      constraints = var.placement_constraints
    }

    restart_policy {
      condition = "any"
      delay     = "10s"
      window    = "60s"
    }
  }

  endpoint_spec {
    ports {
      target_port    = 3100
      published_port = 3100
      protocol       = "tcp"
    }
  }
}
