# modules/mysql/outputs.tf

output "service_id" {
  description = "MySQL docker service ID"
  value       = docker_service.mysql.id
}

output "service_name" {
  description = "MySQL docker service name (softcraftdave)"
  value       = docker_service.mysql.name
}

output "service_replica_id" {
  description = "MySQL service replica/task ID (endpoint_spec replicated replica)"
  value       = docker_service.mysql.endpoint_spec[0].virtual_ips[0].virtual_ip
}
