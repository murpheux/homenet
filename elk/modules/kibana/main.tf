# modules/kibana/main.tf

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = ">= 4.6.0"
    }
  }
}

# kibana.yml contains the kibana_system password and the encryption key.
resource "docker_secret" "kibana_yml" {
  name = "kibana_yml_${substr(sha256(var.config), 0, 12)}"
  data = base64encode(var.config)

  lifecycle {
    create_before_destroy = true
  }
}

resource "docker_service" "kibana" {
  name = "softcraftcarl"

  task_spec {
    container_spec {
      image = var.image

      # Kibana runs as uid 1000.
      secrets {
        secret_id   = docker_secret.kibana_yml.id
        secret_name = docker_secret.kibana_yml.name
        file_name   = "/usr/share/kibana/config/kibana.yml"
        file_uid    = "1000"
        file_gid    = "0"
        file_mode   = 256 # 0400
      }

      mounts {
        target = "/usr/share/kibana/data"
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
      name           = "kibana-http"
      protocol       = "tcp"
      target_port    = 5601
      published_port = 5601
      publish_mode   = "ingress"
    }
  }
}
