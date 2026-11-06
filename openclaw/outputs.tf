output "openclaw_url" {
  description = "The URL to access your OpenClaw instance"
  value       = "https://${var.domain_name}"
}

output "ca_certificate" {
  description = "The internal CA Certificate. Install this on your local devices to trust the connection."
  value       = module.tls.ca_cert
  sensitive   = true
}
