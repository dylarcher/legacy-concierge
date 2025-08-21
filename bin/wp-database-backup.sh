#!/bin/bash

# WordPress Backup Script
# Run this script regularly to backup your WordPress installation

BACKUP_DIR="/backups"
DATE=$(date +%Y%m%d_%H%M%S)
SITE_NAME="legacy-concierge"

# Create backup directory
mkdir -p ${BACKUP_DIR}

echo "Starting backup for ${SITE_NAME} at $(date)"

# Backup database
echo "Backing up database..."
docker exec legacy-concierge_db mysqldump -u ${MYSQL_USER} -p${MYSQL_PASSWORD} ${MYSQL_DATABASE} > ${BACKUP_DIR}/${SITE_NAME}_db_${DATE}.sql

# Backup WordPress files
echo "Backing up WordPress files..."
tar -czf ${BACKUP_DIR}/${SITE_NAME}_files_${DATE}.tar.gz -C /Users/darcher/dev/legacyConcierge wp-content/

# Backup configuration
echo "Backing up configuration..."
cp /Users/darcher/dev/legacyConcierge/wp-config.php ${BACKUP_DIR}/${SITE_NAME}_config_${DATE}.php
cp /Users/darcher/dev/legacyConcierge/.htaccess ${BACKUP_DIR}/${SITE_NAME}_htaccess_${DATE}.txt

# Remove backups older than 30 days
echo "Cleaning old backups..."
find ${BACKUP_DIR} -name "${SITE_NAME}_*" -type f -mtime +30 -delete

echo "Backup completed at $(date)"
echo "Files saved to: ${BACKUP_DIR}"

# List current backups
echo "Current backups:"
ls -la ${BACKUP_DIR}/${SITE_NAME}_*_${DATE}.*
