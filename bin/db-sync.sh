#!/bin/bash

# Database Synchronization Script for WordPress
# Based on the professional workflow outlined in the modernization guide
# Supports pulling production database to local and pushing local to staging

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_ROOT/.env"

# Load environment variables
if [[ -f "$ENV_FILE" ]]; then
    set -a  # Automatically export all variables
    source "$ENV_FILE"
    set +a
else
    echo -e "${RED}Error: .env file not found at $ENV_FILE${NC}"
    echo "Please ensure your .env file exists with the necessary configuration."
    exit 1
fi

# Default values (can be overridden in .env)
LOCAL_WP_PATH="${LOCAL_WP_PATH:-$PROJECT_ROOT/legacy-concierge}"
LOCAL_DB_NAME="${DB_NAME:-wordpress}"
LOCAL_DB_USER="${DB_USER:-root}"
LOCAL_DB_PASS="${DB_PASSWORD:-root}"
LOCAL_URL="${WP_HOME:-http://localhost:8080}"

# Remote configuration (must be set in .env)
REMOTE_HOST="${REMOTE_HOST:-}"
REMOTE_USER="${REMOTE_USER:-}"
REMOTE_PATH="${REMOTE_PATH:-}"
REMOTE_URL="${REMOTE_URL:-}"

# Function to display usage
usage() {
    echo -e "${BLUE}WordPress Database Synchronization Script${NC}"
    echo
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo
    echo "Commands:"
    echo "  pull         Pull production database to local environment"
    echo "  push-staging Push local database to staging environment"
    echo "  backup       Create local database backup"
    echo "  status       Show database status information"
    echo
    echo "Options:"
    echo "  --dry-run    Show what would be done without executing"
    echo "  --verbose    Show detailed output"
    echo "  --help       Show this help message"
    echo
    echo "Examples:"
    echo "  $0 pull                    # Pull production DB to local"
    echo "  $0 pull --dry-run          # Show what pull would do"
    echo "  $0 push-staging            # Push local DB to staging"
    echo "  $0 backup                  # Create local backup"
    echo
    echo "Environment Configuration:"
    echo "Required .env variables for remote operations:"
    echo "  REMOTE_HOST                # SSH hostname or IP"
    echo "  REMOTE_USER                # SSH username"
    echo "  REMOTE_PATH                # Path to WordPress on remote server"
    echo "  REMOTE_URL                 # Full URL of remote site"
    echo
    echo "Optional .env variables:"
    echo "  LOCAL_WP_PATH              # Path to local WordPress (default: ./legacy-concierge)"
    echo "  STAGING_HOST, STAGING_USER, etc.  # For staging push operations"
}

