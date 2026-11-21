# Terraform Docker Outputs Summary

This document provides a comprehensive overview of all Terraform output files created to expose Docker container and service IDs when running `terraform apply`.

## Overview

The outputs are organized into three main stacks:
1. **Database Stack** (`database/`)
2. **Monitoring/Prometheus Stack** (`prometheus/`)
3. **AgentGateway Stack** (`agentgateway/`)
4. **Pi-hole Stack** (`pi-hole/`)

---

## 1. Database Stack (`database/`)

### Top-Level Outputs: `database/outputs.tf`

Aggregates all database service and volume IDs:

| Output | Description | Value |
|--------|-------------|-------|
| `mysql_service_id` | MySQL service ID | Module output |
| `mysql_service_name` | MySQL service name | `softcraftdave` |
| `mongodb_service_id` | MongoDB service ID | Module output |
| `mongodb_service_name` | MongoDB service name | `softcraftjerry` |
| `postgresql_service_id` | PostgreSQL service ID | Module output |
| `postgresql_service_name` | PostgreSQL service name | `softcraftmark` |
| `redis_service_id` | Redis service ID | Module output |
| `redis_service_name` | Redis service name | `softcraftron` |
| `sqlserver_service_id` | SQL Server service ID | Module output |
| `sqlserver_service_name` | SQL Server service name | `softcraftjorge` |
| `db_network_id` | Overlay network ID | Swarm network resource |
| `db_network_name` | Overlay network name | `db_net` |
| `mysql_data_volume` | MySQL local data volume | `mysql_data_local` |
| `mongodb_data_volume` | MongoDB local data volume | `mongodb_data_local` |
| `postgresql_data_volume` | PostgreSQL local data volume | `postgresql_data_local` |
| `redis_data_volume` | Redis local data volume | `redis_data_local` |
| `sqlserver_data_volume` | SQL Server NFS data volume | `sqlserver_data_nfs` |
| `sqlserver_config_volume` | SQL Server NFS config volume | `sqlserver_config_nfs` |

### Module Outputs

#### `database/modules/mysql/outputs.tf`
```hcl
output "service_id"       # Docker service ID
output "service_name"     # Service name: softcraftdave
output "service_replica_id" # Virtual IP for replicas
```

#### `database/modules/mongodb/outputs.tf`
```hcl
output "service_id"       # Docker service ID
output "service_name"     # Service name: softcraftjerry
output "service_replica_id" # Virtual IP for replicas
```

#### `database/modules/postgresql/outputs.tf`
```hcl
output "service_id"       # Docker service ID
output "service_name"     # Service name: softcraftmark
output "service_replica_id" # Virtual IP for replicas
```

#### `database/modules/redis/outputs.tf`
```hcl
output "service_id"       # Docker service ID
output "service_name"     # Service name: softcraftron
output "service_replica_id" # Virtual IP for replicas
```

#### `database/modules/sqlserver/outputs.tf`
```hcl
output "service_id"       # Docker service ID
output "service_name"     # Service name: softcraftjorge
output "service_replica_id" # Virtual IP for replicas
```

---

## 2. Prometheus/Monitoring Stack (`prometheus/`)

### Top-Level Outputs: `prometheus/outputs.tf`

Aggregates all monitoring service and volume IDs:

| Output | Description | Value |
|--------|-------------|-------|
| `prometheus_service_id` | Prometheus service ID | Module output |
| `prometheus_service_name` | Prometheus service name | `softcraftbelle` |
| `grafana_service_id` | Grafana service ID | Module output |
| `grafana_service_name` | Grafana service name | `softcraftbob` |
| `loki_service_id` | Loki service ID | Module output |
| `loki_service_name` | Loki service name | `softcraftmel` |
| `cadvisor_service_id` | cAdvisor service ID | Module output |
| `cadvisor_service_name` | cAdvisor service name | `softcraftchow` |
| `monitoring_network_id` | Overlay network ID | Swarm network resource |
| `monitoring_network_name` | Overlay network name | `monitoring_network` |
| `prometheus_data_volume` | Prometheus local data volume | `prometheus_data_local` |
| `grafana_data_volume` | Grafana local data volume | `grafana_data_local` |
| `loki_data_volume` | Loki local data volume | `loki_data_local` |

### Module Outputs

