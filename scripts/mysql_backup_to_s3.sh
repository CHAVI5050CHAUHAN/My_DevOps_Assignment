#!/bin/bash

set -e

#######################################
# Configuration
#######################################

DB_NAME="app_db"
DB_USER="app_user"
DB_PASSWORD="app_pass"

MYSQL_ROOT_PASSWORD="rootpass"

MYSQL_CONTAINER="om-mysql"

BACKUP_DIR="./backups"

#######################################
# Prepare backup directory
#######################################

mkdir -p "$BACKUP_DIR"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

BACKUP_FILE="${BACKUP_DIR}/mysql_backup_${DB_NAME}_${TIMESTAMP}.sql.gz"

echo "Creating backup: $BACKUP_FILE"

#######################################
# Backup using application user
#######################################

if docker exec "$MYSQL_CONTAINER" \
    sh -c "MYSQL_PWD='$DB_PASSWORD' mysqldump \
    --single-transaction \
    --quick \
    --routines \
    --triggers \
    --no-tablespaces \
    -u '$DB_USER' \
    '$DB_NAME'" \
    | gzip > "$BACKUP_FILE"
then

    echo "Backup completed using application user."

else

    echo "Application user backup failed."
    echo "Trying root user..."

    docker exec "$MYSQL_CONTAINER" \
        sh -c "MYSQL_PWD='$MYSQL_ROOT_PASSWORD' mysqldump \
        --single-transaction \
        --quick \
        --routines \
        --triggers \
        --no-tablespaces \
        -u root \
        '$DB_NAME'" \
        | gzip > "$BACKUP_FILE"

fi

#######################################
# Verify backup
#######################################

if [[ ! -s "$BACKUP_FILE" ]]; then
    echo "ERROR: Backup failed."
    exit 1
fi

echo ""
echo "Backup successful."
echo "Backup file:"
echo "$BACKUP_FILE"

ls -lh "$BACKUP_FILE"
