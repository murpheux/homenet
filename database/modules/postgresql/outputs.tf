# modules/postgresql/outputs.tf

output "service_id" {
  description = "PostgreSQL docker service ID"
  value       = docker_service.postgresql.id
}

output "service_name" {
  description = "PostgreSQL docker service name (softcraftmark)"
  value       = docker_service.postgresql.name
}

output "service_replica_id" {
  description = "PostgreSQL service replica/task ID (endpoint_spec replicated replica)"
  value       = docker_service.postgresql.endpoint_spec[0].virtual_ips[0].virtual_ip
}
