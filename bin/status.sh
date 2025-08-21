#!/bin/bash

# Comprehensive Status and Monitoring Script for Legacy Concierge WordPress
# This script provides detailed information about the Docker environment and WordPress setup

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
MYSQL_CONTAINER="legacy-concierge-mysql"
WP_CONTAINER="legacy-concierge-wp"
PHPMYADMIN_CONTAINER="legacy-concierge-phpmyadmin"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  LEGACY CONCIERGE WORDPRESS STATUS   ${NC}"
echo -e "${BLUE}========================================${NC}"
echo

# Function to check if Docker is running
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}✗ Docker is not installed${NC}"
        exit 1
    fi

    if ! docker info &> /dev/null; then
        echo -e "${RED}✗ Docker is not running${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓ Docker is running${NC}"
}

# Function to show container status
show_container_status() {
    echo -e "${CYAN}=== Container Status ===${NC}"
    docker-compose ps
    echo
}

# Function to show container health
show_container_health() {
    echo -e "${CYAN}=== Container Health ===${NC}"

    # MySQL Health
    if docker ps | grep -q "$MYSQL_CONTAINER"; then
        MYSQL_HEALTH=$(docker inspect --format='{{.State.Health.Status}}' "$MYSQL_CONTAINER" 2>/dev/null || echo "no-healthcheck")
        if [ "$MYSQL_HEALTH" = "healthy" ]; then
            echo -e "${GREEN}✓ MySQL Container: $MYSQL_HEALTH${NC}"
        else
            echo -e "${YELLOW}⚠ MySQL Container: $MYSQL_HEALTH${NC}"
        fi
    else
        echo -e "${RED}✗ MySQL Container: not running${NC}"
    fi

    # WordPress Health
    if docker ps | grep -q "$WP_CONTAINER"; then
        WP_HEALTH=$(docker inspect --format='{{.State.Health.Status}}' "$WP_CONTAINER" 2>/dev/null || echo "no-healthcheck")
        if [ "$WP_HEALTH" = "healthy" ]; then
            echo -e "${GREEN}✓ WordPress Container: $WP_HEALTH${NC}"
        else
            echo -e "${YELLOW}⚠ WordPress Container: $WP_HEALTH${NC}"
        fi
    else
        echo -e "${RED}✗ WordPress Container: not running${NC}"
    fi

    # phpMyAdmin Health
    if docker ps | grep -q "$PHPMYADMIN_CONTAINER"; then
        echo -e "${GREEN}✓ phpMyAdmin Container: running${NC}"
    else
        echo -e "${RED}✗ phpMyAdmin Container: not running${NC}"
    fi

    echo
}

# Function to show service URLs
show_service_urls() {
    echo -e "${CYAN}=== Service URLs ===${NC}"
    echo -e "WordPress Site: ${GREEN}http://localhost:8080${NC}"
    echo -e "phpMyAdmin: ${GREEN}http://localhost:8081${NC}"
    echo -e "MySQL Direct: ${GREEN}localhost:3306${NC}"
    echo
}

# Function to show resource usage
show_resource_usage() {
    echo -e "${CYAN}=== Resource Usage ===${NC}"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" $(docker-compose ps -q) 2>/dev/null || echo "No containers running"
    echo
}

