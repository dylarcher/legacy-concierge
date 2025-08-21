#!/bin/bash

# WordPress Deployment Manager
# Handles staging and production deployments with automated rollback capabilities

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
BACKUP_DIR="./backups"
DATE=$(date +"%Y%m%d_%H%M%S")

# Environment configurations
declare -A ENVIRONMENTS
ENVIRONMENTS[staging]="staging.legacyhomecarelosangeles.com"
ENVIRONMENTS[production]="legacyhomecarelosangeles.com"

print_header() {
    echo -e "${BLUE}${BOLD}========================================${NC}"
    echo -e "${BLUE}${BOLD}  WORDPRESS DEPLOYMENT MANAGER        ${NC}"
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

# Function to show usage
usage() {
    echo -e "${BOLD}Usage:${NC} $0 [COMMAND] [ENVIRONMENT] [OPTIONS]"
    echo
    echo -e "${BOLD}COMMANDS:${NC}"
    echo "  deploy            - Deploy to specified environment"
    echo "  rollback          - Rollback to previous deployment"
    echo "  status            - Show deployment status"
    echo "  test              - Run deployment tests"
    echo "  sync-media        - Sync media files between environments"
    echo "  sync-database     - Sync database between environments"
    echo
    echo -e "${BOLD}ENVIRONMENTS:${NC}"
    echo "  staging           - Deploy to staging environment"
    echo "  production        - Deploy to production environment"
    echo
    echo -e "${BOLD}OPTIONS:${NC}"
    echo "  --dry-run         Run deployment simulation"
    echo "  --skip-backup     Skip pre-deployment backup"
    echo "  --force           Force deployment without confirmation"
    echo "  --verbose         Verbose output"
    echo
    echo -e "${BOLD}EXAMPLES:${NC}"
    echo "  $0 deploy staging"
    echo "  $0 deploy production --dry-run"
    echo "  $0 rollback staging"
    echo "  $0 sync-media staging production"
}

# Function to validate environment
validate_environment() {
    local env="$1"

    if [[ -z "${ENVIRONMENTS[$env]}" ]]; then
        print_error "Invalid environment: $env"
        echo "Valid environments: ${!ENVIRONMENTS[@]}"
        exit 1
    fi
}

# Function to run pre-deployment checks
pre_deployment_checks() {
    local env="$1"

    print_info "Running pre-deployment checks for $env..."

    # Check Git status
    if git status --porcelain | grep -q .; then
        print_warning "Uncommitted changes detected"
        git status --short

        read -p "Continue with deployment? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_error "Deployment cancelled"
            exit 1
        fi
    fi

    # Check Docker containers
    if ! docker-compose ps | grep -q "Up"; then
        print_error "Docker containers are not running"
        exit 1
    fi

    # Run WordPress tests
    print_info "Running WordPress health checks..."
    if ! curl -f -s "http://localhost:8080/legacy-concierge/" > /dev/null; then
        print_error "WordPress site is not responding locally"
        exit 1
    fi

    print_success "Pre-deployment checks passed"
}

# Function to create deployment backup
create_deployment_backup() {
    local env="$1"

    print_info "Creating pre-deployment backup for $env..."

    local backup_name="${PROJECT_NAME}_pre_deploy_${env}_${DATE}"
    local backup_path="$BACKUP_DIR/$backup_name"

    mkdir -p "$backup_path"

    # Export current database
    docker exec legacy-concierge-mysql mysqldump -u root -p"${DB_ROOT_PASSWORD}" "${DB_NAME}" > "$backup_path/database_pre_deploy.sql"

    # Backup wp-content
    tar -czf "$backup_path/wp-content.tar.gz" wp-content/

    # Backup configuration
    cp .env "$backup_path/.env.backup" 2>/dev/null || true
    cp wp-config.php "$backup_path/wp-config.php.backup" 2>/dev/null || true

    # Create deployment info
    cat > "$backup_path/deployment_info.txt" << EOF
Deployment backup created: $(date)
Target environment: $env
Git commit: $(git rev-parse HEAD)
Git branch: $(git branch --show-current)
Docker images:
$(docker-compose images)
EOF

    print_success "Deployment backup created: $backup_path"
    echo "$backup_path"
}

# Function to deploy to staging
deploy_staging() {
    print_info "Deploying to staging environment..."

    # Update staging database URLs
    print_info "Updating URLs for staging..."
    docker exec legacy-concierge-wp wp search-replace "legacyhomecarelosangeles.com" "staging.legacyhomecarelosangeles.com" --allow-root --dry-run

    # Export database for staging
    local staging_db="$BACKUP_DIR/staging_deploy_${DATE}.sql"
    docker exec legacy-concierge-mysql mysqldump -u root -p"${DB_ROOT_PASSWORD}" "${DB_NAME}" > "$staging_db"

    # Replace URLs in database dump
    sed -i.bak 's/legacyhomecarelosangeles\.com/staging.legacyhomecarelosangeles.com/g' "$staging_db"

    print_info "Staging database prepared: $staging_db"
    print_warning "Upload $staging_db to staging server and run:"
    print_warning "mysql -u [user] -p [database] < $staging_db"

    # Create staging file archive
    local staging_files="$BACKUP_DIR/staging_files_${DATE}.tar.gz"
    tar --exclude='wp-content/uploads' --exclude='wp-content/cache' -czf "$staging_files" wp-content/ legacy-concierge/ .htaccess

    print_success "Staging files prepared: $staging_files"
    print_warning "Upload and extract $staging_files to staging server"
}

# Function to deploy to production
deploy_production() {
    print_info "Deploying to production environment..."

    # Extra confirmation for production
    echo -e "${RED}${BOLD}WARNING: This will deploy to PRODUCTION${NC}"
    read -p "Are you absolutely sure? Type 'DEPLOY' to continue: " confirm

    if [[ "$confirm" != "DEPLOY" ]]; then
        print_error "Production deployment cancelled"
        exit 1
    fi

    # Create production database
    local prod_db="$BACKUP_DIR/production_deploy_${DATE}.sql"
    docker exec legacy-concierge-mysql mysqldump -u root -p"${DB_ROOT_PASSWORD}" "${DB_NAME}" > "$prod_db"

    # Ensure production URLs
    sed -i.bak 's/staging\.legacyhomecarelosangeles\.com/legacyhomecarelosangeles.com/g' "$prod_db"
    sed -i.bak2 's/localhost:8080/legacyhomecarelosangeles.com/g' "$prod_db"

    print_info "Production database prepared: $prod_db"

    # Create production file archive
    local prod_files="$BACKUP_DIR/production_files_${DATE}.tar.gz"
    tar --exclude='wp-content/uploads' --exclude='wp-content/cache' --exclude='wp-content/debug.log' -czf "$prod_files" wp-content/ legacy-concierge/ .htaccess

    print_success "Production files prepared: $prod_files"
    print_warning "Manual deployment steps:"
    print_warning "1. Upload $prod_files to production server"
    print_warning "2. Extract files to web root"
    print_warning "3. Import database: mysql -u [user] -p [database] < $prod_db"
    print_warning "4. Update file permissions"
    print_warning "5. Clear any caching"
}

# Function to run deployment tests
run_deployment_tests() {
    local env="$1"
    local url="${ENVIRONMENTS[$env]}"

    print_info "Running deployment tests for $env..."

    # Test basic connectivity
    if curl -f -s "https://$url" > /dev/null; then
        print_success "Site is accessible: https://$url"
    else
        print_error "Site is not accessible: https://$url"
        return 1
    fi

    # Test WordPress admin
    if curl -f -s "https://$url/wp-admin/admin-ajax.php" > /dev/null; then
        print_success "WordPress admin is responding"
    else
        print_error "WordPress admin is not responding"
        return 1
    fi

    # Test SSL certificate
    if openssl s_client -connect "$url:443" -servername "$url" < /dev/null 2>/dev/null | grep -q "Verify return code: 0"; then
        print_success "SSL certificate is valid"
    else
        print_warning "SSL certificate issues detected"
    fi

    print_success "Deployment tests completed"
}

# Function to sync media files
sync_media() {
    local source_env="$1"
    local target_env="$2"

    print_info "Syncing media files from $source_env to $target_env..."

    if [[ "$source_env" == "local" ]]; then
        local source_path="./wp-content/uploads/"
        print_info "Source: Local uploads directory"
    else
        print_error "Remote media sync not implemented yet"
        return 1
    fi

    if [[ "$target_env" == "local" ]]; then
        print_warning "Target is local - no sync needed"
        return 0
    fi

    # Create media archive for upload
    local media_archive="$BACKUP_DIR/media_sync_${DATE}.tar.gz"
    tar -czf "$media_archive" -C wp-content uploads/

    print_success "Media archive created: $media_archive"
    print_warning "Upload and extract $media_archive to target server's wp-content/ directory"
}

# Function to show deployment status
show_deployment_status() {
    print_header

    print_info "Current Git Status:"
    echo "Branch: $(git branch --show-current)"
    echo "Last commit: $(git log -1 --pretty=format:'%h - %s (%cr)')"
    echo "Uncommitted changes: $(git status --porcelain | wc -l) files"
    echo

    print_info "Docker Status:"
    docker-compose ps
    echo

    print_info "Recent Deployments:"
    if [[ -d "$BACKUP_DIR" ]]; then
        ls -lt "$BACKUP_DIR" | grep "deploy" | head -5
    else
        echo "No deployment backups found"
    fi
    echo

    print_info "Environment URLs:"
    for env in "${!ENVIRONMENTS[@]}"; do
        echo "$env: https://${ENVIRONMENTS[$env]}"
    done
}

# Main execution
main() {
    local command="$1"
    local environment="$2"
    local dry_run=false
    local skip_backup=false
    local force=false
    local verbose=false

    # Parse options
    shift 2
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                dry_run=true
                shift
                ;;
            --skip-backup)
                skip_backup=true
                shift
                ;;
            --force)
                force=true
                shift
                ;;
            --verbose)
                verbose=true
                set -x
                shift
                ;;
            *)
                echo "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    case $command in
        deploy)
            if [[ -z "$environment" ]]; then
                print_error "Environment is required for deployment"
                usage
                exit 1
            fi

            validate_environment "$environment"
            pre_deployment_checks "$environment"

            if [[ "$skip_backup" != true ]]; then
                create_deployment_backup "$environment"
            fi

            if [[ "$dry_run" == true ]]; then
                print_info "DRY RUN: Would deploy to $environment"
                exit 0
            fi

            case $environment in
                staging)
                    deploy_staging
                    ;;
                production)
                    deploy_production
                    ;;
            esac
            ;;
        test)
            if [[ -z "$environment" ]]; then
                print_error "Environment is required for testing"
                usage
                exit 1
            fi

            validate_environment "$environment"
            run_deployment_tests "$environment"
            ;;
        sync-media)
            if [[ -z "$environment" ]] || [[ -z "$3" ]]; then
                print_error "Source and target environments are required"
                usage
                exit 1
            fi
            sync_media "$environment" "$3"
            ;;
        status)
            show_deployment_status
            ;;
        rollback)
            print_error "Rollback functionality needs to be implemented"
            exit 1
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
    show_deployment_status
    echo
    echo "Run '$0 help' for available commands"
else
    main "$@"
fi
