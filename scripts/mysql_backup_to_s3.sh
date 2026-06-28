#!/bin/bash

DATE=$(date +%Y%m%d_%H%M%S)

DB_CONTAINER="om-mysql"
DB_NAME="app_db"
DB_USER="app_user"
DB_PASSWORD="app_pass"

BACKUP_DIR="./backups"

S3_BUCKET="s3://my-backup-bucket/mysql"

mkdir -p "$BACKUP_DIR"

BACKUP_FILE="$BACKUP_DIR/mysql_backup_${DATE}.sql"

docker exec "$DB_CONTAINER" mysqldump \
--no-tablespaces \
-u"$DB_USER" \
-p"$DB_PASSWORD" \
"$DB_NAME" > "$BACKUP_FILE"

gzip "$BACKUP_FILE"

aws s3 cp "${BACKUP_FILE}.gz" "$S3_BUCKET/"

echo "Backup uploaded successfully"
echo "${BACKUP_FILE}.gz"
