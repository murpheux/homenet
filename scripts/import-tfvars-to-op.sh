#!/usr/bin/env bash
# Creates a 1Password item from every `name = "value"` line in one or more .tfvars files.
# Field labels are the names in kebab-case (grafana_admin_password -> grafana-admin-password).
# Values travel only through stdin (a JSON item template), never argv or a temp file, and
# are never printed. Refuses to overwrite an existing item.
# Usage: bash scripts/import-tfvars-to-op.sh <vault> <title> <file.tfvars> [more.tfvars...]
set -euo pipefail

[[ $# -ge 3 ]] || { echo "usage: $0 <vault> <title> <file.tfvars> [more.tfvars...]" >&2; exit 2; }
vault=$1
title=$2
shift 2

for bin in op jq; do
  command -v "$bin" >/dev/null || { echo "needs ${bin}" >&2; exit 1; }
done

if op item get "$title" --vault "$vault" --format json >/dev/null 2>&1; then
  echo "item '${title}' already exists in vault '${vault}'; not overwriting" >&2
  exit 1
fi

assign='^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*='
plain='^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=[[:space:]]*"([^"\\]*)"[[:space:]]*$'

pairs=""
count=0
for file in "$@"; do
  [[ -r $file ]] || { echo "cannot read ${file}" >&2; exit 1; }
  while IFS= read -r line || [[ -n $line ]]; do
    [[ $line =~ $assign ]] || continue
    name=${BASH_REMATCH[1]}
    [[ $line =~ $plain ]] || { echo "${file}: ${name} is not a plain \"value\" string; add it by hand" >&2; exit 1; }
    pairs+="${name}"$'\t'"${BASH_REMATCH[1]}"$'\n'
    count=$((count + 1))
  done < "$file"
done
[[ $count -gt 0 ]] || { echo "no assignments found" >&2; exit 1; }

# Fields whose name ends in _user/_email/_url are plain text; everything else is concealed.
printf '%s' "$pairs" | jq -Rn --arg title "$title" '
  [inputs | split("\t") | {name: .[0], value: (.[1:] | join("\t"))}] as $kv
  | {
      title: $title,
      category: "SECURE_NOTE",
      fields: [ $kv[] | {
        id: (.name | gsub("_"; "-")),
        label: (.name | gsub("_"; "-")),
        type: (if (.name | test("_(user|email|url)$")) then "STRING" else "CONCEALED" end),
        value: .value
      } ]
    }' | op item create --vault "$vault" - >/dev/null
unset pairs

echo "created '${title}' in vault '${vault}' with ${count} fields"
