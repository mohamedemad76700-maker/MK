#!/usr/bin/env bash
set -euo pipefail
umask 077
cd "$(dirname "$0")"

[ -f .env ] || { echo "Create and configure .env first."; exit 1; }
set -a; . ./.env; set +a
: "${DATABASE_URL:?DATABASE_URL is required}"
: "${BACKUP_GPG_RECIPIENT:?Set BACKUP_GPG_RECIPIENT to the verified full GPG recipient fingerprint}"

command -v pg_dump >/dev/null 2>&1 || { echo "Install PostgreSQL client tools (pg_dump) first."; exit 1; }
command -v tar >/dev/null 2>&1 || { echo "tar was not found."; exit 1; }
command -v gpg >/dev/null 2>&1 || { echo "Install GPG and import the verified backup recipient public key first."; exit 1; }

MEDIA_DIR="${MEDIA_ROOT:-video_engine_backend/media}"
case "$MEDIA_DIR" in /*) ;; *) MEDIA_DIR="$PWD/$MEDIA_DIR" ;; esac
[ -d "$MEDIA_DIR" ] || { echo "MEDIA_ROOT does not exist: $MEDIA_DIR"; exit 1; }

STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p backups
DB_FILE="backups/mk-school-db-${STAMP}.dump.gpg"
MEDIA_FILE="backups/mk-school-media-${STAMP}.tar.gz.gpg"
cleanup() { [ ! -f "$DB_FILE" ] || rm -f -- "$DB_FILE"; [ ! -f "$MEDIA_FILE" ] || rm -f -- "$MEDIA_FILE"; }
trap 'status=$?; if [ "$status" -ne 0 ]; then cleanup; fi' EXIT

pg_dump --format=custom "$DATABASE_URL" \
  | gpg --batch --yes --trust-model always --recipient "$BACKUP_GPG_RECIPIENT" --output "$DB_FILE" --encrypt
tar -czf - -C "$MEDIA_DIR" . \
  | gpg --batch --yes --trust-model always --recipient "$BACKUP_GPG_RECIPIENT" --output "$MEDIA_FILE" --encrypt

echo "Encrypted backup completed: $DB_FILE and $MEDIA_FILE"
echo "Keep the matching private key separate from this computer; restore-test both files on an isolated staging system."
