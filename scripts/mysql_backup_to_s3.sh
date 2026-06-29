#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ -f "$SCRIPT_DIR/../.env" ]; then
    set -a
    source "$SCRIPT_DIR/../.env"
    set +a
fi

DATE="$(date +%Y%m%d_%H%M%S)"

DB_CONTAINER="om-mysql"
DB_NAME="app_db"
DB_USER="app_user"
DB_PASSWORD="app_pass"

BACKUP_DIR="./backups"
FILE_PREFIX="mysql_backup"

S3_URI="s3://devops-mysql-backup-unique-name/mysql-backups/"

if [[ -z "$S3_URI" ]]; then
	echo "Error: S3_URI is required (example: s3://your-bucket/mysql-backups)" >&2
	exit 1
fi

for cmd in docker aws gzip; do
	if ! command -v "$cmd" >/dev/null 2>&1; then
		echo "Error: required command not found: $cmd" >&2
		exit 1
	fi
done

if ! docker ps --format '{{.Names}}' | grep -Fxq "$DB_CONTAINER"; then
	echo "Error: container '$DB_CONTAINER' is not running." >&2
	exit 1
fi

mkdir -p "$BACKUP_DIR"
BACKUP_FILE="$BACKUP_DIR/${FILE_PREFIX}_${DATE}.sql"

docker exec "$DB_CONTAINER" sh -c "exec mysqldump --no-tablespaces -u\"$DB_USER\" -p\"$DB_PASSWORD\" \"$DB_NAME\"" > "$BACKUP_FILE"

gzip -f "$BACKUP_FILE"

if [[ "$S3_URI" == */ ]]; then
	TARGET_URI="$S3_URI"
else
	TARGET_URI="$S3_URI/"
fi

aws s3 cp "${BACKUP_FILE}.gz" "$TARGET_URI"

echo "Backup uploaded successfully"
echo "${BACKUP_FILE}.gz"
