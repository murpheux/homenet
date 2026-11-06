#!/usr/bin/env bash
# Waits for a Swarm service to answer HTTP with one of the accepted status codes. Prints
# the task state while waiting; on timeout prints the task errors and recent logs.
# Usage: bash scripts/wait-for-service.sh <service> <url> [timeout_s] [codes_regex]
# Env:   CTX (docker context, default murpheux-scarlet)
set -euo pipefail

[[ $# -ge 2 ]] || { echo "usage: $0 <service> <url> [timeout_s] [codes_regex]" >&2; exit 2; }
svc=$1
url=$2
timeout=${3:-900}
codes=${4:-'^(200|401)$'}
ctx=${CTX:-murpheux-scarlet}

start=$(date +%s)
while :; do
  code=$(curl -s -o /dev/null -m 5 -w '%{http_code}' "$url" || true)
  if [[ $code =~ $codes ]]; then
    echo "${svc} is up (HTTP ${code} from ${url})"
    exit 0
  fi

  elapsed=$(($(date +%s) - start))
  if ((elapsed >= timeout)); then
    echo "${svc} not answering at ${url} after ${timeout}s. Diagnostics:" >&2
    echo "--- tasks ---" >&2
    docker --context="$ctx" service ps "$svc" --no-trunc --format '{{.Node}}  {{.CurrentState}}  {{.Error}}' 2>&1 | head -6 >&2 || true
    echo "--- last 40 log lines ---" >&2
    docker --context="$ctx" service logs --tail 40 "$svc" 2>&1 | tail -40 >&2 || true
    exit 1
  fi

  state=$(docker --context="$ctx" service ps "$svc" --format '{{.Node}} {{.CurrentState}}' 2>/dev/null | head -1 || true)
  printf '%5ss  %-45s HTTP %s\n' "$elapsed" "${state:-no task yet}" "${code:-000}"
  sleep 10
done
