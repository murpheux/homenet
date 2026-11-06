terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = ">= 4.6.0"
    }
  }
}

resource "docker_secret" "traefik_cert" {
  name = "traefik_cert_${substr(md5(var.tls_cert), 0, 8)}"
  data = base64encode(var.tls_cert)
}

resource "docker_secret" "traefik_key" {
  name = "traefik_key_${substr(md5(var.tls_key), 0, 8)}"
  data = base64encode(var.tls_key)
}

resource "docker_config" "traefik_tls" {
  name = "traefik_tls_${substr(md5(var.tls_cert), 0, 8)}"
  data = base64encode(<<EOF
tls:
  stores:
    default:
      defaultCertificate:
        certFile: /run/secrets/tls.crt
        keyFile: /run/secrets/tls.key
EOF
  )
}

resource "docker_service" "traefik" {
  name = "traefik"

  task_spec {
    container_spec {
      image = "traefik:v3.0"
      args = [
        "--providers.swarm=true",
        "--providers.swarm.endpoint=unix:///var/run/docker.sock",
        "--providers.swarm.exposedbydefault=false",
        "--entrypoints.web.address=:80",
        "--entrypoints.web.http.redirections.entryPoint.to=websecure",
        "--entrypoints.web.http.redirections.entryPoint.scheme=https",
        "--entrypoints.websecure.address=:443",
        "--providers.file.directory=/etc/traefik/dynamic",
        "--accesslog=true"
      ]

      mounts {
        target    = "/var/run/docker.sock"
        source    = "/var/run/docker.sock"
        type      = "bind"
        read_only = true
      }

      secrets {
        secret_id   = docker_secret.traefik_cert.id
        secret_name = docker_secret.traefik_cert.name
        file_name   = "/run/secrets/tls.crt"
      }
      secrets {
        secret_id   = docker_secret.traefik_key.id
        secret_name = docker_secret.traefik_key.name
        file_name   = "/run/secrets/tls.key"
      }
      configs {
        config_id   = docker_config.traefik_tls.id
        config_name = docker_config.traefik_tls.name
        file_name   = "/etc/traefik/dynamic/tls.yml"
      }
    }

    placement {
      constraints = ["node.role == manager"]
    }

    networks_advanced { id = var.network_id }
  }

  endpoint_spec {
    ports {
      target_port    = 80
      published_port = 80
      publish_mode   = "ingress"
    }
    ports {
      target_port    = 443
      published_port = 443
      publish_mode   = "ingress"
    }
  }

  update_config {
    parallelism = 1
    delay       = "10s"
    order       = "start-first"
  }
}
