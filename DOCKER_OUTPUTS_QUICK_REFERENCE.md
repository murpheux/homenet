# Docker Outputs Quick Reference

## Command Cheatsheet

```bash
# View all outputs for a stack
terraform -chdir=database output
terraform -chdir=prometheus output
terraform -chdir=agentgateway output
terraform -chdir=pi-hole output

# View specific output value
terraform -chdir=database output mysql_service_id
terraform -chdir=database output mysql_service_name

# Get raw string value (no JSON formatting)
terraform -chdir=database output -raw mysql_service_name

# Get JSON output (for scripting)
terraform -chdir=database output -json

# Get map output (for configs)
terraform -chdir=agentgateway output -json agentgateway_config_ids
```

---

## Docker Service IDs

### Database Services

```bash
# MySQL
$ terraform -chdir=database output mysql_service_id
abc123def456...  # Swarm service ID

$ terraform -chdir=database output mysql_service_name
softcraftdave

# Inspect with Docker
$ docker service inspect softcraftdave
$ docker service ps softcraftdave  # View running tasks

# MongoDB
$ terraform -chdir=database output mongodb_service_name
softcraftjerry

# PostgreSQL
$ terraform -chdir=database output postgresql_service_name
softcraftmark

# Redis
$ terraform -chdir=database output redis_service_name
softcraftron

# SQL Server
$ terraform -chdir=database output sqlserver_service_name
softcraftjorge
```

### Prometheus/Monitoring Services

```bash
# Prometheus
$ terraform -chdir=prometheus output prometheus_service_name
softcraftbelle
$ docker service ps softcraftbelle

# Grafana
$ terraform -chdir=prometheus output grafana_service_name
softcraftbob
$ docker service ps softcraftbob

# Loki
$ terraform -chdir=prometheus output loki_service_name
softcraftmel
$ docker service ps softcraftmel

# cAdvisor (Global - one per node)
$ terraform -chdir=prometheus output cadvisor_service_name
softcraftchow
$ docker service ps softcraftchow
```

### AgentGateway Service

```bash
# AgentGateway
$ terraform -chdir=agentgateway output agentgateway_service_name
softcraftgenia
$ docker service ps softcraftgenia

# Web UI
$ terraform -chdir=agentgateway output agentgateway_service_id
# Then: https://<node-ip>:9443/ui
```

---

## Docker Container IDs

### Pi-hole Container

```bash
# Pi-hole (NOT a Swarm service - standalone container)
$ terraform -chdir=pi-hole output pihole_container_id
abc123def456...  # Full container ID

$ terraform -chdir=pi-hole output pihole_container_name
softcraftjim

# View with Docker
$ docker container inspect softcraftjim
$ docker container logs softcraftjim

# Check IP
$ terraform -chdir=pi-hole output pihole_ipv4_address
10.10.2.7
```

---

## Network & Volume IDs

### Database Stack

```bash
# Network
$ terraform -chdir=database output db_network_name
db_net

$ terraform -chdir=database output db_network_id
abc123def456...

# Volumes
$ terraform -chdir=database output mysql_data_volume
mysql_data_local

$ docker volume ls | grep mysql_data_local
```

### Prometheus Stack

```bash
# Network
$ terraform -chdir=prometheus output monitoring_network_name
monitoring_network

# Volumes
$ terraform -chdir=prometheus output prometheus_data_volume
prometheus_data_local

$ terraform -chdir=prometheus output grafana_data_volume
grafana_data_local

$ terraform -chdir=prometheus output loki_data_volume
loki_data_local
```

### AgentGateway Stack

```bash
# State Volume (SQLite database)
$ terraform -chdir=agentgateway output agentgateway_state_volume
agentgateway_state

$ docker volume ls | grep agentgateway_state

# Config and Secret IDs (for debugging)
$ terraform -chdir=agentgateway output -json agentgateway_config_ids
{
  "agentgateway_yaml": "id123...",
  "base_costs_json": "id456..."
}

$ terraform -chdir=agentgateway output -json agentgateway_secret_ids
{
  "tls_cert": "id789...",
  "tls_key": "id012...",
  "ui_htpasswd": "id345..."
}
```

---

## Common Operations

### Restart a Service

```bash
# Get service name from outputs
SERVICE_NAME=$(terraform -chdir=database output -raw mysql_service_name)

# Force restart (rolling update)
docker service update --force $SERVICE_NAME

# Or use the name directly
docker service update --force softcraftdave
```

### View Service Logs

```bash
# Get service name
SERVICE_NAME=$(terraform -chdir=prometheus output -raw prometheus_service_name)

# View logs
docker service logs -f $SERVICE_NAME

# View only last 50 lines
docker service logs --tail 50 $SERVICE_NAME
```

### Scale a Service

```bash
# Scale PostgreSQL to 3 replicas
docker service scale softcraftmark=3

# View current replicas
docker service ps softcraftmark
```

