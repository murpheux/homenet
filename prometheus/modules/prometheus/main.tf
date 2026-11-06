# modules/prometheus/main.tf

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = ">= 4.6.0"
    }
  }
}

# prometheus.yml ships as a Swarm config from the repo instead of a host bind mount,
# so the service can run on any node. Content hash in the name: a change creates a
# new config, swapped in by create_before_destroy.
resource "docker_config" "prometheus_yml" {
  name = "prometheus-yml-${substr(filesha256(var.config_file), 0, 12)}"
  data = filebase64(var.config_file)

  lifecycle {
    create_before_destroy = true
  }
}

resource "docker_service" "prometheus" {
  name = "softcraftbelle"

  task_spec {
    container_spec {
      image = var.image

      # No --web.enable-lifecycle: without auth it lets anyone on the LAN POST /-/quit.
      # Reload a config change with a service update (`make apply` does that).
      args = [
        "--config.file=/etc/prometheus/prometheus.yml",
        "--storage.tsdb.path=/prometheus",
        "--storage.tsdb.retention.time=${var.retention_time}",
        "--storage.tsdb.retention.size=${var.retention_size}",
      ]

      configs {
        config_id   = docker_config.prometheus_yml.id
        config_name = docker_config.prometheus_yml.name
        file_name   = "/etc/prometheus/prometheus.yml"
      }

      mounts {
        target = "/prometheus"
        source = var.data_volume
        type   = "volume"
      }

      healthcheck {
        test     = ["CMD", "wget", "-q", "-O", "-", "http://localhost:9090/-/ready"]
        interval = "10s"
        timeout  = "3s"
        retries  = 10
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
      target_port    = 9090
      published_port = 9090
      protocol       = "tcp"
    }
  }
}
