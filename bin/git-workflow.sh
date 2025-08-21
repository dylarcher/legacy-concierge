#!/bin/bash

# WordPress Git Workflow Management Script
# Based on "A Comprehensive Guide to Modernizing WordPress Development with Git and Automated Deployment"
# Handles commit workflow, publishing, theme updates, and plugin management

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
COMPOSE_PROJECT="${PROJECT_NAME}-wp"
WP_CONTAINER="${COMPOSE_PROJECT}-wp"
DB_CONTAINER="${COMPOSE_PROJECT}-mysql"
BACKUP_DIR="./backups"
DATE=$(date +"%Y%m%d_%H%M%S")

# Ensure we're in the right directory
if [[ ! -f "docker-compose.yml" ]]; then
    echo -e "${RED}Error: Must be run from project root directory${NC}"
    exit 1
fi

# Load environment variables
if [[ -f .env ]]; then
    source .env
fi

print_header() {
    echo -e "${BLUE}${BOLD}========================================${NC}"
    echo -e "${BLUE}${BOLD}  WORDPRESS GIT WORKFLOW MANAGER      ${NC}"
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
    echo -e "${BOLD}Usage:${NC} $0 [COMMAND] [OPTIONS]"
    echo
    echo -e "${BOLD}COMMANDS:${NC}"
    echo "  checkin           - Commit current changes with automated message"
    echo "  publish           - Deploy changes to staging/production"
    echo "  theme-update      - Update active WordPress theme"
    echo "  plugin-sync       - Synchronize plugins with composer.json"
    echo "  backup            - Create full backup (database + files)"
    echo "  restore           - Restore from backup"
    echo "  status            - Show Git and deployment status"
    echo "  init              - Initialize Git workflow for existing project"
    echo
    echo -e "${BOLD}OPTIONS:${NC}"
    echo "  -m, --message     Custom commit message"
    echo "  -e, --env         Target environment (staging|production)"
    echo "  -f, --force       Force operation (use with caution)"
    echo "  -v, --verbose     Verbose output"
    echo
    echo -e "${BOLD}EXAMPLES:${NC}"
    echo "  $0 checkin -m 'Updated homepage layout'"
    echo "  $0 publish -e staging"
    echo "  $0 theme-update"
    echo "  $0 plugin-sync"
}

# Function to check prerequisites
check_prerequisites() {
    local errors=0

    # Check Git
    if ! command -v git &> /dev/null; then
        print_error "Git is not installed"
        ((errors++))
    fi

    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        ((errors++))
    fi

    # Check if in Git repository
    if [[ ! -d .git ]]; then
        print_warning "Not in a Git repository. Run 'git init' or '$0 init'"
        ((errors++))
    fi

    # Check Docker containers
    if ! docker-compose ps | grep -q "Up"; then
        print_warning "Docker containers are not running. Starting them..."
        docker-compose up -d
        sleep 10
    fi

    return $errors
}

