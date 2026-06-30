#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
    echo "Error: Script must be run with sudo."
    exit 1
fi

if [ ! -f "docker-compose.yml" ]; then
    echo "Error: docker-compose.yml not found. Run this script from the project root."
    exit 1
fi

TARGET_USER="${SUDO_USER:-$(whoami)}"
BACKUP_ARCHIVE="n8n-backup-$(date +%Y%m%d-%H%M%S).xx.tar.gz"

echo "Ensuring containers are running for database dump..."
docker compose up -d

echo "Generating logical PostgreSQL dump..."
set +e
DUMP_SUCCESS=false
for i in {1..15}; do
    if docker compose exec -T postgres sh -c 'pg_dumpall -U ${POSTGRES_USER}' > pg_dump.xx.sql 2>/dev/null; then
        DUMP_SUCCESS=true
        break
    fi
    sleep 2
done
set -e

if [ "$DUMP_SUCCESS" != "true" ]; then
    echo "Error: Failed to create database dump. Ensure PostgreSQL is healthy."
    exit 1
fi

echo "Stopping containers to ensure data consistency..."
docker compose down

echo "Creating compressed backup archive..."
tar -czpf "$BACKUP_ARCHIVE" .

echo "Restoring ownership to $TARGET_USER..."
chown "$TARGET_USER:$TARGET_USER" "$BACKUP_ARCHIVE"

echo "Restarting services..."
docker compose up -d

echo "Backup completed successfully: $BACKUP_ARCHIVE"