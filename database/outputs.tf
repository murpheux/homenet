# outputs.tf - Database Stack Container/Service IDs

# MySQL Service
output "mysql_service_id" {
  description = "MySQL service ID"
  value       = module.mysql.service_id
}

output "mysql_service_name" {
  description = "MySQL service name (softcraftdave)"
  value       = module.mysql.service_name
}

# MongoDB Service
output "mongodb_service_id" {
  description = "MongoDB service ID"
  value       = module.mongodb.service_id
}

output "mongodb_service_name" {
  description = "MongoDB service name (softcraftkimmy)"
  value       = module.mongodb.service_name
}

# PostgreSQL Service
output "postgresql_service_id" {
  description = "PostgreSQL service ID"
  value       = module.postgresql.service_id
}

output "postgresql_service_name" {
  description = "PostgreSQL service name (softcraftmark)"
  value       = module.postgresql.service_name
}

# Redis Service
output "redis_service_id" {
  description = "Redis service ID"
  value       = module.redis.service_id
}

output "redis_service_name" {
  description = "Redis service name (softcraftreo)"
  value       = module.redis.service_name
}

# SQL Server Service
output "sqlserver_service_id" {
  description = "SQL Server service ID"
  value       = module.sqlserver.service_id
}

output "sqlserver_service_name" {
  description = "SQL Server service name (softcraftallen)"
  value       = module.sqlserver.service_name
}

# Database Network
output "db_network_id" {
  description = "Database overlay network ID"
  value       = docker_network.db_net.id
}

output "db_network_name" {
  description = "Database overlay network name"
  value       = docker_network.db_net.name
}

# Data Volumes
output "mysql_data_volume" {
  description = "MySQL local data volume name"
  value       = docker_volume.local["mysql_data"].name
}

output "mongodb_data_volume" {
  description = "MongoDB local data volume name"
  value       = docker_volume.local["mongodb_data"].name
}

output "postgresql_data_volume" {
  description = "PostgreSQL local data volume name"
  value       = docker_volume.postgresql_data.name
}

output "redis_data_volume" {
  description = "Redis local data volume name"
  value       = docker_volume.redis_data.name
}

output "sqlserver_data_volume" {
  description = "SQL Server NFS data volume name"
  value       = docker_volume.nfs["sqlserver_data"].name
}

output "sqlserver_config_volume" {
  description = "SQL Server NFS config volume name"
  value       = docker_volume.nfs["sqlserver_config"].name
}
