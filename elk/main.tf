# main.tf

terraform {
  required_version = ">= 1.15.7"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = ">= 4.6.0"
    }

    elasticstack = {
      source  = "elastic/elasticstack"
      version = "~> 0.16"
    }
  }

  # State in Terraform Cloud, like the other stacks. The workspace must use Local
  # execution: the Docker contexts and op run only exist on medusa.
  cloud {
    organization = "softcraft"

    workspaces {
      name = "homenet-elk"
    }
  }
}

# Swarm manager: services, secrets, the overlay network, scarlet's volumes.
provider "docker" {
  context = "murpheux-scarlet"
}

# Worker daemon, used only to create Kibana's node-local data volume on gru.
provider "docker" {
  alias   = "gru"
  context = "murpheux-gru"
}

# Manages built-in and Filebeat users once Elasticsearch is up (first deploy: make bootstrap).
provider "elasticstack" {
  elasticsearch {
    username  = "elastic"
    password  = var.elastic_password
    endpoints = [var.elasticsearch_url]
  }
}

# -------------------------
# Placement
# -------------------------
# Elasticsearch stays on scarlet: its es_data volume is there, and it needs the memory.
# Kibana moves to gru to take load off scarlet. If Kibana won't start on gru's older CPU
# (illegal instruction / x86-64-v2 errors), set kibana = "softcraftscarlet".
locals {
  elk_version = var.elastic_version

  elk_nodes = {
    elasticsearch = "softcraftscarlet"
    kibana        = "softcraftgru"
    logstash      = "softcraftscarlet"
  }
}

# -------------------------
# Network
# -------------------------
resource "docker_network" "elk" {
  name       = "elk_net"
  driver     = "overlay"
  attachable = true
}

# -------------------------
# Kibana data volume (gru)
# -------------------------
resource "docker_volume" "kibana_data" {
  provider = docker.gru

  name   = "kibana_data_local"
  driver = "local"
}

# -------------------------
# Elasticsearch
# -------------------------
module "elasticsearch" {
  source                = "./modules/elasticsearch"
  image                 = "docker.elastic.co/elasticsearch/elasticsearch:${local.elk_version}"
  network               = docker_network.elk.id
  elastic_password      = var.elastic_password
  placement_constraints = ["node.hostname == ${local.elk_nodes.elasticsearch}"]
}

# -------------------------
# Users (elastic/elasticstack provider)
# -------------------------
# Kibana 8 refuses the elastic superuser; it signs in as the built-in kibana_system.
resource "elasticstack_elasticsearch_security_system_user" "kibana_system" {
  depends_on = [module.elasticsearch]

  username = "kibana_system"
  password = var.kibana_system_password
}

# Least privilege for Filebeat: set up its index template, ILM policy and data stream,
# then append documents. No read access to other indices.
resource "elasticstack_elasticsearch_security_role" "filebeat_writer" {
  depends_on = [module.elasticsearch]

  name    = "filebeat_writer"
  cluster = ["monitor", "read_ilm", "read_pipeline", "manage_ilm", "manage_index_templates"]

  indices {
    names      = ["filebeat-*"]
    privileges = ["create_doc", "view_index_metadata", "auto_configure", "manage"]
  }
}

resource "elasticstack_elasticsearch_security_user" "filebeat_writer" {
  username = "filebeat_writer"
  password = var.filebeat_password
  roles    = [elasticstack_elasticsearch_security_role.filebeat_writer.name]
}

# -------------------------
# Kibana
# -------------------------
module "kibana" {
  source = "./modules/kibana"
  image  = "docker.elastic.co/kibana/kibana:${local.elk_version}"
  config = templatefile("${path.module}/config/kibana.yml", {
    kibana_system_password = var.kibana_system_password
    encryption_key         = var.kibana_encryption_key
  })
  network               = docker_network.elk.id
  data_volume           = docker_volume.kibana_data.name
  placement_constraints = ["node.hostname == ${local.elk_nodes.kibana}"]

  depends_on = [elasticstack_elasticsearch_security_system_user.kibana_system]
}

# -------------------------
# Filebeat (every node)
# -------------------------
module "filebeat" {
  source = "./modules/filebeat"
  image  = "docker.elastic.co/beats/filebeat:${local.elk_version}"
  config = templatefile("${path.module}/config/filebeat.yml", {
    filebeat_password = var.filebeat_password
  })
  network = docker_network.elk.id

  depends_on = [elasticstack_elasticsearch_security_user.filebeat_writer]
}

# -------------------------
# Logstash (optional)
# -------------------------
# No pipeline uses it (Filebeat ships straight to Elasticsearch), so it's off by default.
module "logstash" {
  source = "./modules/logstash"
  count  = var.enable_logstash ? 1 : 0

  image                 = "docker.elastic.co/logstash/logstash:${local.elk_version}"
  network               = docker_network.elk.id
  placement_constraints = ["node.hostname == ${local.elk_nodes.logstash}"]

  depends_on = [module.elasticsearch]
}
