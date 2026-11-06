# main.tf

resource "docker_network" "db_net" {
  name   = "db_net"
  driver = "overlay"
}

# Each database is pinned to one node, next to its node-local data volume.
# mysql:8.0 (Oracle Linux 9) needs x86-64-v2 and mongo:7 needs AVX, which only scarlet
# has; SQL Server stays on scarlet with its existing NFS data. postgres:16 and
# redis:7-alpine run on any x86-64 CPU, so they go to the otherwise idle workers.
# Moving a database to another node means a new, empty volume there: dump it first.
locals {
  db_nodes = {
    mysql      = "softcraftscarlet"
    mongodb    = "softcraftscarlet"
    sqlserver  = "softcraftscarlet"
    postgresql = "softcraftcassandra"
    redis      = "softcraftgru"
  }
}

# -------------------------
# Node-local data volumes
# -------------------------
# Local, not NFS: the export uses -mapall=nobody, so the mysql, postgres, mongo and
# redis entrypoints' chown of their data directory fails and the task exits (and
# postgres refuses a data directory it doesn't own).
# A volume must exist on the node its service runs on, so each one is created through
# that node's daemon (provider alias), not the manager's.

# scarlet
resource "docker_volume" "local" {
  for_each = toset(["mysql_data", "mongodb_data"])

  name   = "${each.key}_local"
  driver = "local"
}

# cass
resource "docker_volume" "postgresql_data" {
  provider = docker.cass

  name   = "postgresql_data_local"
  driver = "local"
}

# gru
resource "docker_volume" "redis_data" {
  provider = docker.gru

  name   = "redis_data_local"
  driver = "local"
}

# -------------------------
# NFS-backed volumes (SQL Server only)
# -------------------------
# medusa:/System/Volumes/Data/Users/Shared/nfs_share/docker_volumes/database/<db>/<subdir>
# Mounted by IP so the volumes don't depend on DNS. SQL Server's data stays here because
# it already holds data (mssql runs as uid 10001 and doesn't chown). The other databases
# have no NFS mounts: Docker copies an image directory's permissions onto an empty volume
# mounted over it, and that chmod fails as nobody, so the task is rejected. Their config
# directories were empty anyway.
locals {
  nfs_server    = "10.10.2.100"
  nfs_base_path = "/System/Volumes/Data/Users/Shared/nfs_share/docker_volumes/database"
  nfs_mount_opt = "addr=${local.nfs_server},rw,resvport,nolock,soft,v3"

  # key = "<db>_<subdir>"; the Docker volume name is "<key>_nfs".
  nfs_volumes = {
    sqlserver_data   = "sqlserver/data"
    sqlserver_config = "sqlserver/config"
  }
}

resource "docker_volume" "nfs" {
  for_each = local.nfs_volumes

  name   = "${each.key}_nfs"
  driver = "local"
  driver_opts = {
    type   = "nfs"
    device = ":${local.nfs_base_path}/${each.value}"
    o      = local.nfs_mount_opt
  }
}


# -------------------------
# Database Services
# -------------------------

module "mysql" {
  source                = "./modules/mysql"
  mysql_root_password   = var.mysql_root_password
  mysql_database        = "appdb"
  data_volume           = docker_volume.local["mysql_data"].name
  network               = docker_network.db_net.id
  placement_constraints = ["node.hostname == ${local.db_nodes.mysql}"]
}

module "mongodb" {
  source                = "./modules/mongodb"
  mongo_user            = var.mongo_user
  mongo_password        = var.mongo_password
  mongo_database        = "appdb"
  data_volume           = docker_volume.local["mongodb_data"].name
  network               = docker_network.db_net.id
  placement_constraints = ["node.hostname == ${local.db_nodes.mongodb}"]
}

module "postgresql" {
  source                = "./modules/postgresql"
  postgres_user         = var.postgres_user
  postgres_password     = var.postgres_password
  postgres_db           = "appdb"
  data_volume           = docker_volume.postgresql_data.name
  network               = docker_network.db_net.id
  placement_constraints = ["node.hostname == ${local.db_nodes.postgresql}"]
}

module "sqlserver" {
  source                = "./modules/sqlserver"
  sqlserver_sa_password = var.sqlserver_sa_password
  data_volume           = docker_volume.nfs["sqlserver_data"].name
  config_volume         = docker_volume.nfs["sqlserver_config"].name
  network               = docker_network.db_net.id
  placement_constraints = ["node.hostname == ${local.db_nodes.sqlserver}"]
}

module "redis" {
  source                = "./modules/redis"
  redis_password        = var.redis_password
  data_volume           = docker_volume.redis_data.name
  network               = docker_network.db_net.id
  placement_constraints = ["node.hostname == ${local.db_nodes.redis}"]
}
