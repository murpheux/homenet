# modules/loki/outputs.tf

output "service_id" {
  description = "Loki docker service ID"
  value       = docker_service.loki.id
}

output "service_name" {
  description = "Loki docker service name (softcraftmel); resolves on the monitoring network."
  value       = docker_service.loki.name
}

output "service_replica_id" {
  description = "Loki service replica/task ID (endpoint_spec replicated replica)"
  value       = docker_service.loki.endpoint_spec[0].virtual_ips[0].virtual_ip
}
