#!/usr/bin/env bash
# Creates (or resets the password of) the PostgreSQL role Tomcat logs in as.
# The password comes from TF_VAR_app_db_password (op run) and reaches psql only on stdin.
# Usage: bash scripts/create-db-role.sh [role] [docker-context]
set -euo pipefail

role=${1:-tomcat_user}
ctx=${2:-murpheux-cass}
pw=${TF_VAR_app_db_password:?run through: op run --env-file=op.env -- $0}

[[ $role =~ ^[a-z_][a-z0-9_]*$ ]] || { echo "invalid role name: ${role}" >&2; exit 1; }
# make create-secret generates letters and digits only, so single-quoting is safe.
[[ $pw =~ ^[A-Za-z0-9]+$ ]] || { echo "password must be letters and digits only for this script" >&2; exit 1; }

cid=$(docker --context="$ctx" ps -qf name=softcraftmark | head -1)
[[ -n $cid ]] || { echo "no running softcraftmark (PostgreSQL) container on context ${ctx}" >&2; exit 1; }

printf "DO \$\$ BEGIN
  IF EXISTS (SELECT FROM pg_roles WHERE rolname = '%s') THEN
    ALTER ROLE %s WITH LOGIN PASSWORD '%s';
  ELSE
    CREATE ROLE %s LOGIN PASSWORD '%s';
  END IF;
END \$\$;
GRANT CONNECT ON DATABASE appdb TO %s;
" "$role" "$role" "$pw" "$role" "$pw" "$role" |
  docker --context="$ctx" exec -i "$cid" sh -c 'psql -v ON_ERROR_STOP=1 -q -U "$POSTGRES_USER" -d appdb'
unset pw

echo "role ${role} ready on appdb"
