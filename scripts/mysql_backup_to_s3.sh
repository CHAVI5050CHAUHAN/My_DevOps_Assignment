# Backup location
BACKUP_DIR="${BACKUP_DIR:-./backups}"
mkdir -p "$BACKUP_DIR"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/mysql_backup_${DB_NAME}_${TIMESTAMP}.sql.gz"

echo "Creating backup: $BACKUP_FILE"

if [[ "$USE_CONTAINER_DUMP" == "true" ]]; then

    MYSQL_CONTAINER="${MYSQL_CONTAINER:-om-mysql}"

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

    if ! docker exec -i "$MYSQL_CONTAINER" sh -c "$DUMP_CMD" \
        | gzip > "$BACKUP_FILE"; then

        echo "User backup failed. Trying root..."

        ROOT_PASS="${MYSQL_ROOT_PASSWORD:-rootpass}"

        ROOT_CMD="
            MYSQL_PWD=\"$ROOT_PASS\" mysqldump \
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

    fi

else

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

echo "Backup completed: $BACKUP_FILE"
