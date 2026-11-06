terraform {
  required_version = ">= 1.15.7"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = ">= 4.6.0"
    }

    grafana = {
      source  = "grafana/grafana"
      version = "~> 4.36.0"
    }
  }

  # State in Terraform Cloud, like the other stacks. The workspace must use Local
  # execution: the Docker contexts and op run only exist on medusa.
  cloud {
    organization = "softcraft"

    workspaces {
      name = "homenet-prometheus"
    }
  }
}

# Swarm manager: services, configs, secrets, the overlay network.
provider "docker" {
  context = "murpheux-scarlet"
}

# Worker daemons, used only to create node-local data volumes on those nodes.
provider "docker" {
  alias   = "gru"
  context = "murpheux-gru"
}

provider "docker" {
  alias   = "cass"
  context = "murpheux-cass"
}

# Admin basic auth by default: it works on a brand-new Grafana, because Terraform sets
# those credentials itself (GF_SECURITY_ADMIN_*). A service-account token is used
# instead when grafana_auth_token is set.
provider "grafana" {
  url  = var.grafana_url
  auth = var.grafana_auth_token != "" ? var.grafana_auth_token : "${var.grafana_admin_user}:${var.grafana_admin_password}"
}

# -------------------------
# Placement
# -------------------------
# Off scarlet (it runs MySQL, MongoDB, SQL Server and agentgateway). All images are
# plain amd64 builds, so the x86-64-v1 workers can run them. Each service's data
# volume lives on its node, so changing a node here starts that service empty there.
locals {
  monitoring_nodes = {
    prometheus = "softcraftcassandra"
    grafana    = "softcraftgru"
    loki       = "softcraftgru"
  }
}

# -------------------------
# Network
# -------------------------
resource "docker_network" "monitoring" {
  name   = "monitoring_network"
  driver = "overlay"
}

# -------------------------
# Node-local data volumes
# -------------------------
# Created through each node's own daemon: a volume must exist where its service runs.
resource "docker_volume" "prometheus_data" {
  provider = docker.cass

  name   = "prometheus_data_local"
  driver = "local"
}

resource "docker_volume" "grafana_data" {
  provider = docker.gru

  name   = "grafana_data_local"
  driver = "local"
}

resource "docker_volume" "loki_data" {
  provider = docker.gru

  name   = "loki_data_local"
  driver = "local"
}

# -------------------------
# Modules
# -------------------------
module "prometheus" {
  source                = "./modules/prometheus"
  network               = docker_network.monitoring.id
  data_volume           = docker_volume.prometheus_data.name
  config_file           = "${path.module}/config/prometheus.yaml"
  placement_constraints = ["node.hostname == ${local.monitoring_nodes.prometheus}"]
}

module "grafana" {
  source                 = "./modules/grafana"
  grafana_admin_user     = var.grafana_admin_user
  grafana_admin_password = var.grafana_admin_password
  grafana_admin_email    = var.grafana_admin_email
  network                = docker_network.monitoring.id
  data_volume            = docker_volume.grafana_data.name
  placement_constraints  = ["node.hostname == ${local.monitoring_nodes.grafana}"]
}

module "loki" {
  source                = "./modules/loki"
  network               = docker_network.monitoring.id
  data_volume           = docker_volume.loki_data.name
  config_file           = "${path.module}/config/config.yaml"
  placement_constraints = ["node.hostname == ${local.monitoring_nodes.loki}"]
}

# One cAdvisor per node, so every host's containers are measured.
module "cadvisor" {
  source  = "./modules/cadvisor"
  network = docker_network.monitoring.id
}

# -------------------------
# Grafana datasources
# -------------------------
# Service names resolve on monitoring_network. Created through the Grafana API, so
# Grafana must be up and grafana_auth_token valid (see README: first deploy).
resource "grafana_data_source" "prometheus" {
  depends_on = [module.grafana]

  type        = "prometheus"
  name        = "Prometheus"
  url         = "http://${module.prometheus.service_name}:9090"
  access_mode = "proxy"
  is_default  = true

  json_data_encoded = jsonencode({
    httpMethod = "POST"
  })
}

resource "grafana_data_source" "loki" {
  depends_on = [module.grafana]

  type        = "loki"
  name        = "Loki"
  url         = "http://${module.loki.service_name}:3100"
  access_mode = "proxy"
}

