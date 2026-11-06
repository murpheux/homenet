output "service_name" {
  description = "The name of the created Docker service"
  value       = docker_service.tomcat_service.name
}

output "published_port" {
  description = "The port exposed on the host"
  value       = var.http_port
}