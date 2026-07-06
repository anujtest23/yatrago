#!/usr/bin/env bash
#
# Encrypted PostgreSQL backup for YatraGo.
#
# Produces a gzip-compressed, GPG-symmetrically-encrypted dump and (optionally)
# ships it to a Cloudflare R2 / S3 bucket. Designed to run from cron:
#
#   0 2 * * *  /path/to/backup-db.sh >> /var/log/yatrago-backup.log 2>&1
#
# Required env:
#   DATABASE_URL         postgres connection string
#   BACKUP_PASSPHRASE     symmetric encryption passphrase (store in a secret mgr)
# Optional env:
#   BACKUP_DIR            local output dir (default: ./backups)
#   BACKUP_S3_BUCKET      s3://bucket/prefix to upload to (uses awscli if set)
#   BACKUP_RETENTION_DAYS local retention (default: 14)
#
# Restore:
#   gpg -d backup-YYYYmmdd-HHMMSS.sql.gz.gpg | gunzip | psql "$DATABASE_URL"

set -euo pipefail

: "${DATABASE_URL:?DATABASE_URL is required}"
: "${BACKUP_PASSPHRASE:?BACKUP_PASSPHRASE is required}"

BACKUP_DIR="${BACKUP_DIR:-./backups}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-14}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${BACKUP_DIR}/backup-${STAMP}.sql.gz.gpg"

mkdir -p "$BACKUP_DIR"

echo "[$(date -Is)] Starting backup -> ${OUT}"

# Dump -> compress -> encrypt in a single stream (plaintext never hits disk).
pg_dump --no-owner --no-privileges "$DATABASE_URL" \
  | gzip -9 \
  | gpg --batch --yes --symmetric --cipher-algo AES256 \
        --passphrase "$BACKUP_PASSPHRASE" \
        -o "$OUT"

echo "[$(date -Is)] Wrote $(du -h "$OUT" | cut -f1)"

# Integrity manifest: verify-backup.sh checks this before any restore, and
# it detects silent corruption in transit/storage.
sha256sum "$OUT" > "${OUT}.sha256"
echo "[$(date -Is)] Checksum written to ${OUT}.sha256"

if [[ -n "${BACKUP_S3_BUCKET:-}" ]]; then
  echo "[$(date -Is)] Uploading to ${BACKUP_S3_BUCKET}"
  aws s3 cp "$OUT" "${BACKUP_S3_BUCKET}/"
  aws s3 cp "${OUT}.sha256" "${BACKUP_S3_BUCKET}/"
fi

# Prune old local backups (and their checksum manifests).
find "$BACKUP_DIR" -name 'backup-*.sql.gz.gpg' -mtime "+${RETENTION_DAYS}" -delete
find "$BACKUP_DIR" -name 'backup-*.sql.gz.gpg.sha256' -mtime "+${RETENTION_DAYS}" -delete

echo "[$(date -Is)] Backup complete"
