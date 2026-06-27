#!/usr/bin/env bash
set -euo pipefail

required_cmds=(gzip date)
for cmd in "${required_cmds[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Required command not found: $cmd" >&2
        exit 1
    fi
done

DOCKER_BIN=""
if command -v docker.exe >/dev/null 2>&1; then
    DOCKER_BIN="docker.exe"
elif command -v docker >/dev/null 2>&1; then
    DOCKER_BIN="docker"
fi

COMPOSE_CMD=()
if [[ -n "$DOCKER_BIN" ]] && "$DOCKER_BIN" compose version >/dev/null 2>&1; then
    COMPOSE_CMD=("$DOCKER_BIN" compose)
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD=(docker-compose)
fi

if [[ -f .env ]]; then
    set -a
    # Support Windows CRLF in .env files.
    # shellcheck disable=SC1091
    source <(sed 's/\r$//' .env)
    set +a
fi

USE_CONTAINER_DUMP="false"
if ! command -v mysqldump >/dev/null 2>&1; then
    if [[ ${#COMPOSE_CMD[@]} -gt 0 ]]; then
        USE_CONTAINER_DUMP="true"
    else
        echo "Required command not found: mysqldump (and compose fallback unavailable)" >&2
        exit 1
    fi
fi

AWS_CMD=()
AWS_VIA_DOCKER="false"
if command -v aws >/dev/null 2>&1; then
    AWS_CMD=(aws)
elif [[ -n "$DOCKER_BIN" ]]; then
    AWS_VIA_DOCKER="true"
    AWS_CMD=(
        "$DOCKER_BIN" run --rm -i
        -e AWS_ACCESS_KEY_ID
        -e AWS_SECRET_ACCESS_KEY
        -e AWS_SESSION_TOKEN
        -e AWS_DEFAULT_REGION
        -e AWS_REGION
    )
    if [[ -n "${HOME:-}" && -d "$HOME/.aws" ]]; then
        AWS_CMD+=( -v "$HOME/.aws:/root/.aws:ro" )
    fi
    AWS_CMD+=(amazon/aws-cli)
else
    echo "Required command not found: aws (and docker fallback unavailable)" >&2
    exit 1
fi

: "${DB_HOST:?DB_HOST is required}"
: "${DB_USER:?DB_USER is required}"
: "${DB_PASSWORD:?DB_PASSWORD is required}"
: "${DB_NAME:?DB_NAME is required}"
: "${S3_URI:?S3_URI is required (example: s3://my-bucket/mysql-backups)}"

if [[ "$S3_URI" != s3://* ]]; then
    echo "S3_URI must start with s3://" >&2
    exit 1
fi

DB_PORT="${DB_PORT:-3306}"
BACKUP_DIR="${BACKUP_DIR:-./backups}"
FILE_PREFIX="${FILE_PREFIX:-mysql_backup}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_FILE="${BACKUP_DIR}/${FILE_PREFIX}_${DB_NAME}_${TIMESTAMP}.sql.gz"

mkdir -p "$BACKUP_DIR"

if [[ "$USE_CONTAINER_DUMP" == "true" ]]; then
    DUMP_HOST="$DB_HOST"
    if [[ "$DUMP_HOST" == "127.0.0.1" ]]; then
        DUMP_HOST="localhost"
    fi

    DUMP_CMD="MYSQL_PWD=\"$DB_PASSWORD\" mysqldump --single-transaction --quick --routines --triggers --no-tablespaces -h \"$DUMP_HOST\" -P \"$DB_PORT\" -u \"$DB_USER\" \"$DB_NAME\""
    if ! "${COMPOSE_CMD[@]}" exec -T mysql sh -c "$DUMP_CMD" | gzip > "$BACKUP_FILE"; then
        # If app user auth fails, fallback to root from compose env.
        ROOT_USER="root"
        ROOT_PASS="${MYSQL_ROOT_PASSWORD:-}"
        if [[ -z "$ROOT_PASS" ]]; then
            ROOT_PASS="$("${COMPOSE_CMD[@]}" exec -T mysql sh -c 'printf %s "$MYSQL_ROOT_PASSWORD"')"
        fi
        ROOT_CMD="MYSQL_PWD=\"$ROOT_PASS\" mysqldump --single-transaction --quick --routines --triggers --no-tablespaces -h \"localhost\" -P \"3306\" -u \"$ROOT_USER\" \"$DB_NAME\""
        "${COMPOSE_CMD[@]}" exec -T mysql sh -c "$ROOT_CMD" | gzip > "$BACKUP_FILE"
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
        "$DB_NAME" | gzip > "$BACKUP_FILE"
    unset MYSQL_PWD
fi

# Support both target styles:
# - Prefix path: s3://bucket/folder (we append /)
# - Exact object key: s3://bucket/path/file.sql.gz (we keep as-is)
S3_TARGET="$S3_URI"
if [[ "$S3_URI" =~ ^s3://[^/]+$ ]]; then
    S3_TARGET="$S3_URI/"
elif [[ "$S3_URI" =~ ^s3://.*/[^/]+\.[A-Za-z0-9]+$ ]]; then
    S3_TARGET="$S3_URI"
elif [[ "$S3_URI" != */ ]]; then
    S3_TARGET="$S3_URI/"
fi

aws_args=(s3 cp "$BACKUP_FILE" "$S3_TARGET")
if [[ -n "${AWS_REGION:-}" ]]; then
    aws_args+=(--region "$AWS_REGION")
fi

if [[ "$AWS_VIA_DOCKER" == "true" ]]; then
    cat "$BACKUP_FILE" | "${AWS_CMD[@]}" "${aws_args[@]/$BACKUP_FILE/-}"
else
    "${AWS_CMD[@]}" "${aws_args[@]}"
fi

echo "Backup completed and uploaded: $BACKUP_FILE -> $S3_TARGET"

if [[ -n "${RETENTION_DAYS:-}" ]]; then
    find "$BACKUP_DIR" -type f -name "${FILE_PREFIX}_${DB_NAME}_*.sql.gz" -mtime +"$RETENTION_DAYS" -delete
    echo "Local retention cleanup applied: older than $RETENTION_DAYS days"
fi
