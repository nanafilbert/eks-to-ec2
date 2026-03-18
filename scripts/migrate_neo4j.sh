#!/bin/bash
set -euo pipefail

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DUMP_FILE="neo4j_migration_${TIMESTAMP}.dump"

log()  { echo "[migrate-neo4j] $*"; }
fail() { echo "[migrate-neo4j] ERROR: $*" >&2; exit 1; }

[[ -z "${NEO4J_POD:-}"      ]] && fail "NEO4J_POD is not set"
[[ -z "${NEO4J_PASSWORD:-}" ]] && fail "NEO4J_PASSWORD is not set"

log "Dumping from EKS pod: ${NEO4J_POD}"
kubectl exec -n "${NEO4J_NAMESPACE:-default}" "${NEO4J_POD}" -- \
  neo4j-admin database dump --database=neo4j --to-path=/tmp/
kubectl cp "${NEO4J_NAMESPACE:-default}/${NEO4J_POD}:/tmp/neo4j.dump" "./${DUMP_FILE}"

log "Copying into Docker container..."
docker cp "./${DUMP_FILE}" neo4j:/tmp/${DUMP_FILE}

log "Stopping Neo4j for restore..."
docker stop neo4j
docker run --rm --volumes-from neo4j neo4j:5-community \
  neo4j-admin database load --database=neo4j \
  --from-path=/tmp --overwrite-destination=true

log "Starting Neo4j..."
docker start neo4j
sleep 20

log "Validating..."
docker exec neo4j cypher-shell -u neo4j -p "${NEO4J_PASSWORD}" \
  'MATCH (n) RETURN count(n) AS nodes;'

rm -f "./${DUMP_FILE}"
log "Migration complete."