# Function to show database information
show_database_info() {
    if docker ps | grep -q "$MYSQL_CONTAINER"; then
        echo -e "${CYAN}=== Database Information ===${NC}"

        # Load environment variables
        if [ -f .env ]; then
            source .env
        fi

        # Database size and table count
        DB_SIZE=$(docker exec "$MYSQL_CONTAINER" mysql -u root -p"${DB_ROOT_PASSWORD}" -D "${DB_NAME}" -e "
            SELECT
                ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)'
            FROM information_schema.tables
            WHERE table_schema='${DB_NAME}';" -s --skip-column-names 2>/dev/null || echo "N/A")

        TABLE_COUNT=$(docker exec "$MYSQL_CONTAINER" mysql -u root -p"${DB_ROOT_PASSWORD}" -D "${DB_NAME}" -e "
            SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${DB_NAME}';" -s --skip-column-names 2>/dev/null || echo "N/A")

        echo -e "Database Name: ${GREEN}${DB_NAME}${NC}"
        echo -e "Database Size: ${GREEN}${DB_SIZE} MB${NC}"
        echo -e "Table Count: ${GREEN}${TABLE_COUNT}${NC}"
        echo
    fi
}

# Function to show WordPress information
show_wordpress_info() {
    echo -e "${CYAN}=== WordPress Information ===${NC}"

    # Check if WordPress files exist
    if [ -f "wordpress/wp-config.php" ]; then
        echo -e "${GREEN}✓ WordPress installation found${NC}"

        # Try to get WordPress version
        if [ -f "wordpress/wp-includes/version.php" ]; then
            WP_VERSION=$(grep 'wp_version =' wordpress/wp-includes/version.php | cut -d "'" -f 2 2>/dev/null || echo "Unknown")
            echo -e "WordPress Version: ${GREEN}${WP_VERSION}${NC}"
        fi

        # Check if composer.json exists
        if [ -f "composer.json" ]; then
            echo -e "${GREEN}✓ Composer configuration found${NC}"
            PLUGIN_COUNT=$(grep -c '"wpackagist-plugin/' composer.json 2>/dev/null || echo "0")
            THEME_COUNT=$(grep -c '"wpackagist-theme/' composer.json 2>/dev/null || echo "0")
            echo -e "Composer Plugins: ${GREEN}${PLUGIN_COUNT}${NC}"
            echo -e "Composer Themes: ${GREEN}${THEME_COUNT}${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ WordPress files not found in expected location${NC}"
    fi
    echo
}

# Function to show logs
show_recent_logs() {
    echo -e "${CYAN}=== Recent Container Logs ===${NC}"

    if docker ps | grep -q "$MYSQL_CONTAINER"; then
        echo -e "${PURPLE}MySQL Logs (last 5 lines):${NC}"
        docker logs "$MYSQL_CONTAINER" --tail 5 2>/dev/null || echo "No logs available"
        echo
    fi

    if docker ps | grep -q "$WP_CONTAINER"; then
        echo -e "${PURPLE}WordPress Logs (last 5 lines):${NC}"
        docker logs "$WP_CONTAINER" --tail 5 2>/dev/null || echo "No logs available"
        echo
    fi
}

# Function to show network information
show_network_info() {
    echo -e "${CYAN}=== Network Information ===${NC}"
    docker network ls | grep -E "(NETWORK|wp-network)" || echo "No custom networks found"
    echo
}

# Function to show volumes
show_volume_info() {
    echo -e "${CYAN}=== Volume Information ===${NC}"
    docker volume ls | grep -E "(DRIVER|mysql_data)" || echo "No custom volumes found"
    echo
}

# Function to show security check
show_security_check() {
    echo -e "${CYAN}=== Security Check ===${NC}"

    # Check .env file
    if [ -f ".env" ]; then
        echo -e "${GREEN}✓ Environment file exists${NC}"
        if [ "$(stat -f %A .env 2>/dev/null || stat -c %a .env 2>/dev/null)" = "600" ]; then
            echo -e "${GREEN}✓ Environment file permissions are secure${NC}"
        else
            echo -e "${YELLOW}⚠ Environment file permissions should be 600${NC}"
        fi
    else
        echo -e "${RED}✗ Environment file missing${NC}"
    fi

    # Check wp-config.php permissions
    if [ -f "wordpress/wp-config.php" ]; then
        echo -e "${GREEN}✓ WordPress config exists${NC}"
        if grep -q "SECURE_AUTH_KEY" wordpress/wp-config.php; then
            echo -e "${GREEN}✓ Security keys are configured${NC}"
        else
            echo -e "${YELLOW}⚠ Security keys may need updating${NC}"
        fi
    fi

    echo
}

# Function to show maintenance tasks
show_maintenance_tasks() {
    echo -e "${CYAN}=== Maintenance Tasks ===${NC}"
    echo -e "Run database optimization: ${GREEN}./optimize-database.sh${NC}"
    echo -e "Update plugins: ${GREEN}composer update${NC}"
    echo -e "Backup database: ${GREEN}docker exec $MYSQL_CONTAINER mysqldump -u root -p wordpress > backup.sql${NC}"
    echo -e "View container logs: ${GREEN}docker logs [container_name]${NC}"
    echo -e "Monitor resources: ${GREEN}docker stats${NC}"
    echo
}

# Main execution
main() {
    check_docker
    echo

    # Load environment variables if available
    if [ -f .env ]; then
        source .env
    fi

    show_container_status
    show_container_health
    show_service_urls
    show_resource_usage
    show_database_info
    show_wordpress_info
    show_network_info
    show_volume_info
    show_security_check
    show_recent_logs
    show_maintenance_tasks

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}        STATUS CHECK COMPLETE          ${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Run the script
main "$@"
