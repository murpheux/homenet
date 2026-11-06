variable "domain_name" {
  description = "The domain name for OpenClaw (e.g., openclaw.homelab.local)"
  type        = string
  default     = "openclaw.local"
}

variable "admin_username" {
  description = "Admin username for OpenClaw UI"
  type        = string
  default     = "admin"
}

variable "admin_password" {
  description = "Admin password for OpenClaw UI"
  type        = string
  sensitive   = true
}

variable "ai_api_key" {
  description = "Your primary AI API Key (e.g., Anthropic - also mapped to Hermes)"
  type        = string
  sensitive   = true
}

variable "deepseek_api_key" {
  description = "API Key for DeepSeek (Default Provider)"
  type        = string
  sensitive   = true
}

variable "openai_api_key" {
  description = "API Key for OpenAI"
  type        = string
  sensitive   = true
}

variable "openrouter_api_key" {
  description = "API Key for OpenRouter"
  type        = string
  sensitive   = true
}

variable "gemini_api_key" {
  description = "API Key for Google Gemini"
  type        = string
  sensitive   = true
}

variable "nfs_server_ip" {
  description = "IP address of the NFS server"
  type        = string
  default     = "10.10.2.100"
}

variable "nfs_base_path" {
  description = "Base path on the NFS server for Docker volumes"
  type        = string
  default     = ":/System/Volumes/Data/Users/Shared/nfs_share/docker_volumes"
}

variable "nfs_mount_opts" {
  description = "NFS mount options"
  type        = string
  default     = "addr=10.10.2.100,rw,resvport,nolock,soft,v3"
}

variable "openclaw_client_htpasswd" {
  description = "htpasswd string for Traefik basic auth to access OpenClaw"
  type        = string
  sensitive   = true
}

variable "openclaw_gateway_token" {
  description = "Gateway token required by OpenClaw (OPENCLAW_GATEWAY_TOKEN)"
  type        = string
  sensitive   = true
}
