# Copilot Instructions for HomeNet

This repository is a **home network infrastructure project** using Infrastructure as Code (IaC) to manage DNS (Pi-hole), monitoring (Prometheus, ELK), and services through Docker Compose and Ansible.

## Architecture Overview

**Components:**
- **Pi-hole**: DNS/ad-blocking service deployed via Terraform with multiple variants (bare-metal build, Docker Swarm, ARM)
- **Docker Swarm**: Orchestration layer for containerized services
- **Monitoring**: Prometheus and ELK stack for metrics and logging
- **Configuration Management**: Ansible playbooks for system configuration
- **Infrastructure as Code**: Terraform manages Docker providers and remote provisioning

**Directory Structure:**
- `/pi-hole/`, `/pi-hole-build/`, `/pi-hole-swarm/`, `/pi-hole-xarm/`: Different Pi-hole deployment strategies
- `/swarm/`: Docker Swarm orchestration configs
- `/prometheus/`, `/elk-b/`, `/elkb-zzzz/`: Monitoring stack deployments
- `/ansible/`: Configuration management playbooks
- `/bash/`: Utility scripts
- Root-level `.tf` files: Update automation and standalone provisioning

## Build and Deploy Commands

### Terraform
Each subdirectory with Terraform configs (`/pi-hole`, `/swarm`, `/prometheus`, etc.) follows the same workflow:
```bash
cd <component-directory>
terraform init
terraform plan -var-file=terraform.tfvars -out=plan.tfplan  # Review changes
terraform apply plan.tfplan
```

For components with secrets:
```bash
terraform apply -var-file=secrets.tfvars  # Variables from secrets.tfvars
```

### Docker Compose
```bash
cd swarm/
docker compose up -d          # Start services in background
docker compose logs -f        # Follow logs
docker compose down           # Stop and remove containers
```

### Ansible
```bash
ansible-playbook ansible/<playbook-name>.yaml        # Run playbook
ansible-playbook ansible/<playbook-name>.yaml --check # Dry-run
```

### Bash Utilities
```bash
bash/cleanup.sh  # System cleanup for macOS (removes caches, logs, preferences)
```

## Key Conventions

### Terraform
- **Variable files**: 
  - `terraform.tfvars` for non-sensitive configuration
  - `secrets.tfvars` for sensitive data (never commit to git)
- **Provider context**: Docker configurations specify a context (e.g., `"murpheux-scarlet"`) to target specific Docker hosts
- **IPVLAN networks**: Pi-hole uses IPVLAN driver for network isolation with custom IPv4 and IPv6 subnets
- **One component per directory**: Each deployment variant (pi-hole-swarm, pi-hole-xarm, pi-hole-build) has its own Terraform state

### Docker Compose
- Services deployed in Docker Swarm mode (`deploy.mode: replicated`)
- Persistent volumes for configuration (`pihole_etc`, `dnsmasq`)
- Network constraints using Swarm placement (e.g., `constraints: node.role == worker`)
- Environment variables for service configuration (passwords, timezones, IP addresses)

### Ansible
- Uses **roles** for modularization (e.g., `HomeSecExplorer.pihole`)
- Playbooks target host groups defined in inventory (e.g., `pihole_hosts`)
- Configuration variables in `vars` section mirror the role's expected structure

### Naming
- Deployment variants use clear suffixes: `-build` (build Pi-hole from source), `-swarm` (Docker Swarm), `-xarm` (ARM architecture), `-update` (update automation)
- Terraform state files: `.tfstate` and `.tfstate.backup` (tracked in git for reference, not secrets)

## Working with State and Secrets

⚠️ **Important**: Never commit sensitive data:
- `secrets.tfvars` files contain passwords and API keys
- Ensure `.gitignore` excludes sensitive files before adding new configs
- Use environment variables for sensitive values if possible

To preview changes before applying:
```bash
cd <component-dir>
terraform plan -var-file=secrets.tfvars
```

## Testing Configuration Changes

- Use `--check` flag with Ansible for dry-runs:
  ```bash
  ansible-playbook ansible/pihole.yaml --check
  ```
- Use `terraform plan` to preview infrastructure changes before applying
- For Docker Compose, test locally with `docker compose up` before deploying to production

## Updating Components

- **Pi-hole updates**: `pihole-update.tf` automates updates via SSH remote-exec on bare-metal hosts
- **System updates**: `ansible/update_upgrade_linux.yaml` handles OS-level package updates
- Pi-hole-swarm Docker images default to `:latest` tag; pin versions in production
