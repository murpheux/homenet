#!/usr/bin/env bash
# Re-initialises every Terraform stack so its .terraform.lock.hcl and cached providers
# match the provider constraints (kreuzwerker/docker >= 4.6.0). Fixes "the cached package ...
# does not match any of the checksums recorded in the dependency lock file".
# Usage (from the repo root): bash scripts/upgrade-provider-locks.sh [stack...]
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
stacks=("$@")
[[ ${#stacks[@]} -gt 0 ]] || stacks=(agentgateway database elk openclaw pi-hole prometheus tomcat)

# Hashes for both platforms in use: medusa (darwin_arm64) and the Linux Swarm nodes.
platforms=(-platform=darwin_arm64 -platform=linux_amd64)

failed=()
for stack in "${stacks[@]}"; do
  dir="${root}/${stack}"
  echo "=== ${stack} ==="
  [[ -d $dir ]] || { echo "  no such directory"; failed+=("$stack"); continue; }

  init_args=(init -upgrade -input=false)
  # MinIO-backed stacks need their backend credentials file.
  if [[ -f "${dir}/backend.tfvars" ]]; then
    init_args+=(-backend-config=backend.tfvars)
  fi

  if (cd "$dir" && terraform "${init_args[@]}" >/dev/null && terraform providers lock "${platforms[@]}" >/dev/null); then
    v=$(awk '/kreuzwerker\/docker"/{f=1} f&&/version/{gsub(/"/,"",$3); print $3; exit}' "${dir}/.terraform.lock.hcl")
    echo "  ok: kreuzwerker/docker locked at ${v}"
  else
    echo "  FAILED: run 'cd ${stack} && terraform init -upgrade' to see the error"
    failed+=("$stack")
  fi
done

if [[ ${#failed[@]} -gt 0 ]]; then
  echo "failed: ${failed[*]}"
  exit 1
fi
echo "all stacks locked; run 'make plan' (or terraform plan) in each before applying"
