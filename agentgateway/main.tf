terraform {
  required_version = ">= 1.15.7"

  cloud {
    organization = "softcraft"

    workspaces {
      name = "homenet-agentgateway"
    }
  }

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = ">= 4.6.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">=3.2.0"
    }
  }
}

provider "docker" {
  context = "murpheux-scarlet"
}

# Upstream LLM provider credentials, passed to the container as environment
# variables and expanded by agentgateway in agentgateway.yaml. Supply them at
# apply time, e.g. `op run --env-file=op.env -- terraform apply` (see op.env).
# Defaults are empty so the stack still applies; a model with an empty key only
# fails when it is actually called.
variable "anthropic_api_key" {
  description = "Anthropic API key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "deepseek_api_key" {
  description = "DeepSeek API key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "openai_api_key" {
  description = "OpenAI API key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "openrouter_api_key" {
  description = "OpenRouter API key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "gemini_api_key" {
  description = "Google Gemini API key"
  type        = string
  sensitive   = true
  default     = ""
}

# No defaults: a missing 1Password reference fails at plan instead of breaking requests.
variable "claude_enterprise_api_key" {
  description = "Anthropic enterprise API key (claude-enterprise provider)"
  type        = string
  sensitive   = true
}

variable "lm_studio_api_key" {
  description = "LM Studio API key (llm-studio provider)"
  type        = string
  sensitive   = true
}

# 1. Config files as Swarm configs, from the repo.
# They used to come from an NFS share mounted at /config. A slow or unreachable NFS
# server blocked container start (task stuck in "Starting", no logs, port refused).
# Configs are content-hashed: a changed file creates a new config and rolls the service.
locals {
  agentgateway_config_files = {
    agentgateway_yaml = "${path.module}/agentgateway.yaml"
    base_costs_json   = "${path.module}/base-costs.json"
  }
}

resource "docker_config" "agentgateway" {
  for_each = local.agentgateway_config_files

  name = "agentgateway_${each.key}_${substr(filesha256(each.value), 0, 12)}"
  data = filebase64(each.value)

  lifecycle {
    create_before_destroy = true
  }
}

# The old NFS volume definition: forget it without deleting it (a stuck task may still
# hold it). Remove by hand once unused: docker --context=murpheux-scarlet volume rm agentgateway_nfs_volume
removed {
  from = docker_volume.agentgateway_nfs_data

  lifecycle {
    destroy = false
  }
}

# 1b. Node-local volume for the state database.
# SQLite MUST NOT live on the NFS export: the mount uses `nolock` and SQLite's
# WAL/shared-memory files rely on mmap + POSIX locks, which is unsafe over NFS and
# can wedge nfsd. Keep the database on the node's local disk instead. The config
# points at /state/agentgateway.db (see agentgateway.yaml).
resource "docker_volume" "agentgateway_state" {
  name   = "agentgateway_state"
  driver = "local"
}

# Docker creates local volumes owned by root; the service runs as 1000:1000, so
# hand the volume to that uid once with a throwaway container.
resource "null_resource" "agentgateway_state_perms" {
  triggers = {
    volume = docker_volume.agentgateway_state.id
  }

  provisioner "local-exec" {
    command = "docker --context=murpheux-scarlet run --rm -v ${docker_volume.agentgateway_state.name}:/state alpine chown 1000:1000 /state"
  }

  depends_on = [docker_volume.agentgateway_state]
}

# 1c. TLS material and UI credentials as Swarm secrets (encrypted in the Raft log,
# mounted on tmpfs) instead of world-readable files on the NFS share. Sources are the
# git-ignored local copies. Secrets are immutable: the content hash in each name makes
# a changed file create a new secret, and create_before_destroy swaps it in first.
locals {
  agentgateway_secret_files = {
    tls_cert    = "${path.module}/tls/cert.pem"
    tls_key     = "${path.module}/tls/key.pem"
    ui_htpasswd = "${path.module}/ui.htpasswd"
  }
}

resource "docker_secret" "agentgateway" {
  for_each = local.agentgateway_secret_files

  name = "agentgateway_${each.key}_${substr(filesha256(each.value), 0, 12)}"
  data = filebase64(each.value)

  lifecycle {
    create_before_destroy = true
  }
}

