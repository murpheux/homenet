# modules/cadvisor/outputs.tf

output "service_id" {
  description = "cAdvisor docker service ID (global service, one task per node)"
  value       = docker_service.cadvisor.id
}

output "service_name" {
  description = "cAdvisor docker service name (softcraftchow)"
  value       = docker_service.cadvisor.name
}
