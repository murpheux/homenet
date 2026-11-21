# outputs.tf - AgentGateway Stack Container/Service IDs

# AgentGateway Service
output "agentgateway_service_id" {
  description = "AgentGateway service ID"
  value       = docker_service.agentgateway.id
}

output "agentgateway_service_name" {
  description = "AgentGateway service name (softcraftgenia)"
  value       = docker_service.agentgateway.name
}

output "agentgateway_service_replica_id" {
  description = "AgentGateway service replica/task ID (endpoint_spec replicated replica)"
  value       = docker_service.agentgateway.endpoint_spec[0].virtual_ips[0].virtual_ip
}

# Data Volume (SQLite state database)
output "agentgateway_state_volume" {
  description = "AgentGateway SQLite state database local volume name"
  value       = docker_volume.agentgateway_state.name
}

output "agentgateway_state_volume_id" {
  description = "AgentGateway SQLite state database local volume ID"
  value       = docker_volume.agentgateway_state.id
}

# Configuration and Secrets (Swarm configs/secrets)
output "agentgateway_config_ids" {
  description = "AgentGateway config file IDs (content-hashed)"
  value = {
    for key, config in docker_config.agentgateway : key => config.id
  }
}

output "agentgateway_secret_ids" {
  description = "AgentGateway secret file IDs (content-hashed, encrypted at rest)"
  value = {
    for key, secret in docker_secret.agentgateway : key => secret.id
  }
}
