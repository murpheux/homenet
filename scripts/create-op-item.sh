#!/usr/bin/env bash
# Creates a 1Password item whose fields are random 32-character alphanumeric secrets.
# Values are generated locally and passed to `op item create` only through stdin (a JSON
# item template), never argv or a temp file, and are never printed. Refuses to overwrite
# an existing item. Usage: bash scripts/create-op-item.sh <vault> <title> <field> [field...]
set -euo pipefail

[[ $# -ge 3 ]] || { echo "usage: $0 <vault> <title> <field> [field...]" >&2; exit 2; }
vault=$1
title=$2
shift 2

for bin in op jq openssl; do
  command -v "$bin" >/dev/null || { echo "needs ${bin}" >&2; exit 1; }
done

if op item get "$title" --vault "$vault" --format json >/dev/null 2>&1; then
  echo "item '${title}' already exists in vault '${vault}'; not overwriting" >&2
  exit 1
fi

gen() {
  local v=""
  while [[ ${#v} -lt 32 ]]; do
    v+=$(openssl rand -base64 48 | tr -dc 'A-Za-z0-9')
  done
  printf '%s' "${v:0:32}"
}

pairs=""
for field in "$@"; do
  [[ $field =~ ^[a-z0-9][a-z0-9-]*$ ]] || { echo "invalid field name: ${field}" >&2; exit 1; }
  pairs+="${field}"$'\t'"$(gen)"$'\n'
done

printf '%s' "$pairs" | jq -Rn --arg title "$title" '
  [inputs | split("\t") | {name: .[0], value: .[1]}] as $kv
  | {
      title: $title,
      category: "SECURE_NOTE",
      fields: [ $kv[] | {id: .name, label: .name, type: "CONCEALED", value: .value} ]
    }' | op item create --vault "$vault" - >/dev/null
unset pairs

echo "created '${title}' in vault '${vault}' with fields: $*"
