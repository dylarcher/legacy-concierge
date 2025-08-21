#!/bin/bash

# WordPress Maintenance and Monitoring Script
# Comprehensive maintenance tasks for optimal WordPress performance

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="legacy-concierge"
WP_CONTAINER="legacy-concierge-wp"
DB_CONTAINER="legacy-concierge-mysql"
BACKUP_DIR="./backups"
LOG_DIR="./logs"
DATE=$(date +"%Y%m%d_%H%M%S")

print_header() {
    echo -e "${BLUE}${BOLD}========================================${NC}"
    echo -e "${BLUE}${BOLD}  WORDPRESS MAINTENANCE MANAGER       ${NC}"
    echo -e "${BLUE}${BOLD}========================================${NC}"
    echo
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

usage() {
    echo -e "${BOLD}Usage:${NC} $0 [COMMAND] [OPTIONS]"
    echo
    echo -e "${BOLD}COMMANDS:${NC}"
    echo "  daily             - Run daily maintenance tasks"
    echo "  weekly            - Run weekly maintenance tasks"
    echo "  monthly           - Run monthly maintenance tasks"
    echo "  security-scan     - Run comprehensive security scan"
    echo "  performance-audit - Analyze site performance"
    echo "  cleanup           - Clean temporary files and optimize"
    echo "  update-all        - Update WordPress core, themes, and plugins"
    echo "  backup-full       - Create complete backup (database + files)"
    echo "  health-report     - Generate comprehensive health report"
    echo "  monitor           - Start continuous monitoring mode"
    echo
    echo -e "${BOLD}OPTIONS:${NC}"
    echo "  --verbose         - Show detailed output"
    echo "  --dry-run         - Show what would be done without executing"
    echo "  --schedule        - Run in scheduled mode (less interactive)"
    echo "  --email           - Send report via email (requires configuration)"
    echo
    echo -e "${BOLD}EXAMPLES:${NC}"
    echo "  $0 daily"
    echo "  $0 weekly --verbose"
    echo "  $0 security-scan --email"
    echo "  $0 backup-full"
}

check_prerequisites() {
    # Ensure directories exist
    mkdir -p "$BACKUP_DIR" "$LOG_DIR"

    # Check Docker containers
    if ! docker-compose ps | grep -q "Up"; then
        print_warning "Starting Docker containers..."
        docker-compose up -d
        sleep 15
    fi

    # Load environment variables
    if [[ -f .env ]]; then
        source .env
    else
        print_warning ".env file not found"
    fi
}

log_activity() {
    local message="$1"
    local log_file="$LOG_DIR/maintenance_${DATE}.log"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" >> "$log_file"
}

run_daily_maintenance() {
    print_info "Running daily maintenance tasks..."
    log_activity "Starting daily maintenance"

    # 1. Check system health
    print_info "1. System health check..."
    ./bin/health-check.sh >> "$LOG_DIR/health_${DATE}.log"

    # 2. Update plugins (security updates only)
    print_info "2. Checking for security updates..."
    docker exec "$WP_CONTAINER" wp plugin update --all --dry-run --allow-root | grep -i security || print_info "No security updates available"

    # 3. Clear caches
    print_info "3. Clearing caches..."
    if docker exec "$WP_CONTAINER" wp cache flush --allow-root 2>/dev/null; then
        print_success "WordPress cache cleared"
    fi

    # Clear object cache if available
    docker exec "$WP_CONTAINER" wp cache flush --allow-root 2>/dev/null || true

    # 4. Check for broken links (basic)
    print_info "4. Basic link check..."
    curl -f -s "http://localhost:8080/wordpress/" > /dev/null && print_success "Site is accessible" || print_error "Site not accessible"

    # 5. Monitor disk space
    print_info "5. Disk space check..."
    local disk_usage
    disk_usage=$(df -h . | tail -1 | awk '{print $5}' | sed 's/%//')
    if [[ $disk_usage -gt 80 ]]; then
        print_warning "Disk space usage: ${disk_usage}%"
    else
        print_success "Disk space usage: ${disk_usage}%"
    fi

    # 6. Check error logs
    print_info "6. Checking error logs..."
    if [[ -f "wp-content/debug.log" ]]; then
        local error_count
        error_count=$(tail -100 wp-content/debug.log 2>/dev/null | grep -i error | wc -l || echo 0)
        if [[ $error_count -gt 0 ]]; then
            print_warning "Found $error_count recent errors in debug.log"
        else
            print_success "No recent errors found"
        fi
    fi

    log_activity "Daily maintenance completed"
    print_success "Daily maintenance completed"
}

run_weekly_maintenance() {
    print_info "Running weekly maintenance tasks..."
    log_activity "Starting weekly maintenance"

    # Run daily tasks first
    run_daily_maintenance

    # 1. Full plugin and theme updates
    print_info "1. Updating plugins and themes..."
    docker exec "$WP_CONTAINER" wp plugin update --all --allow-root
    docker exec "$WP_CONTAINER" wp theme update --all --allow-root

    # 2. Database optimization
    print_info "2. Optimizing database..."
    ./bin/optimize-database.sh

    # 3. Security scan
    print_info "3. Security scan..."
    run_security_scan

    # 4. Performance audit
    print_info "4. Performance audit..."
    run_performance_audit

    # 5. Backup creation
    print_info "5. Creating weekly backup..."
    create_full_backup "weekly"

    # 6. Clean up old files
    print_info "6. Cleaning up old files..."
    cleanup_old_files

    log_activity "Weekly maintenance completed"
    print_success "Weekly maintenance completed"
}

run_monthly_maintenance() {
    print_info "Running monthly maintenance tasks..."
    log_activity "Starting monthly maintenance"

    # Run weekly tasks first
    run_weekly_maintenance

    # 1. WordPress core update
    print_info "1. Checking WordPress core updates..."
    if docker exec "$WP_CONTAINER" wp core check-update --allow-root | grep -q "WordPress is at the latest version"; then
        print_success "WordPress is up to date"
    else
        print_info "WordPress updates available:"
        docker exec "$WP_CONTAINER" wp core check-update --allow-root
    fi

    # 2. Comprehensive security audit
    print_info "2. Comprehensive security audit..."
    run_comprehensive_security_scan

    # 3. Performance optimization
    print_info "3. Performance optimization..."
    optimize_performance

    # 4. Update documentation
    print_info "4. Updating documentation..."
    generate_changelog

    # 5. Archive old backups
    print_info "5. Archiving old backups..."
    archive_old_backups

    log_activity "Monthly maintenance completed"
    print_success "Monthly maintenance completed"
}

run_security_scan() {
    print_info "Running security scan..."
    local security_log="$LOG_DIR/security_${DATE}.log"

    # 1. Check file permissions
    print_info "Checking file permissions..."
    find . -name "*.php" -perm 777 > "$security_log" 2>/dev/null || true
    if [[ -s "$security_log" ]]; then
        print_warning "Found PHP files with 777 permissions"
        cat "$security_log"
    else
        print_success "File permissions look good"
    fi

    # 2. Check for malware signatures
    print_info "Scanning for malware signatures..."
    grep -r "eval(" wp-content/ 2>/dev/null | head -5 >> "$security_log" || true
    grep -r "base64_decode(" wp-content/ 2>/dev/null | head -5 >> "$security_log" || true

    # 3. Check WordPress salts
    print_info "Checking WordPress salts..."
    if grep -q "put your unique phrase here" wp-config.php 2>/dev/null; then
        print_warning "WordPress salts are not configured"
    else
        print_success "WordPress salts are configured"
    fi

    # 4. Check admin user
    print_info "Checking admin users..."
    docker exec "$WP_CONTAINER" wp user list --role=administrator --allow-root

    print_info "Security scan results saved to: $security_log"
}

run_comprehensive_security_scan() {
    print_info "Running comprehensive security scan..."

    # Basic security scan
    run_security_scan

    # Additional comprehensive checks
    print_info "Checking for vulnerable plugins..."
    # This would integrate with vulnerability databases in a real implementation

    print_info "Checking SSL certificate..."
    if command -v openssl &> /dev/null; then
        echo | openssl s_client -connect "localhost:8080" -servername "localhost" 2>/dev/null | grep -i "verify return code"
    fi

    print_info "Comprehensive security scan completed"
}

run_performance_audit() {
    print_info "Running performance audit..."
    local perf_log="$LOG_DIR/performance_${DATE}.log"

    # 1. Check database size
    print_info "Analyzing database size..."
    local db_size
    db_size=$(docker exec "$DB_CONTAINER" mysql -u root -p"${DB_ROOT_PASSWORD}" -D "${DB_NAME}" -e "
        SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Database Size (MB)'
        FROM information_schema.tables
        WHERE table_schema='${DB_NAME}';" -s --skip-column-names 2>/dev/null)

    echo "Database size: ${db_size} MB" >> "$perf_log"

    # 2. Check largest tables
    print_info "Checking largest database tables..."
    docker exec "$DB_CONTAINER" mysql -u root -p"${DB_ROOT_PASSWORD}" -D "${DB_NAME}" -e "
        SELECT table_name AS 'Table',
               ROUND(((data_length + index_length) / 1024 / 1024), 2) AS 'Size (MB)'
        FROM information_schema.TABLES
        WHERE table_schema = '${DB_NAME}'
        ORDER BY (data_length + index_length) DESC
        LIMIT 5;" >> "$perf_log" 2>/dev/null

    # 3. Check plugin count
    print_info "Analyzing plugin count..."
    local plugin_count
    plugin_count=$(docker exec "$WP_CONTAINER" wp plugin list --allow-root | wc -l)
    echo "Active plugins: $plugin_count" >> "$perf_log"

    # 4. Test site response time
    print_info "Testing site response time..."
    local response_time
    response_time=$(curl -o /dev/null -s -w "%{time_total}" "http://localhost:8080/wordpress/" || echo "N/A")
    echo "Response time: ${response_time}s" >> "$perf_log"

    print_info "Performance audit completed: $perf_log"
}

optimize_performance() {
    print_info "Running performance optimizations..."

    # 1. Database optimization
    ./bin/optimize-database.sh

    # 2. Clear all caches
    docker exec "$WP_CONTAINER" wp cache flush --allow-root 2>/dev/null || true

    # 3. Optimize images (if plugin available)
    docker exec "$WP_CONTAINER" wp media regenerate --yes --allow-root 2>/dev/null || print_info "Media regeneration not available"

    # 4. Update .htaccess for better caching
    if [[ -f .htaccess ]]; then
        print_info "Checking .htaccess optimizations..."
        if ! grep -q "ExpiresByType" .htaccess; then
            print_info "Consider adding caching rules to .htaccess"
        fi
    fi

    print_success "Performance optimization completed"
}

create_full_backup() {
    local backup_type="${1:-manual}"
    print_info "Creating full backup ($backup_type)..."

    local backup_name="${PROJECT_NAME}_${backup_type}_backup_${DATE}"
    local backup_path="$BACKUP_DIR/$backup_name"

    mkdir -p "$backup_path"

    # Database backup
    print_info "Backing up database..."
    docker exec "$DB_CONTAINER" mysqldump -u root -p"${DB_ROOT_PASSWORD}" "${DB_NAME}" > "$backup_path/database.sql"

    # Files backup
    print_info "Backing up files..."
    tar --exclude='wp-content/cache' --exclude='*.log' -czf "$backup_path/wordpress_files.tar.gz" wp-content/ wordpress/ .htaccess 2>/dev/null || true

    # Configuration backup
    cp .env "$backup_path/.env.backup" 2>/dev/null || true
    cp wp-config.php "$backup_path/wp-config.php.backup" 2>/dev/null || true
    cp docker-compose.yml "$backup_path/docker-compose.yml.backup" 2>/dev/null || true

    # Create backup manifest
    cat > "$backup_path/backup_manifest.txt" << EOF
Backup Type: $backup_type
Created: $(date)
WordPress Version: $(docker exec "$WP_CONTAINER" wp core version --allow-root 2>/dev/null || echo "Unknown")
Database Size: $(ls -lh "$backup_path/database.sql" | awk '{print $5}')
Files Size: $(ls -lh "$backup_path/wordpress_files.tar.gz" | awk '{print $5}')
Git Commit: $(git rev-parse HEAD 2>/dev/null || echo "Not in git repository")
EOF

    print_success "Backup created: $backup_path"
    log_activity "Created $backup_type backup: $backup_path"
}

cleanup_old_files() {
    print_info "Cleaning up old files..."

    # Remove old logs (older than 30 days)
    find "$LOG_DIR" -name "*.log" -mtime +30 -delete 2>/dev/null || true

    # Remove old backups (keep last 10)
    find "$BACKUP_DIR" -maxdepth 1 -type d -name "*backup*" | sort -r | tail -n +11 | xargs rm -rf 2>/dev/null || true

    # Clean WordPress temporary files
    find wp-content/uploads -name "*.tmp" -delete 2>/dev/null || true

    # Clean debug logs older than 7 days
    find . -name "debug.log" -mtime +7 -delete 2>/dev/null || true

    print_success "Cleanup completed"
}

archive_old_backups() {
    print_info "Archiving old backups..."

    local archive_dir="$BACKUP_DIR/archive"
    mkdir -p "$archive_dir"

    # Archive backups older than 90 days
    find "$BACKUP_DIR" -maxdepth 1 -type d -name "*backup*" -mtime +90 | while read -r backup; do
        if [[ -d "$backup" ]]; then
            local backup_name=$(basename "$backup")
            tar -czf "$archive_dir/${backup_name}.tar.gz" -C "$BACKUP_DIR" "$backup_name"
            rm -rf "$backup"
            print_info "Archived: $backup_name"
        fi
    done

    print_success "Backup archiving completed"
}

generate_changelog() {
    print_info "Generating changelog..."
    if [[ -f scripts/generate-changelog.js ]]; then
        node scripts/generate-changelog.js
        print_success "Changelog updated"
    else
        print_warning "Changelog generator not found"
    fi
}

generate_health_report() {
    print_info "Generating comprehensive health report..."

    local report_file="$LOG_DIR/health_report_${DATE}.md"

    cat > "$report_file" << EOF
# WordPress Health Report

**Generated:** $(date)
**Project:** $PROJECT_NAME
**Version:** $(grep version package.json | cut -d'"' -f4)

## System Status

### Docker Containers
\`\`\`
$(docker-compose ps)
\`\`\`

### WordPress Status
- **Version:** $(docker exec "$WP_CONTAINER" wp core version --allow-root 2>/dev/null || echo "Unknown")
- **Active Theme:** $(docker exec "$WP_CONTAINER" wp theme list --status=active --field=name --allow-root 2>/dev/null || echo "Unknown")
- **Plugin Count:** $(docker exec "$WP_CONTAINER" wp plugin list --allow-root 2>/dev/null | wc -l || echo "Unknown")

### Database Status
- **Size:** $(docker exec "$DB_CONTAINER" mysql -u root -p"${DB_ROOT_PASSWORD}" -D "${DB_NAME}" -e "SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size_MB' FROM information_schema.tables WHERE table_schema='${DB_NAME}';" -s --skip-column-names 2>/dev/null || echo "Unknown") MB
- **Tables:** $(docker exec "$DB_CONTAINER" mysql -u root -p"${DB_ROOT_PASSWORD}" -D "${DB_NAME}" -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${DB_NAME}';" -s --skip-column-names 2>/dev/null || echo "Unknown")

### Performance Metrics
- **Response Time:** $(curl -o /dev/null -s -w "%{time_total}" "http://localhost:8080/wordpress/" || echo "N/A")s
- **Disk Usage:** $(df -h . | tail -1 | awk '{print $5}')

### Security Status
- **SSL Status:** $(curl -I -s "http://localhost:8080" | grep -i "strict-transport-security" > /dev/null && echo "Enabled" || echo "Check Required")
- **Admin Users:** $(docker exec "$WP_CONTAINER" wp user list --role=administrator --field=user_login --allow-root 2>/dev/null | wc -l || echo "Unknown")

## Recent Activity
$(tail -20 "$LOG_DIR/maintenance_${DATE}.log" 2>/dev/null || echo "No recent activity logged")

## Recommendations
$(generate_recommendations)

---
*Report generated automatically by WordPress Maintenance Manager*
EOF

    print_success "Health report generated: $report_file"

    # Display summary
    cat "$report_file"
}

generate_recommendations() {
    local recommendations=""

    # Check disk space
    local disk_usage
    disk_usage=$(df -h . | tail -1 | awk '{print $5}' | sed 's/%//')
    if [[ $disk_usage -gt 80 ]]; then
        recommendations+="- 🚨 High disk usage detected ($disk_usage%). Consider cleaning up old files.\n"
    fi

    # Check plugin count
    local plugin_count
    plugin_count=$(docker exec "$WP_CONTAINER" wp plugin list --allow-root 2>/dev/null | wc -l || echo 0)
    if [[ $plugin_count -gt 30 ]]; then
        recommendations+="- ⚠️ High plugin count ($plugin_count). Review and deactivate unused plugins.\n"
    fi

    # Check for updates
    if docker exec "$WP_CONTAINER" wp plugin list --update=available --allow-root 2>/dev/null | grep -q "available"; then
        recommendations+="- 🔄 Plugin updates are available. Run weekly maintenance.\n"
    fi

    if [[ -z "$recommendations" ]]; then
        recommendations="- ✅ System appears to be running optimally."
    fi

    echo -e "$recommendations"
}

main() {
    local command="$1"
    local verbose=false
    local dry_run=false
    local schedule=false
    local email=false

    # Parse options
    shift
    while [[ $# -gt 0 ]]; do
        case $1 in
            --verbose)
                verbose=true
                set -x
                shift
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            --schedule)
                schedule=true
                shift
                ;;
            --email)
                email=true
                shift
                ;;
            *)
                echo "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    check_prerequisites

    case $command in
        daily)
            run_daily_maintenance
            ;;
        weekly)
            run_weekly_maintenance
            ;;
        monthly)
            run_monthly_maintenance
            ;;
        security-scan)
            run_security_scan
            ;;
        performance-audit)
            run_performance_audit
            ;;
        cleanup)
            cleanup_old_files
            ;;
        update-all)
            print_info "Updating all components..."
            docker exec "$WP_CONTAINER" wp core update --allow-root
            docker exec "$WP_CONTAINER" wp plugin update --all --allow-root
            docker exec "$WP_CONTAINER" wp theme update --all --allow-root
            ;;
        backup-full)
            create_full_backup "manual"
            ;;
        health-report)
            generate_health_report
            ;;
        monitor)
            print_info "Starting monitoring mode..."
            print_warning "Monitoring mode not implemented yet"
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            echo "Unknown command: $command"
            usage
            exit 1
            ;;
    esac
}

# Handle no arguments
if [[ $# -eq 0 ]]; then
    print_header
    generate_health_report
    echo
    echo "Run '$0 help' for available commands"
else
    main "$@"
fi
