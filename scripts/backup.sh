#!/bin/bash
set -euo pipefail

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR=/tmp/db-backups/${TIMESTAMP}
BUCKET="${S3_BACKUP_BUCKET:-your-backup-bucket}"

log() { echo "[backup ${TIMESTAMP}] $*"; }

mkdir -p "${BACKUP_DIR}"

# ── PostgreSQL ────────────────────────────────────────────────────────
log "Dumping PostgreSQL..."
docker exec postgres pg_dump \
  -U "${POSTGRES_USER:-appuser}" \
  -d "${POSTGRES_DB:-appdb}" \
  --format=custom | gzip > "${BACKUP_DIR}/postgres_${TIMESTAMP}.dump.gz"

# ── Neo4j ─────────────────────────────────────────────────────────────
log "Dumping Neo4j..."
docker exec neo4j neo4j-admin database dump \
  --database=neo4j --to-path=/tmp/
docker cp neo4j:/tmp/neo4j.dump "${BACKUP_DIR}/neo4j_${TIMESTAMP}.dump"
gzip "${BACKUP_DIR}/neo4j_${TIMESTAMP}.dump"

# ── Upload to S3 ──────────────────────────────────────────────────────
# No AWS keys needed — Instance Profile provides credentials automatically
log "Uploading to S3..."
aws s3 cp "${BACKUP_DIR}/" \
  "s3://${BUCKET}/backups/${TIMESTAMP}/" --recursive

rm -rf "${BACKUP_DIR}"
log "Done."
