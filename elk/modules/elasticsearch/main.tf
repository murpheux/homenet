# modules/elasticsearch/main.tf

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = ">= 4.6.0"
    }
  }
}

# -------------------------
# Data volume (scarlet)
# -------------------------
# Existing volume: it may hold 7.17 indices, which 8.19 upgrades in place on first start.
resource "docker_volume" "es_data" {
  name = "es_data"
}

# ELASTIC_PASSWORD_FILE keeps the password out of `docker service inspect`.
resource "docker_secret" "elastic_password" {
  name = "elastic_password_${substr(sha256(var.elastic_password), 0, 12)}"
  data = base64encode(var.elastic_password)

  lifecycle {
    create_before_destroy = true
  }
}

# -------------------------
# Elasticsearch
# -------------------------
resource "docker_service" "elasticsearch" {
  name = "softcraftotto"

  task_spec {
    container_spec {
      image = var.image

      # Single node: no cluster formation or transport TLS needed. HTTP is plain (LAN
      # only) but authenticated.
      env = {
        "discovery.type"                       = "single-node"
        "ES_JAVA_OPTS"                         = var.java_opts
        "xpack.security.enabled"               = "true"
        "xpack.security.http.ssl.enabled"      = "false"
        "xpack.security.transport.ssl.enabled" = "false"
        "ELASTIC_PASSWORD_FILE"                = "/run/secrets/elastic_password"
      }

      secrets {
        secret_id   = docker_secret.elastic_password.id
        secret_name = docker_secret.elastic_password.name
        file_name   = "/run/secrets/elastic_password"
      }

      mounts {
        target = "/usr/share/elasticsearch/data"
        source = docker_volume.es_data.name
        type   = "volume"
      }

      # 401 means up and enforcing security; no credentials needed for the probe.
      healthcheck {
        test     = ["CMD-SHELL", "curl -s -o /dev/null -w '%%{http_code}' http://localhost:9200 | grep -qE '^(200|401)$'"]
        interval = "10s"
        timeout  = "5s"
        retries  = 30
      }
    }

    networks_advanced {
      id = var.network
      # Kibana and Filebeat address Elasticsearch by this name.
      aliases = ["elasticsearch"]
    }

    placement {
      constraints = var.placement_constraints
    }

    resources {
      limits {
        memory_bytes = var.memory_limit_bytes
      }
    }

    restart_policy {
      condition = "any"
      delay     = "10s"
      window    = "120s"
    }
  }

  mode {
    replicated {
      replicas = 1
    }
  }

  endpoint_spec {
    ports {
      name           = "es-http"
      protocol       = "tcp"
      target_port    = 9200
      published_port = 9200
      publish_mode   = "ingress"
    }
  }

  # No converge_config: on a convergence timeout the provider deletes the service, taking
  # its logs with it. `make bootstrap` waits with scripts/wait-for-service.sh instead,
  # which prints the task errors and logs if Elasticsearch doesn't come up.
}
