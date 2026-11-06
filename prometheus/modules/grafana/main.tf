# modules/grafana/main.tf

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = ">= 4.6.0"
    }
  }
}

# GF_SECURITY_ADMIN_PASSWORD__FILE keeps the password out of `docker service inspect`.
resource "docker_secret" "admin_password" {
  name = "grafana_admin_password_${substr(sha256(var.grafana_admin_password), 0, 12)}"
  data = base64encode(var.grafana_admin_password)

  lifecycle {
    create_before_destroy = true
  }
}

resource "docker_service" "grafana" {
  name = "softcraftbob"

  task_spec {
    container_spec {
      image = var.image
      user  = "472"

      env = {
        "GF_SECURITY_ADMIN_USER"           = var.grafana_admin_user
        "GF_SECURITY_ADMIN_PASSWORD__FILE" = "/run/secrets/grafana_admin_password"
        "GF_SECURITY_ADMIN_EMAIL"          = var.grafana_admin_email
        "GF_AUTH_ANONYMOUS_ENABLED"        = "false"
      }

      # Default mode 0444: Grafana runs as uid 472.
      secrets {
        secret_id   = docker_secret.admin_password.id
        secret_name = docker_secret.admin_password.name
        file_name   = "/run/secrets/grafana_admin_password"
      }

      mounts {
        target = "/var/lib/grafana"
        source = var.data_volume
        type   = "volume"
      }

      healthcheck {
        test     = ["CMD", "curl", "-f", "http://localhost:3000/api/health"]
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
      target_port    = 3000
      published_port = 3000
      protocol       = "tcp"
    }
  }

  # Wait until the task is running and healthy before Terraform moves on: the
  # grafana_data_source resources call Grafana's API right after this.
  converge_config {
    delay   = "10s"
    timeout = "5m"
  }
}
