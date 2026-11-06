terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = ">= 4.6.0"
    }
  }
}

resource "docker_volume" "hermes_data_nfs_volume" {
  name   = "hermes_data_nfs"
  driver = "local"
  driver_opts = {
    type   = "nfs"
    device = "${var.nfs_base_path}/hermes/data"
    o      = var.nfs_mount_opts
  }
}

resource "docker_secret" "hermes_api_key" {
  name = "hermes_api_key_${substr(md5(var.ai_api_key), 0, 8)}"
  data = base64encode(var.ai_api_key)
}

resource "docker_service" "hermes" {
  name = "hermes"

  task_spec {
    container_spec {
      image   = "ghcr.io/nousresearch/hermes-agent:latest"
      command = ["gateway"]

      env = {
        "HERMES_AUTH_TOKEN" = var.ai_api_key
      }

      secrets {
        secret_id   = docker_secret.hermes_api_key.id
        secret_name = docker_secret.hermes_api_key.name
        file_name   = "/run/secrets/hermes_api_key"
      }

      mounts {
        target = "/data"
        source = docker_volume.hermes_data_nfs_volume.name
        type   = "volume"
      }

      healthcheck {
        test     = ["CMD", "curl", "-f", "http://localhost:8642/health"]
        interval = "30s"
        timeout  = "5s"
        retries  = 3
      }
    }

    networks_advanced {
      id = var.network_id
    }
  }

  endpoint_spec {
    ports {
      target_port    = 8642
      published_port = 8642
      publish_mode   = "ingress"
    }
  }

  mode {
    replicated {
      replicas = 1
    }
  }

  update_config {
    parallelism       = 1
    delay             = "10s"
    failure_action    = "rollback"
    monitor           = "15s"
    max_failure_ratio = "0.1"
    order             = "start-first"
  }
}
