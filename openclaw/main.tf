module "tls" {
  source      = "./modules/tls"
  domain_name = var.domain_name
}

module "network" {
  source = "./modules/network"
}

module "traefik" {
  source     = "./modules/traefik"
  network_id = module.network.network_id
  tls_cert   = module.tls.server_cert
  tls_key    = module.tls.server_key
}

module "openclaw" {
  source         = "./modules/openclaw"
  domain_name    = var.domain_name
  network_id     = module.network.network_id
  admin_username = var.admin_username
  admin_password = var.admin_password

  ai_api_key         = var.ai_api_key
  deepseek_api_key   = var.deepseek_api_key
  openai_api_key     = var.openai_api_key
  openrouter_api_key = var.openrouter_api_key
  gemini_api_key     = var.gemini_api_key

  nfs_server_ip            = var.nfs_server_ip
  nfs_base_path            = var.nfs_base_path
  nfs_mount_opts           = var.nfs_mount_opts
  openclaw_client_htpasswd = var.openclaw_client_htpasswd
  openclaw_gateway_token   = var.openclaw_gateway_token

  depends_on = [module.traefik]
}

module "hermes" {
  source      = "./modules/hermes"
  domain_name = var.domain_name
  network_id  = module.network.network_id
  ai_api_key  = var.ai_api_key

  nfs_server_ip  = var.nfs_server_ip
  nfs_base_path  = var.nfs_base_path
  nfs_mount_opts = var.nfs_mount_opts
}
