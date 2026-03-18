#!/bin/bash
# Pull and redeploy updated app images with zero downtime
# Usage: ./scripts/deploy.sh [version]
set -euo pipefail

VERSION="${1:-latest}"
COMPOSE_FILE="/opt/eks-to-ec2/server-a/docker-compose.yml"

log() { echo "[deploy $(date +%H:%M:%S)] $*"; }

log "Deploying version: ${VERSION}"

# Pull new images
log "Pulling images..."
VERSION=${VERSION} docker compose -f "${COMPOSE_FILE}" pull backend celery

# Restart app containers only — databases stay running
log "Restarting backend and celery..."
VERSION=${VERSION} docker compose -f "${COMPOSE_FILE}" \
  up -d --no-deps backend celery

# Run migrations
log "Running migrations..."
docker compose -f "${COMPOSE_FILE}" \
  exec backend python manage.py migrate --noinput

# Reload Nginx
log "Reloading Nginx..."
docker compose -f "${COMPOSE_FILE}" exec nginx nginx -s reload

log "Deploy complete."
