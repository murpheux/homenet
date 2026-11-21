# modules/mongodb/outputs.tf

output "service_id" {
  description = "MongoDB docker service ID"
  value       = docker_service.mongodb.id
}

output "service_name" {
  description = "MongoDB docker service name (softcraftjerry)"
  value       = docker_service.mongodb.name
}

output "service_replica_id" {
  description = "MongoDB service replica/task ID (endpoint_spec replicated replica)"
  value       = docker_service.mongodb.endpoint_spec[0].virtual_ips[0].virtual_ip
}