#### `prometheus/modules/prometheus/outputs.tf`
```hcl
output "service_id"       # Docker service ID
output "service_name"     # Service name: softcraftbelle
output "service_replica_id" # Virtual IP for replicas
```

#### `prometheus/modules/grafana/outputs.tf`
```hcl
output "service_id"       # Docker service ID
output "service_name"     # Service name: softcraftbob
output "service_replica_id" # Virtual IP for replicas
```

#### `prometheus/modules/loki/outputs.tf` (Enhanced)
```hcl
output "service_id"       # Docker service ID
output "service_name"     # Service name: softcraftmel
output "service_replica_id" # Virtual IP for replicas
```

#### `prometheus/modules/cadvisor/outputs.tf`
```hcl
output "service_id"       # Docker service ID (global service)
output "service_name"     # Service name: softcraftchow
# Note: cAdvisor is global (one task per node), no virtual_ip
```

---

## 3. AgentGateway Stack (`agentgateway/`)

### Outputs: `agentgateway/outputs.tf`

| Output | Description | Value |
|--------|-------------|-------|
| `agentgateway_service_id` | AgentGateway service ID | Docker service resource |
| `agentgateway_service_name` | AgentGateway service name | `softcraftgenia` |
| `agentgateway_service_replica_id` | Virtual IP for replicas | Endpoint spec VIP |
| `agentgateway_state_volume` | SQLite state DB volume name | `agentgateway_state` |
| `agentgateway_state_volume_id` | Volume resource ID | Docker volume resource |
| `agentgateway_config_ids` | Config file IDs (content-hashed) | Map of config IDs |
| `agentgateway_secret_ids` | Secret file IDs (content-hashed) | Map of secret IDs |

**Service Details:**
- **Service Name:** `softcraftgenia`
- **Port 9443:** HTTPS API + Web UI
- **Port 8082:** Plain HTTP (redirects to HTTPS)
- **Placement:** Pinned to `softcraftscarlet` (requires x86-64-v2+)

---

## 4. Pi-hole Stack (`pi-hole/`)

### Outputs: `pi-hole/outputs.tf`

**Note:** Pi-hole runs as a Docker container, NOT a Swarm service.

| Output | Description | Value |
|--------|-------------|-------|
| `pihole_container_id` | Container ID (not a service) | Docker container resource |
| `pihole_container_name` | Container name | `softcraftjim` |
| `pihole_container_image_id` | Image ID | Docker image hash |
| `pihole_network_id` | ipvlan network ID | Docker network resource |
| `pihole_network_name` | Network name | `pihole_ipvlan` |
| `pihole_ipv4_address` | Static IPv4 address | `10.10.2.7` |
| `pihole_ipv6_address` | Static IPv6 address | `fd00:10:10:2::5` |
| `pihole_image_id` | Image ID | Docker image resource |
| `pihole_image_repo_digest` | Content-addressed image hash | Registry digest |

**Container Details:**
- **Container Name:** `softcraftjim` (hostname: `softcraftjim`)
- **Image:** `pihole/pihole:latest`
- **Network:** ipvlan (parent: `enp3s0f0`)

---

## Usage Examples

### View All Outputs After `terraform apply`

```bash
# In database/ directory
terraform output

# In prometheus/ directory
terraform output

# In agentgateway/ directory
terraform output

# In pi-hole/ directory
terraform output
```

### View Specific Output

```bash
# Get MySQL service ID
terraform -chdir=database output mysql_service_id

# Get Grafana service name
terraform -chdir=prometheus output grafana_service_name

# Get AgentGateway state volume
terraform -chdir=agentgateway output agentgateway_state_volume
```

### JSON Output (for scripting)

```bash
# Get all outputs as JSON
terraform -chdir=database output -json

# Get specific output as JSON value
terraform -chdir=database output -json mysql_service_id | jq -r '.value'
```

### Verify Container IDs with Docker

After applying Terraform, verify containers with Docker:

```bash
# List swarm services
docker service ls

# Inspect a service and get task IDs
docker service ps softcraftdave   # MySQL
docker service ps softcraftbelle  # Prometheus
docker service ps softcraftgenia  # AgentGateway

# Inspect a container
docker container ls | grep softcraftjim  # Pi-hole

# Get detailed service info
docker service inspect softcraftdave --format='{{json .ID}}'
```

---

## Output Structure

### For Swarm Services

Each Swarm service output includes:

