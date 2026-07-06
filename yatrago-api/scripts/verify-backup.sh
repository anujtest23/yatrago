#!/usr/bin/env bash
#
# Backup verification for YatraGo — run this on a schedule (e.g. weekly cron)
# so the FIRST time a restore is attempted is never during an incident.
#
#   0 4 * * 0  /path/to/verify-backup.sh >> /var/log/yatrago-verify.log 2>&1
#
# Verification levels (each includes the previous):
#   1. checksum  — sha256 manifest matches the backup file
#   2. decrypt   — GPG passphrase decrypts and gzip integrity holds
#   3. restore   — full restore into a scratch database, sanity-count rows
#                  (only when RESTORE_TEST_DB_URL is set; the scratch DB is
#                  DROPPED AND RECREATED every run — never point it at a
#                  database you care about)
#
# Required env:
#   BACKUP_PASSPHRASE     same passphrase the backup was written with
# Optional env:
#   BACKUP_DIR            where backups live (default: ./backups)
#   BACKUP_FILE           specific file to verify (default: newest)
#   RESTORE_TEST_DB_URL   postgres URL of a DISPOSABLE scratch database
#   ALERT_WEBHOOK         Slack-compatible webhook to notify on failure

set -uo pipefail

BACKUP_DIR="${BACKUP_DIR:-./backups}"

fail() {
  echo "[$(date -Is)] VERIFY FAILED: $1" >&2
  if [[ -n "${ALERT_WEBHOOK:-}" ]]; then
    curl -sS -m 10 -X POST -H 'Content-Type: application/json' \
      -d "{\"text\":\"[SECURITY ALERT] Backup verification FAILED: $1\"}" \
      "$ALERT_WEBHOOK" || true
  fi
  exit 1
}

: "${BACKUP_PASSPHRASE:?BACKUP_PASSPHRASE is required}"

FILE="${BACKUP_FILE:-$(ls -1t "${BACKUP_DIR}"/backup-*.sql.gz.gpg 2>/dev/null | head -1)}"
[[ -n "$FILE" && -f "$FILE" ]] || fail "no backup file found in ${BACKUP_DIR}"

echo "[$(date -Is)] Verifying ${FILE}"

# 1. Checksum
if [[ -f "${FILE}.sha256" ]]; then
  sha256sum -c "${FILE}.sha256" >/dev/null 2>&1 \
    || fail "sha256 mismatch for ${FILE} (corrupted backup)"
  echo "[$(date -Is)] checksum OK"
else
  echo "[$(date -Is)] WARNING: no .sha256 manifest (older backup?) — skipping"
fi

# 2. Decrypt + gzip integrity (streamed; plaintext never hits disk)
gpg --batch --quiet --passphrase "$BACKUP_PASSPHRASE" -d "$FILE" 2>/dev/null \
  | gunzip -t \
  || fail "decryption/gzip integrity check failed for ${FILE}"
echo "[$(date -Is)] decrypt + compression integrity OK"

# 3. Optional full restore test into a disposable scratch database
if [[ -n "${RESTORE_TEST_DB_URL:-}" ]]; then
  echo "[$(date -Is)] restore test into scratch database"
  ADMIN_URL="${RESTORE_TEST_DB_URL%/*}/postgres"
  SCRATCH_DB="${RESTORE_TEST_DB_URL##*/}"; SCRATCH_DB="${SCRATCH_DB%%\?*}"

  psql "$ADMIN_URL" -v ON_ERROR_STOP=1 \
    -c "DROP DATABASE IF EXISTS \"${SCRATCH_DB}\";" \
    -c "CREATE DATABASE \"${SCRATCH_DB}\";" \
    || fail "could not recreate scratch database ${SCRATCH_DB}"

  gpg --batch --quiet --passphrase "$BACKUP_PASSPHRASE" -d "$FILE" 2>/dev/null \
    | gunzip \
    | psql "$RESTORE_TEST_DB_URL" -q -v ON_ERROR_STOP=1 >/dev/null \
    || fail "restore into scratch database failed"

  USERS=$(psql "$RESTORE_TEST_DB_URL" -tAc 'SELECT count(*) FROM users;' 2>/dev/null) \
    || fail "restored database missing users table"
  echo "[$(date -Is)] restore OK (${USERS} users restored)"

  psql "$ADMIN_URL" -c "DROP DATABASE IF EXISTS \"${SCRATCH_DB}\";" >/dev/null || true
fi

echo "[$(date -Is)] Backup verification PASSED"
