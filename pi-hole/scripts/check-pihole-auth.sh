#!/usr/bin/env bash
# Checks that each Pi-hole accepts its password, without printing it.
# Args are host=ENV_VAR pairs naming the env var that holds that host's password.
# Run via `make check-auth` (op run injects the TF_VAR_* values from op.env).
# -k: the Pi-holes serve self-signed certs; this check only reads the auth result.
set -euo pipefail

[[ $# -gt 0 ]] || { echo "usage: $0 <host>=<ENV_VAR> [...]" >&2; exit 2; }

rc=0
for arg in "$@"; do
  host=${arg%%=*}
  var=${arg#*=}
  if [[ $host == "$arg" || -z ${!var:-} ]]; then
    echo "${host}: ${var} is not set (expected host=ENV_VAR, run through op run)"
    rc=1
    continue
  fi

  if ! out=$(jq -n --arg pw "${!var}" '{password: $pw}' |
    curl -sk -m 5 -w '\n%{http_code}' -H 'Content-Type: application/json' -d @- "https://${host}/api/auth"); then
    echo "${host}: no response (connection failed)"
    rc=1
    continue
  fi
  http_code=${out##*$'\n'}
  resp=${out%$'\n'*}

  # Pi-hole v6 replies with .session on success and .error (key/message/hint) on rejection.
  if ! summary=$(jq -c --arg http_code "$http_code" --arg var "$var" \
    '{var: $var, http: $http_code, valid: .session.valid, totp: .session.totp, message: .session.message, error: .error}' \
    <<<"$resp" 2>/dev/null); then
    echo "${host}: http ${http_code}, non-JSON reply: ${resp:0:200}"
    rc=1
    continue
  fi
  echo "${host}: ${summary}"
  [[ $(jq -r '.session.valid' <<<"$resp") == "true" ]] || rc=1

  # Log out so the check doesn't consume one of Pi-hole's limited API sessions.
  sid=$(jq -r '.session.sid // empty' <<<"$resp")
  if [[ -n $sid ]]; then
    curl -sk -m 5 -X DELETE -H "sid: ${sid}" "https://${host}/api/auth" >/dev/null || true
  fi
done
exit "$rc"