# Function to generate automatic commit message
generate_commit_message() {
    local changes=$(git status --porcelain)
    local message="Auto-commit: "
    local wp_files=0
    local theme_files=0
    local plugin_files=0
    local config_files=0
    local other_files=0

    while IFS= read -r line; do
        if [[ $line == *"wp-content/themes"* ]]; then
            ((theme_files++))
        elif [[ $line == *"wp-content/plugins"* ]]; then
            ((plugin_files++))
        elif [[ $line == *"wp-config"* ]] || [[ $line == *".env"* ]] || [[ $line == *"composer"* ]]; then
            ((config_files++))
        elif [[ $line == *".php"* ]] || [[ $line == *".js"* ]] || [[ $line == *".css"* ]]; then
            ((wp_files++))
        else
            ((other_files++))
        fi
    done <<< "$changes"

    local parts=()
    [[ $theme_files -gt 0 ]] && parts+=("${theme_files} theme file(s)")
    [[ $plugin_files -gt 0 ]] && parts+=("${plugin_files} plugin file(s)")
    [[ $config_files -gt 0 ]] && parts+=("${config_files} config file(s)")
    [[ $wp_files -gt 0 ]] && parts+=("${wp_files} WordPress file(s)")
    [[ $other_files -gt 0 ]] && parts+=("${other_files} other file(s)")

    if [[ ${#parts[@]} -gt 0 ]]; then
        message+=$(IFS=", "; echo "${parts[*]}")
    else
        message+="various changes"
    fi

    echo "$message"
}

# Function to handle Git workflow and commit process
git_checkin() {
    local custom_message="$1"

    print_info "Starting Git check-in process..."

    # Check for uncommitted changes
    if git diff-index --quiet HEAD --; then
        print_warning "No changes to commit"
        return 0
    fi

    # Show current status
    print_info "Current Git status:"
    git status --short
    echo

    # Add all changes
    print_info "Adding changes to staging area..."
    git add .

    # Generate or use custom message
    local commit_message
    if [[ -n "$custom_message" ]]; then
        commit_message="$custom_message"
    else
        commit_message=$(generate_commit_message)
    fi

    print_info "Commit message: $commit_message"

    # Commit changes
    git commit -m "$commit_message"
    print_success "Changes committed successfully"

    # Push to remote if it exists
    if git remote | grep -q origin; then
        print_info "Pushing to remote repository..."
        git push origin $(git branch --show-current)
        print_success "Changes pushed to remote repository"
    else
        print_warning "No remote repository configured"
    fi
}

# Function to update WordPress theme
update_theme() {
    print_info "Starting theme update process..."

    # Check if WordPress is running
    if ! docker ps | grep -q "$WP_CONTAINER"; then
        print_error "WordPress container is not running"
        return 1
    fi

    # Get current theme
    local current_theme=$(docker exec "$WP_CONTAINER" wp theme list --status=active --field=name --allow-root 2>/dev/null || echo "")

    if [[ -z "$current_theme" ]]; then
        print_error "Could not detect active theme"
        return 1
    fi

    print_info "Active theme: $current_theme"

    # Update theme via WP-CLI if available
    if docker exec "$WP_CONTAINER" which wp &>/dev/null; then
        print_info "Updating theme via WP-CLI..."
        docker exec "$WP_CONTAINER" wp theme update "$current_theme" --allow-root || print_warning "Theme update via WP-CLI failed"
    fi

    # Update theme assets if they exist
    local theme_path="wp-content/themes/$current_theme"
    if [[ -d "$theme_path" ]]; then
        print_info "Processing theme assets..."

        # Check for package.json in theme directory
        if [[ -f "$theme_path/package.json" ]]; then
            print_info "Found Node.js dependencies in theme..."
            (cd "$theme_path" && npm install --production 2>/dev/null) || print_warning "npm install failed"
        fi

        # Check for composer.json in theme directory
        if [[ -f "$theme_path/composer.json" ]]; then
            print_info "Found PHP dependencies in theme..."
            (cd "$theme_path" && composer install --no-dev 2>/dev/null) || print_warning "composer install failed"
        fi

        print_success "Theme update completed"
    else
        print_warning "Theme directory not found locally"
    fi
}

# Function to synchronize plugins
sync_plugins() {
    print_info "Starting plugin synchronization..."

    # Update composer dependencies
    if [[ -f composer.json ]]; then
        print_info "Updating Composer dependencies..."
        composer update --no-dev --optimize-autoloader
        print_success "Composer dependencies updated"
    fi

    # Activate plugins via WP-CLI if available
    if docker exec "$WP_CONTAINER" which wp &>/dev/null; then
        print_info "Activating plugins via WP-CLI..."

        # Get list of installed plugins from composer
        local composer_plugins=$(composer show | grep "wpackagist-plugin" | cut -d'/' -f2 | cut -d' ' -f1)

        while IFS= read -r plugin; do
            if [[ -n "$plugin" ]]; then
                print_info "Activating plugin: $plugin"
                docker exec "$WP_CONTAINER" wp plugin activate "$plugin" --allow-root 2>/dev/null || print_warning "Failed to activate $plugin"
            fi
        done <<< "$composer_plugins"

        print_success "Plugin synchronization completed"
    else
        print_warning "WP-CLI not available in container"
    fi
}

# Function to create backup
create_backup() {
    print_info "Creating backup..."

    # Create backup directory
    mkdir -p "$BACKUP_DIR"

    local backup_name="${PROJECT_NAME}_backup_${DATE}"
    local backup_path="$BACKUP_DIR/$backup_name"

    mkdir -p "$backup_path"

    # Backup database
    print_info "Backing up database..."
    if [[ -n "$DB_ROOT_PASSWORD" ]]; then
        docker exec "$DB_CONTAINER" mysqldump -u root -p"$DB_ROOT_PASSWORD" "$DB_NAME" > "$backup_path/database.sql"
    else
        docker exec "$DB_CONTAINER" mysqldump -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" > "$backup_path/database.sql"
    fi

    # Backup wp-content
    print_info "Backing up wp-content..."
    tar -czf "$backup_path/wp-content.tar.gz" wp-content/

    # Backup configuration files
    print_info "Backing up configuration..."
    cp .env "$backup_path/.env.backup" 2>/dev/null || true
    cp wp-config.php "$backup_path/wp-config.php.backup" 2>/dev/null || true
    cp composer.json "$backup_path/composer.json.backup" 2>/dev/null || true
    cp docker-compose.yml "$backup_path/docker-compose.yml.backup" 2>/dev/null || true

    # Create backup info file
    cat > "$backup_path/backup_info.txt" << EOF
Backup created: $(date)
Git commit: $(git rev-parse HEAD 2>/dev/null || echo "Not in git repository")
Git branch: $(git branch --show-current 2>/dev/null || echo "Not in git repository")
Docker images:
$(docker-compose images)
EOF

    print_success "Backup created: $backup_path"
    echo -e "${CYAN}Backup contents:${NC}"
    ls -la "$backup_path"
}

# Function to show status
show_status() {
    print_header

    print_info "Git Repository Status:"
    if [[ -d .git ]]; then
        echo "Branch: $(git branch --show-current)"
        echo "Last commit: $(git log -1 --pretty=format:'%h - %s (%cr)' 2>/dev/null || echo 'No commits')"
        echo "Uncommitted changes:"
        git status --short | head -10
        if [[ $(git status --porcelain | wc -l) -gt 10 ]]; then
            echo "... and $(($(git status --porcelain | wc -l) - 10)) more files"
        fi
    else
        echo "Not a Git repository"
    fi
    echo

    print_info "Docker Container Status:"
    docker-compose ps
    echo

    print_info "WordPress Status:"
    if docker exec "$WP_CONTAINER" which wp &>/dev/null; then
        echo "WordPress Version: $(docker exec "$WP_CONTAINER" wp core version --allow-root 2>/dev/null || echo 'Unknown')"
        echo "Active Theme: $(docker exec "$WP_CONTAINER" wp theme list --status=active --field=name --allow-root 2>/dev/null || echo 'Unknown')"
        echo "Plugin Count: $(docker exec "$WP_CONTAINER" wp plugin list --field=name --allow-root 2>/dev/null | wc -l || echo 'Unknown')"
    else
        echo "WP-CLI not available"
    fi
    echo

    print_info "Recent Backups:"
    if [[ -d "$BACKUP_DIR" ]]; then
        ls -lt "$BACKUP_DIR" | head -5
    else
        echo "No backups found"
    fi
}

# Function to initialize Git workflow
init_workflow() {
    print_info "Initializing Git workflow..."

    # Initialize Git if not already done
    if [[ ! -d .git ]]; then
        git init
        print_success "Git repository initialized"
    fi

    # Create or update .gitignore
    cat > .gitignore << 'EOF'
# WordPress Core
/legacy-concierge/
wp-config-sample.php
wp-config.php
.htaccess

# Environment and Security
.env
.env.*
*.log

# Dependencies
/vendor/
/node_modules/
composer.lock
package-lock.json

# Uploads and Cache
wp-content/uploads/
wp-content/cache/
wp-content/backup-db/

# Development
.vscode/
.idea/
*.tmp
*.swp
.DS_Store

# Docker
docker-compose.override.yml
EOF

    print_success "Created/updated .gitignore"

    # Create initial commit if no commits exist
    if ! git log --oneline -1 &>/dev/null; then
        git add .
        git commit -m "Initial commit: WordPress project setup"
        print_success "Created initial commit"
    fi

    print_info "Git workflow initialized successfully"
}

# Main execution
main() {
    local command="$1"
    local custom_message=""
    local environment="staging"
    local force=false
    local verbose=false

    # Parse arguments
    shift
    while [[ $# -gt 0 ]]; do
        case $1 in
            -m|--message)
                custom_message="$2"
                shift 2
                ;;
            -e|--env)
                environment="$2"
                shift 2
                ;;
            -f|--force)
                force=true
                shift
                ;;
            -v|--verbose)
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
        checkin)
            check_prerequisites
            git_checkin "$custom_message"
            ;;
        publish)
            check_prerequisites
            create_backup
            git_checkin "$custom_message"
            print_info "Publishing to $environment environment..."
            print_warning "Publishing functionality needs to be configured for your hosting environment"
            ;;
        theme-update)
            check_prerequisites
            update_theme
            ;;
        plugin-sync)
            check_prerequisites
            sync_plugins
            ;;
        backup)
            check_prerequisites
            create_backup
            ;;
        status)
            show_status
            ;;
        init)
            init_workflow
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
    show_status
    echo
    echo "Run '$0 help' for available commands"
else
    main "$@"
fi