### Inspect Service Details

```bash
# Full JSON inspection
docker service inspect softcraftdave

# Just endpoint VIP
docker service inspect softcraftdave --format='{{json .Endpoint.VirtualIPs}}'

# Task status
docker service ps --no-trunc softcraftdave
```

### Check Volume Data

```bash
# List all volumes
docker volume ls | grep data_local

# Inspect a volume
docker volume inspect mysql_data_local

# View volume mount point
docker volume inspect mysql_data_local --format='{{.Mountpoint}}'

# Check volume size
docker volume inspect mysql_data_local | jq '.Labels'
```

---

## Output Values Summary

| Stack | Service | Service Name | Type | Container Type |
|-------|---------|--------------|------|---|
| Database | MySQL | `softcraftdave` | Service | Swarm |
| Database | MongoDB | `softcraftjerry` | Service | Swarm |
| Database | PostgreSQL | `softcraftmark` | Service | Swarm |
| Database | Redis | `softcraftron` | Service | Swarm |
| Database | SQL Server | `softcraftjorge` | Service | Swarm |
| Prometheus | Prometheus | `softcraftbelle` | Service | Swarm |
| Prometheus | Grafana | `softcraftbob` | Service | Swarm |
| Prometheus | Loki | `softcraftmel` | Service | Swarm |
| Prometheus | cAdvisor | `softcraftchow` | Service | Swarm (Global) |
| AgentGateway | AgentGateway | `softcraftgenia` | Service | Swarm |
| Pi-hole | Pi-hole | `softcraftjim` | Container | Standalone |

---

## Accessing Services

### From Local Host (medusa)

```bash
# Database services (via Swarm ingress)
mysql -h localhost -u root -p <password> appdb
psql -h localhost -U postgres appdb
redis-cli -h localhost

# Monitoring services
# Prometheus: http://localhost:9090
# Grafana: http://localhost:3000
# Loki: http://localhost:3100

# AgentGateway
# HTTPS: https://localhost:9443/ui
# API: https://localhost:9443/v1
```

### From Swarm Network (via DNS names)

```bash
# Service names resolve on their networks
# From inside the swarm or containers on the network:

# Database network (db_net)
mysql -h softcraftdave -u root -p appdb
psql -h softcraftmark -U postgres appdb
redis-cli -h softcraftron

# Monitoring network (monitoring_network)
# Prometheus: http://softcraftbelle:9090
# Grafana: http://softcraftbob:3000
# Loki: http://softcraftmel:3100
```

---

## Troubleshooting

### Service won't start

```bash
# Check service status
docker service ps --no-trunc softcraftdave

# View service logs
docker service logs softcraftdave

# Inspect detailed error
docker service ps softcraftdave --format='{{.Status}} - {{.StatusAt}}'
```

### Volume permission issues

```bash
# Check volume owner
docker run --rm -v mysql_data_local:/data alpine ls -la /data/

# For agentgateway_state volume specifically
docker volume inspect agentgateway_state | jq '.Labels'
```

### Network connectivity

```bash
# Verify network exists
docker network ls | grep -E "db_net|monitoring_network|pihole"

# Inspect network
docker network inspect db_net

# Check service IP
docker service inspect softcraftdave --format='{{range .Endpoint.VirtualIPs}}{{.Addr}}{{end}}'
```

---

## Export Outputs to Env File

```bash
# Create .env file with all outputs
cat > docker_outputs.env << 'EOF'
# Database
export MYSQL_SERVICE_ID=$(terraform -chdir=database output -raw mysql_service_id)
export MYSQL_SERVICE_NAME=$(terraform -chdir=database output -raw mysql_service_name)
export POSTGRESQL_SERVICE_ID=$(terraform -chdir=database output -raw postgresql_service_id)

# Prometheus
export PROMETHEUS_SERVICE_ID=$(terraform -chdir=prometheus output -raw prometheus_service_id)
export GRAFANA_SERVICE_ID=$(terraform -chdir=prometheus output -raw grafana_service_id)

# AgentGateway
export AGENTGATEWAY_SERVICE_ID=$(terraform -chdir=agentgateway output -raw agentgateway_service_id)

# Pi-hole
export PIHOLE_CONTAINER_ID=$(terraform -chdir=pi-hole output -raw pihole_container_id)
export PIHOLE_IP=$(terraform -chdir=pi-hole output -raw pihole_ipv4_address)
EOF

# Source the file
source docker_outputs.env

# Use in commands
docker service ps $MYSQL_SERVICE_NAME
docker service logs -f $PROMETHEUS_SERVICE_NAME
```

---

## See Also

- `TERRAFORM_OUTPUTS_SUMMARY.md` - Detailed documentation of all outputs
- `README.md` - Main project README
- Terraform state files (stored in Terraform Cloud)
