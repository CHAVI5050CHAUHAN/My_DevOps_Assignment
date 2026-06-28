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

USE_CONTAINER_DUMP="${USE_CONTAINER_DUMP:-false}"
MYSQL_CONTAINER="${MYSQL_CONTAINER:-om-mysql}"

BACKUP_DIR="${BACKUP_DIR:-./backups}"

#############################################
# Validation
#############################################

if [[ -z "$DB_NAME" ]]; then
    echo "ERROR: DB_NAME is empty"
    exit 1
fi

if [[ -z "$DB_USER" ]]; then
    echo "ERROR: DB_USER is empty"
    exit 1
fi

mkdir -p "$BACKUP_DIR"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

BACKUP_FILE="${BACKUP_DIR}/mysql_backup_${DB_NAME}_${TIMESTAMP}.sql.gz"

echo "================================="
echo "MySQL Backup Started"
echo "Database : $DB_NAME"
echo "Host     : $DB_HOST"
echo "Port     : $DB_PORT"
echo "Mode     : $USE_CONTAINER_DUMP"
echo "Backup   : $BACKUP_FILE"
echo "================================="

#############################################
# Docker Backup
#############################################

if [[ "$USE_CONTAINER_DUMP" == "true" ]]; then

    echo "Using Docker backup mode"

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
        | gzip > "$BACKUP_FILE"
    then

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

        echo "Backup completed using root"

    fi

#############################################
# Local mysqldump Backup
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
# Verification
#############################################

if [[ ! -s "$BACKUP_FILE" ]]; then
    echo "ERROR: Backup file is empty."
    exit 1
fi

echo
echo "Backup completed successfully"
echo "File : $BACKUP_FILE"

ls -lh "$BACKUP_FILE"

echo "================================="
echo "Done"
echo "================================="
