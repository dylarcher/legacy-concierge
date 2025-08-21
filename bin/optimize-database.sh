#!/bin/bash

# Database Optimization and Update Script for Legacy Concierge WordPress
# This script optimizes the database and applies performance improvements

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CONTAINER_NAME="legacy-concierge-mysql"
DB_NAME="wordpress"

echo -e "${BLUE}=== Database Optimization and Update Script ===${NC}"
echo "This script will optimize the WordPress database and apply performance improvements."
echo

# Function to check if Docker container is running
check_container() {
    if ! docker ps | grep -q "$CONTAINER_NAME"; then
        echo -e "${RED}Error: MySQL container '$CONTAINER_NAME' is not running.${NC}"
        echo "Please start the Docker services first with: docker-compose up -d"
        exit 1
    fi
    echo -e "${GREEN}✓ MySQL container is running${NC}"
}

# Function to wait for MySQL to be ready
wait_for_mysql() {
    echo -e "${YELLOW}Waiting for MySQL to be ready...${NC}"
    local counter=0
    local max_attempts=30

    while [ $counter -lt $max_attempts ]; do
        if docker exec "$CONTAINER_NAME" mysqladmin ping -h localhost --silent; then
            echo -e "${GREEN}✓ MySQL is ready${NC}"
            return 0
        fi
        counter=$((counter + 1))
        echo -n "."
        sleep 2
    done

    echo -e "${RED}Error: MySQL did not become ready within $((max_attempts * 2)) seconds${NC}"
    exit 1
}

# Function to optimize database tables
optimize_tables() {
    echo -e "${BLUE}Optimizing database tables...${NC}"

    # Get list of tables and optimize each one
    TABLES=$(docker exec "$CONTAINER_NAME" mysql -u root -p"${DB_ROOT_PASSWORD}" -D "$DB_NAME" -e "SHOW TABLES;" -s --skip-column-names)

    for table in $TABLES; do
        echo "Optimizing table: $table"
        docker exec "$CONTAINER_NAME" mysql -u root -p"${DB_ROOT_PASSWORD}" -D "$DB_NAME" -e "OPTIMIZE TABLE \`$table\`;" > /dev/null
    done

    echo -e "${GREEN}✓ All tables optimized${NC}"
}

# Function to repair database tables
repair_tables() {
    echo -e "${BLUE}Repairing database tables...${NC}"

    TABLES=$(docker exec "$CONTAINER_NAME" mysql -u root -p"${DB_ROOT_PASSWORD}" -D "$DB_NAME" -e "SHOW TABLES;" -s --skip-column-names)

    for table in $TABLES; do
        echo "Repairing table: $table"
        docker exec "$CONTAINER_NAME" mysql -u root -p"${DB_ROOT_PASSWORD}" -D "$DB_NAME" -e "REPAIR TABLE \`$table\`;" > /dev/null
    done

    echo -e "${GREEN}✓ All tables repaired${NC}"
}

# Function to update WordPress database
update_wordpress_db() {
    echo -e "${BLUE}Updating WordPress database structure...${NC}"

    # Run WordPress database upgrade
    docker exec legacy-concierge-wp wp core update-db --path=/var/www/html/wordpress --allow-root 2>/dev/null || true

    echo -e "${GREEN}✓ WordPress database updated${NC}"
}

# Function to flush WordPress cache and rewrite rules
flush_wordpress() {
    echo -e "${BLUE}Flushing WordPress cache and rewrite rules...${NC}"

    # Flush rewrite rules
    docker exec legacy-concierge-wp wp rewrite flush --path=/var/www/html/wordpress --allow-root 2>/dev/null || true

    # Flush object cache if available
    docker exec legacy-concierge-wp wp cache flush --path=/var/www/html/wordpress --allow-root 2>/dev/null || true

    echo -e "${GREEN}✓ WordPress cache and rewrite rules flushed${NC}"
}

