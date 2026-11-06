# modules/logstash/main.tf
#
# Optional (enable_logstash). With an empty pipeline volume, Docker copies the image's
# default pipeline in (beats input on 5044, stdout output). Add a real pipeline there
# before pointing anything at it.

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = ">= 4.6.0"
    }
  }
}

resource "docker_volume" "logstash_pipeline" {
  name = "logstash_pipeline"
}

resource "docker_service" "logstash" {
  name = "softcraftjerrry"

  task_spec {
    container_spec {
      image = var.image

      env = {
        "LS_JAVA_OPTS" = "-Xms512m -Xmx512m"
      }

      mounts {
        target = "/usr/share/logstash/pipeline"
        source = docker_volume.logstash_pipeline.name
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
        memory_bytes = 1073741824 # 1 GiB
      }
    }

    restart_policy {
      condition = "any"
      delay     = "10s"
      window    = "60s"
    }
  }

  mode {
    replicated {
      replicas = 1
    }
  }
}
