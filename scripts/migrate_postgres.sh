#!/bin/bash
set -euo pipefail

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DUMP_FILE="postgres_migration_${TIMESTAMP}.dump"

log()  { echo "[migrate-postgres] $*"; }
fail() { echo "[migrate-postgres] ERROR: $*" >&2; exit 1; }

[[ -z "${RDS_HOST:-}" ]] && fail "RDS_HOST is not set"

log "Dumping from RDS: ${RDS_HOST}"
pg_dump -h "${RDS_HOST}" -p "${RDS_PORT:-5432}" \
  -U "${RDS_USER:-postgres}" -d "${RDS_DB:-yourdb}" \
  --format=custom --no-owner --no-acl -f "${DUMP_FILE}"

log "Copying dump into container..."
docker cp "${DUMP_FILE}" postgres:/tmp/${DUMP_FILE}

log "Dropping and recreating target database..."
docker exec postgres psql -U "${POSTGRES_USER:-appuser}" -d postgres -c \
  "DROP DATABASE IF EXISTS ${POSTGRES_DB:-appdb};"
docker exec postgres psql -U "${POSTGRES_USER:-appuser}" -d postgres -c \
  "CREATE DATABASE ${POSTGRES_DB:-appdb} OWNER ${POSTGRES_USER:-appuser};"

log "Restoring..."
docker exec postgres pg_restore \
  -U "${POSTGRES_USER:-appuser}" -d "${POSTGRES_DB:-appdb}" \
  --no-owner --no-acl "/tmp/${DUMP_FILE}"

log "Validating row counts..."
docker exec postgres psql -U "${POSTGRES_USER:-appuser}" -d "${POSTGRES_DB:-appdb}" \
  -c "SELECT tablename, n_live_tup FROM pg_stat_user_tables ORDER BY n_live_tup DESC LIMIT 10;"

docker exec postgres rm -f "/tmp/${DUMP_FILE}"
rm -f "${DUMP_FILE}"
log "Migration complete."
