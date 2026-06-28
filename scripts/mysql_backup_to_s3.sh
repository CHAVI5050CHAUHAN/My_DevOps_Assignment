#!/bin/bash

set -euo pipefail

#############################################
# Configuration
#############################################

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-3306}"

DB_NAME="${DB_NAME:-app_db}"
DB_USER="${DB_USER:-app_user}"
DB_PASSWORD="${DB_PASSWORD:-app_pass}"

MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-rootpass}"

USE_CONTAINER_DUMP="${USE_CONTAINER_DUMP:-true}"
MYSQL_CONTAINER="${MYSQL_CONTAINER:-om-mysql}"

BACKUP_DIR="${BACKUP_DIR:-./backups}"

#############################################
# Create Backup Directory
#############################################

mkdir -p "$BACKUP_DIR"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

BACKUP_FILE="${BACKUP_DIR}/mysql_backup_${DB_NAME}_${TIMESTAMP}.sql.gz"

echo "======================================="
echo "Starting MySQL Backup"
echo "Database  : $DB_NAME"
echo "Backup    : $BACKUP_FILE"
echo "======================================="

#############################################
# Backup Using Docker Container
#############################################

if [[ "$USE_CONTAINER_DUMP" == "true" ]]; then

    echo "Using Docker container backup mode"

    DUMP_CMD="
        MYSQL_PWD=\"$DB_PASSWORD\" mysqldump \
        --single-transaction \
        --quick \
        --routines \
        --triggers \
        --no-tablespaces \
        -h localhost \
        -P 3306 \
        -u \"$DB_USER\" \
        \"$DB_NAME\"
    "

    if docker exec -i "$MYSQL_CONTAINER" sh -c "$DUMP_CMD" \
        | gzip > "$BACKUP_FILE"; then

        echo "Backup completed using application user"

    else

        echo "Application user backup failed"
        echo "Trying MySQL root user..."

        ROOT_CMD="
            MYSQL_PWD=\"$MYSQL_ROOT_PASSWORD\" mysqldump \
            --single-transaction \
            --quick \
            --routines \
            --triggers \
            --no-tablespaces \
            -h localhost \
            -P 3306 \
            -u root \
            \"$DB_NAME\"
        "

        docker exec -i "$MYSQL_CONTAINER" sh -c "$ROOT_CMD" \
            | gzip > "$BACKUP_FILE"

        echo "Backup completed using root user"

    fi

#############################################
# Backup Using Local mysqldump
#############################################

else

    echo "Using local mysqldump"

    export MYSQL_PWD="$DB_PASSWORD"

    mysqldump \
        --single-transaction \
        --quick \
        --routines \
        --triggers \
        --no-tablespaces \
        -h "$DB_HOST" \
        -P "$DB_PORT" \
        -u "$DB_USER" \
        "$DB_NAME" \
        | gzip > "$BACKUP_FILE"

    unset MYSQL_PWD

fi

#############################################
# Validation
#############################################

if [[ ! -s "$BACKUP_FILE" ]]; then
    echo "ERROR: Backup file is empty."
    exit 1
fi

echo
echo "Backup successful"
echo "Location : $BACKUP_FILE"

ls -lh "$BACKUP_FILE"

echo "======================================="
echo "Backup completed successfully"
echo "======================================="