# 2. Docker Swarm Service for Agentgateway
#
# The LLM API and the built-in UI run in the SAME agentgateway process on port 9443
# (UI at https://<host>:9443/ui), matching the stock docker-compose behaviour but
# over HTTPS. There is no separate UI image, and the `agentgateway`/`agctl`
# binaries have no `ui` subcommand.
resource "docker_service" "agentgateway" {
  name = "softcraftgenia"

  task_spec {
    container_spec {
      image = "cr.agentgateway.dev/agentgateway:v1.7.0"

      # User 1000:1000 from original docker-compose
      user = "1000:1000"

      # The image defaults to /config/config.yaml and auto-generates a config when
      # that file is absent. We ship a pre-baked agentgateway.yaml instead, so point
      # the binary at it explicitly.
      args = ["-f", "/config/agentgateway.yaml"]

      # Upstream provider credentials, expanded by agentgateway.yaml.
      env = {
        "TZ"                        = "America/Edmonton"
        "ANTHROPIC_API_KEY"         = var.anthropic_api_key
        "DEEPSEEK_API_KEY"          = var.deepseek_api_key
        "OPENAI_API_KEY"            = var.openai_api_key
        "OPENROUTER_API_KEY"        = var.openrouter_api_key
        "GEMINI_API_KEY"            = var.gemini_api_key
        "CLAUDE_ENTERPRISE_API_KEY" = var.claude_enterprise_api_key
        "LM_STUDIO_API_KEY"         = var.lm_studio_api_key
      }

      # Read-only config files (paths referenced by agentgateway.yaml and args).
      configs {
        config_id   = docker_config.agentgateway["agentgateway_yaml"].id
        config_name = docker_config.agentgateway["agentgateway_yaml"].name
        file_name   = "/config/agentgateway.yaml"
        file_uid    = "1000"
        file_gid    = "1000"
        file_mode   = 292
      }
      configs {
        config_id   = docker_config.agentgateway["base_costs_json"].id
        config_name = docker_config.agentgateway["base_costs_json"].name
        file_name   = "/config/base-costs.json"
        file_uid    = "1000"
        file_gid    = "1000"
        file_mode   = 292
      }

      # Node-local state volume for the SQLite database (never NFS).
      mounts {
        target = "/state"
        source = docker_volume.agentgateway_state.name
        type   = "volume"
      }

      # Referenced by agentgateway.yaml. file_mode is decimal: 292 = 0444, 256 = 0400.
      secrets {
        secret_id   = docker_secret.agentgateway["tls_cert"].id
        secret_name = docker_secret.agentgateway["tls_cert"].name
        file_name   = "/run/secrets/agentgateway-tls-cert.pem"
        file_uid    = "1000"
        file_gid    = "1000"
        file_mode   = 292
      }
      secrets {
        secret_id   = docker_secret.agentgateway["tls_key"].id
        secret_name = docker_secret.agentgateway["tls_key"].name
        file_name   = "/run/secrets/agentgateway-tls-key.pem"
        file_uid    = "1000"
        file_gid    = "1000"
        file_mode   = 256
      }
      secrets {
        secret_id   = docker_secret.agentgateway["ui_htpasswd"].id
        secret_name = docker_secret.agentgateway["ui_htpasswd"].name
        file_name   = "/run/secrets/agentgateway-ui.htpasswd"
        file_uid    = "1000"
        file_gid    = "1000"
        file_mode   = 256
      }
    }

    # Wait between restarts instead of a tight crash loop (delay 0s restarted instantly).
    restart_policy {
      condition = "any"
      delay     = "10s"
      window    = "60s"
    }

    # The upstream image's Chainguard glibc runtime requires the x86-64-v2
    # microarchitecture (SSE4.2 + POPCNT). softcraftgru is a Core 2 Duo P8800 which
    # lacks these and aborts with "Fatal glibc error: CPU does not support x86-64-v2"
    # (exit 127). Pin the workload to softcraftscarlet (Haswell / x86-64-v3 capable).
    placement {
      constraints = ["node.hostname == softcraftscarlet"]
    }
  }

  mode {
    replicated {
      replicas = 1
    }
  }

  endpoint_spec {
    ports {
      name           = "gateway-9443"
      target_port    = 9443
      published_port = 9443
      publish_mode   = "ingress"
    }

    # Plain HTTP ingress; the gateway 301-redirects it to HTTPS on 9443. The container
    # runs as uid 1000, so it listens on 8080 internally. Published as 8082, not 80
    # (openclaw's Traefik) or 8081 (tomcat health): ingress ports are cluster-wide.
    ports {
      name           = "http-8082"
      target_port    = 8080
      published_port = 8082
      publish_mode   = "ingress"
    }
  }

  depends_on = [null_resource.agentgateway_state_perms]
}
