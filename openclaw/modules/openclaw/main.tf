terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = ">= 4.6.0"
    }
  }
}

resource "docker_volume" "openclaw_data_nfs_volume" {
  name   = "openclaw_data_nfs"
  driver = "local"
  driver_opts = {
    type   = "nfs"
    device = "${var.nfs_base_path}/openclaw/data"
    o      = var.nfs_mount_opts
  }
}

resource "docker_volume" "browser_data_nfs_volume" {
  name   = "openclaw_browser_data_nfs"
  driver = "local"
  driver_opts = {
    type   = "nfs"
    device = "${var.nfs_base_path}/openclaw/browser"
    o      = var.nfs_mount_opts
  }
}

# Mandatory sidecar: the coollabsio/openclaw image hardcodes an nginx upstream
# `http://browser:3000/` (noVNC) and expects CDP at `http://browser:9223`.
# nginx resolves upstreams at startup, so without this service openclaw exits 1.
# Service name MUST remain "browser" for swarm overlay DNS.
resource "docker_service" "browser" {
  name = "browser"

  task_spec {
    container_spec {
      image = "coollabsio/openclaw-browser:latest"

      env = {
        "PUID"       = "1000"
        "PGID"       = "1000"
        "TZ"         = "America/Edmonton"
        "CHROME_CLI" = "--remote-debugging-port=9222"
      }

      mounts {
        target = "/config"
        source = docker_volume.browser_data_nfs_volume.name
        type   = "volume"
      }

      # Equivalent of compose `shm_size: 2g` — Chromium needs a large /dev/shm.
      mounts {
        target = "/dev/shm"
        type   = "tmpfs"
        tmpfs_options {
          size_bytes = 2147483648
        }
      }

      healthcheck {
        test     = ["CMD-SHELL", "bash -c ':> /dev/tcp/127.0.0.1/9222' || exit 1"]
        interval = "5s"
        timeout  = "5s"
        retries  = 10
      }
    }

    placement {
      constraints = ["node.hostname != softcraftcassandra"]
    }

    networks_advanced {
      id = var.network_id
    }
  }

  mode {
    replicated {
      replicas = 1
    }
  }

  update_config {
    parallelism    = 1
    delay          = "10s"
    failure_action = "rollback"
    order          = "stop-first"
  }
}

resource "docker_secret" "openclaw_api_key" {
  name = "openclaw_api_key_${substr(md5(var.ai_api_key), 0, 8)}"
  data = base64encode(var.ai_api_key)
}

resource "docker_service" "openclaw" {
  name = "openclaw"

  task_spec {
    container_spec {
      image = "coollabsio/openclaw:latest"

      env = {
        "OPENCLAW_ALLOWED_ORIGINS" = "https://${var.domain_name}"
        "AUTH_USERNAME"            = var.admin_username
        "AUTH_PASSWORD"            = var.admin_password
        "OPENCLAW_GATEWAY_TOKEN"   = var.openclaw_gateway_token

        "ANTHROPIC_API_KEY" = var.ai_api_key
        "OPENAI_API_KEY"    = var.openai_api_key
        "GOOGLE_API_KEY"    = var.gemini_api_key

        "DEEPSEEK_API_KEY"   = var.deepseek_api_key
        "OPENROUTER_API_KEY" = var.openrouter_api_key

        "BROWSER_CDP_URL"                     = "http://browser:9223"
        "BROWSER_DEFAULT_PROFILE"             = "openclaw"
        "BROWSER_EVALUATE_ENABLED"            = "true"
        "BROWSER_SNAPSHOT_MODE"               = "efficient"
        "BROWSER_REMOTE_TIMEOUT_MS"           = "1500"
        "BROWSER_REMOTE_HANDSHAKE_TIMEOUT_MS" = "3000"

        "OPENCLAW_CONFIG_JSON" = jsonencode({
          models = {
            mode = "merge"
            providers = {
              deepseek = {
                baseUrl = "https://api.deepseek.com/v1"
                apiKey  = "$${DEEPSEEK_API_KEY}"
                api     = "openai-completions"
                models = [
                  {
                    id        = "deepseek-chat"
                    name      = "DeepSeek Chat (v3)"
                    input     = ["text"]
                    reasoning = false
                  },
                  {
                    id        = "deepseek-reasoner"
                    name      = "DeepSeek Reasoner (R1)"
                    input     = ["text"]
                    reasoning = true
                  }
                ]
              }
              # NOTE: openrouter is a built-in provider (keyed by OPENROUTER_API_KEY);
              # declaring it here is stripped by the image's configure step.
            }
          }
          agents = {
            defaults = {
              model = {
                primary = "deepseek/deepseek-chat"
              }
              # Model IDs must exist in the bundled catalog; retired refs
              # (claude-3-5-sonnet, gpt-4o, gemini-1.5-pro) are rejected by doctor.
              models = {
                "deepseek/deepseek-chat"                 = {}
                "deepseek/deepseek-reasoner"             = {}
                "anthropic/claude-sonnet-4-6"            = {}
                "openai/gpt-5.5"                         = {}
                "google/gemini-3.1-pro-preview"          = {}
                "openrouter/anthropic/claude-3.5-sonnet" = {}
                "openrouter/google/gemini-2.5-pro"       = {}
              }
            }
          }
        })
      }

      secrets {
        secret_id   = docker_secret.openclaw_api_key.id
        secret_name = docker_secret.openclaw_api_key.name
        file_name   = "/run/secrets/ai_api_key"
      }

      mounts {
        target = "/data"
        source = docker_volume.openclaw_data_nfs_volume.name
        type   = "volume"
      }

      healthcheck {
        test     = ["CMD", "curl", "-f", "http://localhost:8080/healthz"]
        interval = "30s"
        timeout  = "10s"
        retries  = 3
      }
    }

    placement {
      constraints = ["node.hostname != softcraftcassandra"]
    }

    networks_advanced {
      id = var.network_id
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

  labels {
    label = "traefik.enable"
    value = "true"
  }
  labels {
    label = "traefik.http.routers.openclaw.rule"
    value = "Host(`${var.domain_name}`)"
  }
  labels {
    label = "traefik.http.routers.openclaw.entrypoints"
    value = "websecure"
  }
  labels {
    label = "traefik.http.routers.openclaw.tls"
    value = "true"
  }
  labels {
    label = "traefik.http.services.openclaw.loadbalancer.server.port"
    value = "8080"
  }

  labels {
    label = "traefik.http.middlewares.openclaw-auth.basicauth.users"
    value = var.openclaw_client_htpasswd
  }
  labels {
    label = "traefik.http.routers.openclaw.middlewares"
    value = "openclaw-auth"
  }

  depends_on = [docker_service.browser]
}
