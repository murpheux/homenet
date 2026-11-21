# modules/sqlserver/outputs.tf

output "service_id" {
  description = "SQL Server docker service ID"
  value       = docker_service.sqlserver.id
}

output "service_name" {
  description = "SQL Server docker service name (softcraftjorge)"
  value       = docker_service.sqlserver.name
}

output "service_replica_id" {
  description = "SQL Server service replica/task ID (endpoint_spec replicated replica)"
  value       = docker_service.sqlserver.endpoint_spec[0].virtual_ips[0].virtual_ip
}
