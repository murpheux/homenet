# modules/cadvisor/main.tf

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = ">= 4.6.0"
    }
  }
}

# Global: one task per node, so each host's containers are measured. Prometheus scrapes
# every task through the overlay DNS name tasks.softcraftchow. Port 8080 on the ingress
# reaches whichever node's cAdvisor the routing mesh picks (UI only).
resource "docker_service" "cadvisor" {
  name = "softcraftchow"

  task_spec {
    container_spec {
      image = var.image

      mounts {
        target    = "/var/run/docker.sock"
        source    = "/var/run/docker.sock"
        type      = "bind"
        read_only = true
      }
      mounts {
        target    = "/rootfs"
        source    = "/"
        type      = "bind"
        read_only = true
      }
      mounts {
        target    = "/var/lib/docker"
        source    = "/var/lib/docker"
        type      = "bind"
        read_only = true
      }
      mounts {
        target    = "/sys"
        source    = "/sys"
        type      = "bind"
        read_only = true
      }
    }

    networks_advanced {
      id = var.network
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

  endpoint_spec {
    ports {
      target_port    = 8080
      published_port = 8080
      protocol       = "tcp"
    }
  }
}