# Function to analyze database performance
analyze_database() {
    echo -e "${BLUE}Analyzing database performance...${NC}"

    # Get database size
    DB_SIZE=$(docker exec "$CONTAINER_NAME" mysql -u root -p"${DB_ROOT_PASSWORD}" -D "$DB_NAME" -e "
        SELECT
            ROUND(SUM(data_length + index_length) / 1024 / 1024, 1) AS 'Database Size (MB)'
        FROM information_schema.tables
        WHERE table_schema='$DB_NAME';" -s --skip-column-names)

    echo "Database size: ${DB_SIZE} MB"

    # Get table count
    TABLE_COUNT=$(docker exec "$CONTAINER_NAME" mysql -u root -p"${DB_ROOT_PASSWORD}" -D "$DB_NAME" -e "
        SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$DB_NAME';" -s --skip-column-names)

    echo "Total tables: $TABLE_COUNT"

    # Get largest tables
    echo "Largest tables:"
    docker exec "$CONTAINER_NAME" mysql -u root -p"${DB_ROOT_PASSWORD}" -D "$DB_NAME" -e "
        SELECT
            table_name AS 'Table',
            ROUND(((data_length + index_length) / 1024 / 1024), 2) AS 'Size (MB)'
        FROM information_schema.TABLES
        WHERE table_schema = '$DB_NAME'
        ORDER BY (data_length + index_length) DESC
        LIMIT 10;"

    echo -e "${GREEN}✓ Database analysis complete${NC}"
}

# Function to clean up database
cleanup_database() {
    echo -e "${BLUE}Cleaning up database...${NC}"

    # Remove spam comments
    docker exec "$CONTAINER_NAME" mysql -u root -p"${DB_ROOT_PASSWORD}" -D "$DB_NAME" -e "
        DELETE FROM wp_comments WHERE comment_approved = 'spam';" 2>/dev/null || true

    # Remove trash posts
    docker exec "$CONTAINER_NAME" mysql -u root -p"${DB_ROOT_PASSWORD}" -D "$DB_NAME" -e "
        DELETE FROM wp_posts WHERE post_status = 'trash';" 2>/dev/null || true

    # Remove auto-drafts
    docker exec "$CONTAINER_NAME" mysql -u root -p"${DB_ROOT_PASSWORD}" -D "$DB_NAME" -e "
        DELETE FROM wp_posts WHERE post_status = 'auto-draft';" 2>/dev/null || true

    # Remove orphaned post meta
    docker exec "$CONTAINER_NAME" mysql -u root -p"${DB_ROOT_PASSWORD}" -D "$DB_NAME" -e "
        DELETE pm FROM wp_postmeta pm LEFT JOIN wp_posts wp ON wp.ID = pm.post_id WHERE wp.ID IS NULL;" 2>/dev/null || true

    # Remove orphaned comment meta
    docker exec "$CONTAINER_NAME" mysql -u root -p"${DB_ROOT_PASSWORD}" -D "$DB_NAME" -e "
        DELETE cm FROM wp_commentmeta cm LEFT JOIN wp_comments wc ON wc.comment_ID = cm.comment_id WHERE wc.comment_ID IS NULL;" 2>/dev/null || true

    echo -e "${GREEN}✓ Database cleanup complete${NC}"
}

# Main execution
main() {
    # Load environment variables
    if [ -f .env ]; then
        source .env
        echo -e "${GREEN}✓ Environment variables loaded${NC}"
    else
        echo -e "${RED}Error: .env file not found${NC}"
        exit 1
    fi

    # Check prerequisites
    check_container
    wait_for_mysql

    # Perform optimizations
    echo -e "${BLUE}=== Starting Database Optimization ===${NC}"

    repair_tables
    cleanup_database
    optimize_tables
    update_wordpress_db
    flush_wordpress
    analyze_database

    echo -e "${GREEN}=== Database Optimization Complete ===${NC}"
    echo "Your WordPress database has been optimized and updated."
    echo
    echo "To monitor performance:"
    echo "- Access phpMyAdmin at http://localhost:8081"
    echo "- Check slow query log: docker exec $CONTAINER_NAME cat /var/log/mysql/mysql-slow.log"
    echo "- Monitor with: docker stats $CONTAINER_NAME"
}

# Run the script
main "$@"