```hcl
output "service_id"
  # Swarm service ID (hex string)
  # Example: abc123def456...

output "service_name"
  # Human-readable service name
  # Example: softcraftdave (MySQL)

output "service_replica_id"
  # Virtual IP for the service (endpoint_spec.virtual_ips[0].virtual_ip)
  # Resolves to running task via DNS
```

### For Docker Container (Pi-hole)

```hcl
output "container_id"
  # Full container ID (hex string)

output "container_name"
  # Container name: softcraftjim

output "container_image_id"
  # Image hash/ID
```

### For Networks

```hcl
output "network_id"
  # Network resource ID

output "network_name"
  # Network name (db_net, monitoring_network, pihole_ipvlan)
```

### For Volumes

```hcl
output "volume_name"
  # Volume name (can be used with docker volume ls)

output "volume_id"
  # Volume resource ID
```

---

## Accessing Outputs in Root Module

The root-level `outputs.tf` files aggregate module outputs:

```hcl
# Example from database/outputs.tf
output "mysql_service_id" {
  value = module.mysql.service_id
}
```

This allows referencing module outputs directly from the root module:

```bash
terraform output mysql_service_id  # Gets module.mysql.service_id
```

---

## Content-Hashed Secrets and Configs

**AgentGateway** uses content-hashed secrets and configs:

```hcl
# Original config file hash in name:
# agentgateway_yaml_a1b2c3d4e5f6

# When file changes:
# agentgateway_yaml_z9y8x7w6v5u4

# Output references both old and new IDs for rollover
output "agentgateway_config_ids" {
  value = {
    for key, config in docker_config.agentgateway : key => config.id
  }
}
```

---

## Summary of All Services

| Service | Stack | Type | Service Name | Node |
|---------|-------|------|--------------|------|
| MySQL | Database | Service | `softcraftdave` | scarlet |
| MongoDB | Database | Service | `softcraftjerry` | scarlet |
| PostgreSQL | Database | Service | `softcraftmark` | cass |
| Redis | Database | Service | `softcraftron` | gru |
| SQL Server | Database | Service | `softcraftjorge` | scarlet |
| Prometheus | Prometheus | Service | `softcraftbelle` | cass |
| Grafana | Prometheus | Service | `softcraftbob` | gru |
| Loki | Prometheus | Service | `softcraftmel` | gru |
| cAdvisor | Prometheus | Service | `softcraftchow` | Global |
| AgentGateway | AgentGateway | Service | `softcraftgenia` | scarlet |
| Pi-hole | Pi-hole | Container | `softcraftjim` | N/A |

---

## Files Created/Modified

### Created:
- `database/outputs.tf` ✅
- `database/modules/mysql/outputs.tf` ✅
- `database/modules/mongodb/outputs.tf` ✅
- `database/modules/postgresql/outputs.tf` ✅
- `database/modules/redis/outputs.tf` ✅
- `database/modules/sqlserver/outputs.tf` ✅
- `prometheus/outputs.tf` ✅
- `prometheus/modules/prometheus/outputs.tf` ✅ (Enhanced)
- `prometheus/modules/grafana/outputs.tf` ✅
- `prometheus/modules/loki/outputs.tf` ✅ (Enhanced)
- `prometheus/modules/cadvisor/outputs.tf` ✅
- `agentgateway/outputs.tf` ✅
- `pi-hole/outputs.tf` ✅

### Modified:
- `prometheus/modules/prometheus/outputs.tf` (added service_id and service_replica_id)
- `prometheus/modules/loki/outputs.tf` (added service_id and service_replica_id)

---

## Next Steps

1. **Run `terraform plan`** to preview changes:
   ```bash
   cd database && terraform plan
   cd ../prometheus && terraform plan
   cd ../agentgateway && terraform plan
   cd ../pi-hole && terraform plan
   ```

2. **Run `terraform apply`** to create/update resources and populate outputs:
   ```bash
   cd database && terraform apply
   cd ../prometheus && terraform apply
   cd ../agentgateway && terraform apply
   cd ../pi-hole && terraform apply
   ```

3. **View outputs** to see all container and service IDs:
   ```bash
   cd database && terraform output
   # View all service IDs, names, and volume names
   ```

4. **Use outputs for automation**:
   ```bash
   SERVICE_ID=$(terraform output -raw mysql_service_id)
   docker service inspect $SERVICE_ID
   ```
