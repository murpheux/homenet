#!/usr/bin/env bash
# One-time migration: creates the 1Password item referenced by op.env from secrets.tfvars.
# Values travel only through stdin (a JSON item template), never argv or a temp file, and
# are never printed. Usage: bash scripts/import-tfvars-to-op.sh [tfvars] [vault] [title]
set -euo pipefail

tfvars=${1:-secrets.tfvars}
vault=${2:-private}
title=${3:-database}

[[ -r $tfvars ]] || { echo "cannot read ${tfvars}" >&2; exit 1; }
for bin in op jq; do
  command -v "$bin" >/dev/null || { echo "needs ${bin}" >&2; exit 1; }
done

if op item get "$title" --vault "$vault" --format json >/dev/null 2>&1; then
  echo "item '${title}' already exists in vault '${vault}'; not overwriting" >&2
  exit 1
fi

# tfvars name -> 1Password field label (op.env references these labels).
names=(mysql_root_password mongo_user mongo_password postgres_user postgres_password sqlserver_sa_password redis_password)

pairs=""
for name in "${names[@]}"; do
  line=$(grep -E "^[[:space:]]*${name}[[:space:]]*=" "$tfvars" || true)
  [[ -n $line ]] || { echo "${name}: missing from ${tfvars}" >&2; exit 1; }
  re='^[[:space:]]*[a-z_]+[[:space:]]*=[[:space:]]*"([^"\\]*)"[[:space:]]*$'
  [[ $line =~ $re ]] || { echo "${name}: not a plain \"value\" string; add it to 1Password by hand" >&2; exit 1; }
  pairs+="${name}"$'\t'"${BASH_REMATCH[1]}"$'\n'
done

# Tab-separated name/value lines on stdin -> SECURE_NOTE template -> op item create (stdin).
printf '%s' "$pairs" | jq -Rn --arg title "$title" '
  [inputs | split("\t") | {name: .[0], value: (.[1:] | join("\t"))}] as $kv
  | {
      title: $title,
      category: "SECURE_NOTE",
      fields: [ $kv[] | {
        id: (.name | gsub("_"; "-")),
        label: (.name | gsub("_"; "-")),
        type: (if (.name | test("_user$")) then "STRING" else "CONCEALED" end),
        value: .value
      } ]
    }' | op item create --vault "$vault" - >/dev/null
unset pairs

echo "created '${title}' in vault '${vault}' with ${#names[@]} fields; verify with: make check-secrets"
