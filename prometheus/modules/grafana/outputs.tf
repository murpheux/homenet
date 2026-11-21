# modules/grafana/outputs.tf

output "service_id" {
  description = "Grafana docker service ID"
  value       = docker_service.grafana.id
}

output "service_name" {
  description = "Grafana docker service name (softcraftbob)"
  value       = docker_service.grafana.name
}

output "service_replica_id" {
  description = "Grafana service replica/task ID (endpoint_spec replicated replica)"
  value       = docker_service.grafana.endpoint_spec[0].virtual_ips[0].virtual_ip
}