# Function to check prerequisites
check_prerequisites() {
    local missing_tools=()

    # Check for required tools
    command -v wp >/dev/null 2>&1 || missing_tools+=("wp-cli")
    command -v ssh >/dev/null 2>&1 || missing_tools+=("ssh")
    command -v scp >/dev/null 2>&1 || missing_tools+=("scp")
    command -v mysqldump >/dev/null 2>&1 || missing_tools+=("mysqldump")
    command -v mysql >/dev/null 2>&1 || missing_tools+=("mysql")

    if [[ ${#missing_tools[@]} -ne 0 ]]; then
        echo -e "${RED}Error: Missing required tools:${NC}"
        printf ' - %s\n' "${missing_tools[@]}"
        echo
        echo "Please install the missing tools:"
        echo " - WP-CLI: https://wp-cli.org/"
        echo " - SSH client (usually pre-installed)"
        echo " - MySQL client tools"
        exit 1
    fi
}

# Function to check if WordPress is accessible
check_wordpress() {
    local wp_path="$1"
    local context="${2:-local}"

    if [[ "$context" == "local" ]]; then
        if [[ ! -f "$wp_path/wp-config.php" ]]; then
            echo -e "${RED}Error: WordPress not found at $wp_path${NC}"
            echo "Please ensure your local WordPress installation exists."
            return 1
        fi

        # Test WP-CLI access
        if ! wp --path="$wp_path" core version >/dev/null 2>&1; then
            echo -e "${YELLOW}Warning: WP-CLI cannot access local WordPress${NC}"
            echo "Please check your WordPress installation and configuration."
            return 1
        fi
    fi

    return 0
}

# Function to create database backup
create_backup() {
    local backup_name="${1:-backup_$(date +%Y%m%d_%H%M%S).sql}"
    local backup_path="$PROJECT_ROOT/.backup"

    echo -e "${BLUE}Creating local database backup...${NC}"

    # Create backup directory
    mkdir -p "$backup_path"

    # Create backup using WP-CLI
    if wp --path="$LOCAL_WP_PATH" db export "$backup_path/$backup_name" 2>/dev/null; then
        echo -e "${GREEN}✓ Backup created: $backup_path/$backup_name${NC}"

        # Compress the backup
        if command -v gzip >/dev/null 2>&1; then
            gzip "$backup_path/$backup_name"
            echo -e "${GREEN}✓ Backup compressed: $backup_path/$backup_name.gz${NC}"
        fi
    else
        echo -e "${RED}✗ Failed to create database backup${NC}"
        return 1
    fi
}

# Function to pull database from remote
pull_database() {
    local dry_run="${1:-false}"
    local verbose="${2:-false}"

    echo -e "${BLUE}=== Pulling Database from Production ===${NC}"

    # Validate remote configuration
    if [[ -z "$REMOTE_HOST" || -z "$REMOTE_USER" || -z "$REMOTE_PATH" || -z "$REMOTE_URL" ]]; then
        echo -e "${RED}Error: Remote configuration incomplete${NC}"
        echo "Please set REMOTE_HOST, REMOTE_USER, REMOTE_PATH, and REMOTE_URL in your .env file"
        return 1
    fi

    # Create temporary filename
    local temp_file="temp_remote_db_$(date +%Y%m%d_%H%M%S).sql"
    local remote_temp_path="/tmp/$temp_file"
    local local_temp_path="/tmp/$temp_file"

    echo -e "${YELLOW}Remote: $REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH${NC}"
    echo -e "${YELLOW}Local:  $LOCAL_WP_PATH${NC}"

    if [[ "$dry_run" == "true" ]]; then
        echo -e "${PURPLE}[DRY RUN] Would execute the following steps:${NC}"
        echo "1. SSH to $REMOTE_HOST and export database using WP-CLI"
        echo "2. Download $remote_temp_path to $local_temp_path"
        echo "3. Create local backup before import"
        echo "4. Import remote database to local"
        echo "5. Run search-replace from '$REMOTE_URL' to '$LOCAL_URL'"
        echo "6. Cleanup temporary files"
        return 0
    fi

    # Step 1: Create backup of local database
    echo -e "${BLUE}Step 1: Creating backup of local database...${NC}"
    create_backup "pre_pull_backup_$(date +%Y%m%d_%H%M%S).sql" || {
        echo -e "${RED}Failed to create backup. Aborting pull operation.${NC}"
        return 1
    }

    # Step 2: Export remote database
    echo -e "${BLUE}Step 2: Exporting remote database...${NC}"
    ssh "$REMOTE_USER@$REMOTE_HOST" "wp --path='$REMOTE_PATH' db export '$remote_temp_path'" || {
        echo -e "${RED}Failed to export remote database${NC}"
        return 1
    }

    # Step 3: Download database dump
    echo -e "${BLUE}Step 3: Downloading database dump...${NC}"
    scp "$REMOTE_USER@$REMOTE_HOST:$remote_temp_path" "$local_temp_path" || {
        echo -e "${RED}Failed to download database dump${NC}"
        return 1
    }

    # Step 4: Import to local database
    echo -e "${BLUE}Step 4: Importing to local database...${NC}"
    wp --path="$LOCAL_WP_PATH" db import "$local_temp_path" || {
        echo -e "${RED}Failed to import database${NC}"
        return 1
    }

    # Step 5: Search and replace URLs
    echo -e "${BLUE}Step 5: Updating URLs from $REMOTE_URL to $LOCAL_URL...${NC}"
    wp --path="$LOCAL_WP_PATH" search-replace "$REMOTE_URL" "$LOCAL_URL" --all-tables || {
        echo -e "${RED}Failed to update URLs${NC}"
        return 1
    }

    # Step 6: Cleanup temporary files
    echo -e "${BLUE}Step 6: Cleaning up temporary files...${NC}"
    rm -f "$local_temp_path"
    ssh "$REMOTE_USER@$REMOTE_HOST" "rm -f '$remote_temp_path'"

    echo -e "${GREEN}✓ Database pull completed successfully!${NC}"
    echo -e "${PURPLE}Local site URL: $LOCAL_URL${NC}"
    echo
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Verify your local site is working: $LOCAL_URL"
    echo "2. Check that all plugins and themes are functioning correctly"
    echo "3. Update any hardcoded URLs or paths as needed"
}

# Function to push database to staging
push_staging() {
    local dry_run="${1:-false}"

    echo -e "${BLUE}=== Pushing Database to Staging ===${NC}"

    # Check for staging configuration
    local staging_host="${STAGING_HOST:-}"
    local staging_user="${STAGING_USER:-}"
    local staging_path="${STAGING_PATH:-}"
    local staging_url="${STAGING_URL:-}"

    if [[ -z "$staging_host" || -z "$staging_user" || -z "$staging_path" || -z "$staging_url" ]]; then
        echo -e "${RED}Error: Staging configuration incomplete${NC}"
        echo "Please set STAGING_HOST, STAGING_USER, STAGING_PATH, and STAGING_URL in your .env file"
        return 1
    fi

    if [[ "$dry_run" == "true" ]]; then
        echo -e "${PURPLE}[DRY RUN] Would push local database to staging:${NC}"
        echo "From: $LOCAL_URL"
        echo "To:   $staging_url ($staging_user@$staging_host:$staging_path)"
        return 0
    fi

    # Confirm before pushing
    echo -e "${YELLOW}⚠️  This will OVERWRITE the staging database!${NC}"
    echo "From: $LOCAL_URL"
    echo "To:   $staging_url"
    read -p "Are you sure you want to continue? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Push cancelled."
        return 0
    fi

    # Create temporary file
    local temp_file="temp_local_db_$(date +%Y%m%d_%H%M%S).sql"
    local local_temp_path="/tmp/$temp_file"
    local remote_temp_path="/tmp/$temp_file"

    # Export local database
    echo -e "${BLUE}Exporting local database...${NC}"
    wp --path="$LOCAL_WP_PATH" db export "$local_temp_path" || return 1

    # Update URLs for staging in the dump file
    echo -e "${BLUE}Updating URLs for staging environment...${NC}"
    sed -i.bak "s|$LOCAL_URL|$staging_url|g" "$local_temp_path"

    # Upload to staging server
    echo -e "${BLUE}Uploading database to staging server...${NC}"
    scp "$local_temp_path" "$staging_user@$staging_host:$remote_temp_path" || return 1

    # Import on staging server
    echo -e "${BLUE}Importing database on staging server...${NC}"
    ssh "$staging_user@$staging_host" "wp --path='$staging_path' db import '$remote_temp_path'" || return 1

    # Final search-replace on staging (to handle any missed cases)
    ssh "$staging_user@$staging_host" "wp --path='$staging_path' search-replace '$LOCAL_URL' '$staging_url' --all-tables" || true

    # Cleanup
    rm -f "$local_temp_path" "$local_temp_path.bak"
    ssh "$staging_user@$staging_host" "rm -f '$remote_temp_path'"

    echo -e "${GREEN}✓ Database pushed to staging successfully!${NC}"
    echo -e "${PURPLE}Staging site URL: $staging_url${NC}"
}

# Function to show database status
show_status() {
    echo -e "${BLUE}=== Database Status ===${NC}"
    echo

    # Local database info
    echo -e "${PURPLE}Local Environment:${NC}"
    echo "WordPress Path: $LOCAL_WP_PATH"
    echo "Database Name:  $LOCAL_DB_NAME"
    echo "Site URL:       $LOCAL_URL"

    if check_wordpress "$LOCAL_WP_PATH" "local" 2>/dev/null; then
        local wp_version=$(wp --path="$LOCAL_WP_PATH" core version 2>/dev/null)
        local db_size=$(wp --path="$LOCAL_WP_PATH" db size --human-readable 2>/dev/null)
        echo "WordPress Ver:  $wp_version"
        echo "Database Size:  $db_size"
        echo -e "${GREEN}Status: ✓ Available${NC}"
    else
        echo -e "${RED}Status: ✗ Not available${NC}"
    fi

    echo

    # Remote info (if configured)
    if [[ -n "$REMOTE_HOST" ]]; then
        echo -e "${PURPLE}Production Environment:${NC}"
        echo "Remote Host:    $REMOTE_HOST"
        echo "Remote User:    $REMOTE_USER"
        echo "Remote Path:    $REMOTE_PATH"
        echo "Remote URL:     $REMOTE_URL"

        # Test SSH connection
        if ssh -o ConnectTimeout=5 -o BatchMode=yes "$REMOTE_USER@$REMOTE_HOST" exit 2>/dev/null; then
            echo -e "${GREEN}SSH Status: ✓ Connected${NC}"
        else
            echo -e "${RED}SSH Status: ✗ Cannot connect${NC}"
        fi
    fi

    echo

    # Recent backups
    local backup_dir="$PROJECT_ROOT/.backup"
    if [[ -d "$backup_dir" ]]; then
        echo -e "${PURPLE}Recent Backups:${NC}"
        find "$backup_dir" -name "*.sql*" -type f -exec ls -lh {} \; 2>/dev/null | head -5 | while read -r line; do
            echo "  $line"
        done
    fi
}

# Main function
main() {
    local command="${1:-}"
    local dry_run=false
    local verbose=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                dry_run=true
                shift
                ;;
            --verbose)
                verbose=true
                shift
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            pull|push-staging|backup|status)
                if [[ -z "$command" ]]; then
                    command="$1"
                fi
                shift
                ;;
            *)
                if [[ -z "$command" ]]; then
                    command="$1"
                fi
                shift
                ;;
        esac
    done

    # Check prerequisites
    check_prerequisites

    # Execute command
    case "$command" in
        pull)
            check_wordpress "$LOCAL_WP_PATH" || exit 1
            pull_database "$dry_run" "$verbose"
            ;;
        push-staging)
            check_wordpress "$LOCAL_WP_PATH" || exit 1
            push_staging "$dry_run"
            ;;
        backup)
            check_wordpress "$LOCAL_WP_PATH" || exit 1
            create_backup
            ;;
        status)
            show_status
            ;;
        *)
            echo -e "${RED}Error: Unknown command '$command'${NC}"
            echo
            usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
