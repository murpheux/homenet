# modules/prometheus/outputs.tf

output "service_id" {
  description = "Prometheus docker service ID"
  value       = docker_service.prometheus.id
}

output "service_name" {
  description = "Prometheus docker service name (softcraftbelle); resolves on the monitoring network."
  value       = docker_service.prometheus.name
}

output "service_replica_id" {
  description = "Prometheus service replica/task ID (endpoint_spec replicated replica)"
  value       = docker_service.prometheus.endpoint_spec[0].virtual_ips[0].virtual_ip
}
