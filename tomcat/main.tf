terraform {
  required_version = ">= 1.15.7"

  cloud {
    organization = "softcraft"

    workspaces {
      name = "homenet-tomcat"
    }
  }

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = ">= 4.6.0"
    }
  }
}

provider "docker" {
  context = "murpheux-scarlet"
}

# -----------------------------------------------------------------------------
# Rendered files
# -----------------------------------------------------------------------------
# Built-in templatefile(): the hashicorp/template provider is archived and has no
# darwin_arm64 build, so `terraform init` failed on medusa.
locals {
  server_xml = templatefile("${path.module}/templates/server.xml.tftpl", {
    http_port         = var.http_port
    health_check_port = var.health_check_port
    shutdown_port     = var.shutdown_port
  })

  health_ping = templatefile("${path.module}/templates/health_ping.json.tftpl", {
    health_check_port = var.health_check_port
  })

  index_html = templatefile("${path.module}/templates/index.html.tftpl", {
    http_port = var.http_port
  })

  # Holds the DB password, so it ships as a Swarm secret, not a config.
  application_properties = templatefile("${path.module}/templates/application.properties.tftpl", {
    http_port   = var.http_port
    db_url      = var.app_db_url
    db_user     = var.app_db_user
    db_password = var.app_db_password
  })
}

# -----------------------------------------------------------------------------
# Swarm configs and secret
# -----------------------------------------------------------------------------
# Configs and secrets are immutable: the content hash in each name makes a change
# create a new object, swapped in by create_before_destroy.
resource "docker_config" "tomcat_server_xml" {
  name = "tomcat-server-xml-${md5(local.server_xml)}"
  data = base64encode(local.server_xml)

  lifecycle {
    create_before_destroy = true
  }
}

resource "docker_config" "index_html" {
  name = "tomcat-index-html-${md5(local.index_html)}"
  data = base64encode(local.index_html)

  lifecycle {
    create_before_destroy = true
  }
}

resource "docker_config" "health_ping" {
  name = "tomcat-health-ping-${md5(local.health_ping)}"
  data = base64encode(local.health_ping)

  lifecycle {
    create_before_destroy = true
  }
}

resource "docker_secret" "app_properties" {
  name = "tomcat-app-properties-${substr(sha256(local.application_properties), 0, 12)}"
  data = base64encode(local.application_properties)

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# Service & image
# -----------------------------------------------------------------------------
# Joins the database stack's overlay network so the JDBC URL can reach the
# `postgresql` service by name.
data "docker_network" "db" {
  name = var.db_network_name
}

resource "docker_service" "tomcat_service" {
  name = "tomcat-app-service"

  task_spec {
    container_spec {
      # An exact patch tag: readable in `docker service ps` and pulled by whichever node
      # runs the task. (A docker_image image_id is node-local: workers can't pull it.)
      image = var.tomcat_image

      configs {
        config_id   = docker_config.tomcat_server_xml.id
        config_name = docker_config.tomcat_server_xml.name
        file_name   = "/usr/local/tomcat/conf/server.xml"
      }

      configs {
        config_id   = docker_config.index_html.id
        config_name = docker_config.index_html.name
        file_name   = "/usr/local/tomcat/webapps/ROOT/index.html"
      }

      configs {
        config_id   = docker_config.health_ping.id
        config_name = docker_config.health_ping.name
        file_name   = "/usr/local/tomcat/healthapps/ping/index.html"
      }

      # Shared classpath; contains the DB password.
      secrets {
        secret_id   = docker_secret.app_properties.id
        secret_name = docker_secret.app_properties.name
        file_name   = "/usr/local/tomcat/lib/application.properties"
      }
    }

    networks_advanced {
      id = data.docker_network.db.id
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

  mode {
    replicated {
      replicas = var.service_replicas
    }
  }

  endpoint_spec {
    ports {
      target_port    = var.http_port
      published_port = var.http_port
      publish_mode   = "ingress"
    }

    ports {
      target_port    = var.health_check_port
      published_port = var.health_check_port
      publish_mode   = "ingress"
    }
  }
}
