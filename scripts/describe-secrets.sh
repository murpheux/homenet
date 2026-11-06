#!/usr/bin/env bash
# Describes secret env vars (length, stray whitespace, hash-like) without printing them.
# Run via a stack's `make check-secrets` so op run resolves its 1Password references.
set -euo pipefail

[[ $# -gt 0 ]] || { echo "usage: $0 <ENV_VAR> [...]" >&2; exit 2; }

seen=""
for var in "$@"; do
  val=${!var:-}
  if [[ -z $val ]]; then
    echo "${var}: NOT SET"
    continue
  fi
  trimmed=${val//[[:space:]]/}
  ws=no
  [[ $trimmed == "$val" ]] || ws=YES
  hash=no
  # shellcheck disable=SC2016  # literal '$' prefixes of Pi-hole/bcrypt hashes
  [[ $val == '$BALLOON'* || $val == '$2'[aby]'$'* ]] && hash=YES
  fp=$(printf '%s' "$val" | shasum -a 256 | cut -c1-8)
  dup=""
  prev=$(printf '%s' "$seen" | awk -v fp="$fp" '$1 == fp {print $2; exit}')
  [[ -n $prev ]] && dup=" (same value as ${prev})"
  seen+="${fp} ${var}"$'\n'
  echo "${var}: length=${#val} whitespace=${ws} looks_like_hash=${hash}${dup}"
done
