# modules/loki/outputs.tf

output "service_name" {
  description = "Swarm service name; resolves on the monitoring network."
  value       = docker_service.loki.name
}
