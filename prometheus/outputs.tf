# outputs.tf - Prometheus/Monitoring Stack Container/Service IDs

# Prometheus Service
output "prometheus_service_id" {
  description = "Prometheus service ID"
  value       = module.prometheus.service_id
}

output "prometheus_service_name" {
  description = "Prometheus service name (softcraftbelle)"
  value       = module.prometheus.service_name
}

# Grafana Service
output "grafana_service_id" {
  description = "Grafana service ID"
  value       = module.grafana.service_id
}

output "grafana_service_name" {
  description = "Grafana service name (softcraftbob)"
  value       = module.grafana.service_name
}

# Loki Service (Log aggregation)
output "loki_service_id" {
  description = "Loki service ID"
  value       = module.loki.service_id
}

output "loki_service_name" {
  description = "Loki service name (softcraftmel)"
  value       = module.loki.service_name
}

# cAdvisor Service (Container metrics)
output "cadvisor_service_id" {
  description = "cAdvisor service ID (global, one per node)"
  value       = module.cadvisor.service_id
}

output "cadvisor_service_name" {
  description = "cAdvisor service name (softcraftchow)"
  value       = module.cadvisor.service_name
}

# Monitoring Network
output "monitoring_network_id" {
  description = "Monitoring overlay network ID"
  value       = docker_network.monitoring.id
}

output "monitoring_network_name" {
  description = "Monitoring overlay network name"
  value       = docker_network.monitoring.name
}

# Data Volumes
output "prometheus_data_volume" {
  description = "Prometheus local data volume name"
  value       = docker_volume.prometheus_data.name
}

output "grafana_data_volume" {
  description = "Grafana local data volume name"
  value       = docker_volume.grafana_data.name
}

output "loki_data_volume" {
  description = "Loki local data volume name"
  value       = docker_volume.loki_data.name
}
