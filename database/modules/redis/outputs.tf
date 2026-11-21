# modules/redis/outputs.tf

output "service_id" {
  description = "Redis docker service ID"
  value       = docker_service.redis.id
}

output "service_name" {
  description = "Redis docker service name (softcraftron)"
  value       = docker_service.redis.name
}

output "service_replica_id" {
  description = "Redis service replica/task ID (endpoint_spec replicated replica)"
  value       = docker_service.redis.endpoint_spec[0].virtual_ips[0].virtual_ip
}
