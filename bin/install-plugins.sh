#!/bin/bash

# WordPress Plugin Management Script
# Comprehensive plugin installation, activation, and management system

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
WP_CONTAINER="legacy-concierge-wp"
PLUGIN_BACKUP_DIR="./backups/plugins"
DATE=$(date +"%Y%m%d_%H%M%S")

print_header() {
    echo -e "${BLUE}${BOLD}========================================${NC}"
    echo -e "${BLUE}${BOLD}  WORDPRESS PLUGIN MANAGER            ${NC}"
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

# Plugin categories for better organization
declare -A PLUGIN_CATEGORIES

# Essential plugins
PLUGIN_CATEGORIES[essential]="
wpackagist-plugin/classic-editor
wpackagist-plugin/classic-widgets
wpackagist-plugin/contact-form-7
wpackagist-plugin/duplicate-post
wpackagist-plugin/custom-post-type-ui
wpackagist-plugin/advanced-custom-fields
"

# SEO and Marketing plugins
PLUGIN_CATEGORIES[seo]="
wpackagist-plugin/wordpress-seo
wpackagist-plugin/redirection
wpackagist-plugin/really-simple-ssl
wpackagist-plugin/google-site-kit
wpackagist-plugin/mailchimp-for-wp
"

# Performance plugins
PLUGIN_CATEGORIES[performance]="
wpackagist-plugin/litespeed-cache
wpackagist-plugin/wp-optimize
wpackagist-plugin/wp-super-cache
wpackagist-plugin/ewww-image-optimizer
wpackagist-plugin/autoptimize
"

# Security plugins
PLUGIN_CATEGORIES[security]="
wpackagist-plugin/wordfence
wpackagist-plugin/updraftplus
wpackagist-plugin/easy-hide-login
wpackagist-plugin/wp-security-audit-log
"

# E-commerce plugins
PLUGIN_CATEGORIES[ecommerce]="
wpackagist-plugin/woocommerce
wpackagist-plugin/woocommerce-gateway-stripe
wpackagist-plugin/woocommerce-pdf-invoices-packing-slips
"

# Development plugins
PLUGIN_CATEGORIES[development]="
wpackagist-plugin/query-monitor
wpackagist-plugin/debug-bar
wpackagist-plugin/wp-crontrol
wpackagist-plugin/regenerate-thumbnails
"

# Page builder plugins
PLUGIN_CATEGORIES[pagebuilders]="
wpackagist-plugin/elementor
wpackagist-plugin/jetpack
wpackagist-plugin/happy-elementor-addons
"

# Premium plugins that need manual installation
PREMIUM_PLUGINS="
all-in-one-wp-migration-unlimited-extension
bridge-core
elementor-pro
instagram-feed-pro
revslider
seedprod-coming-soon-pro-5
"

usage() {
    echo -e "${BOLD}Usage:${NC} $0 [COMMAND] [CATEGORY/PLUGIN] [OPTIONS]"
    echo
    echo -e "${BOLD}COMMANDS:${NC}"
    echo "  install           - Install plugins by category or individual plugin"
    echo "  activate          - Activate installed plugins"
    echo "  deactivate        - Deactivate plugins"
    echo "  update            - Update all plugins"
    echo "  list              - List installed plugins"
    echo "  search            - Search for plugins in repository"
    echo "  remove            - Remove plugins"
    echo "  backup            - Backup plugin configurations"
    echo "  restore           - Restore plugin configurations"
    echo "  status            - Show plugin status"
    echo
    echo -e "${BOLD}CATEGORIES:${NC}"
    echo "  essential         - Core WordPress functionality plugins"
    echo "  seo               - SEO and marketing plugins"
    echo "  performance       - Caching and optimization plugins"
    echo "  security          - Security and backup plugins"
    echo "  ecommerce         - WooCommerce and e-commerce plugins"
    echo "  development       - Development and debugging plugins"
    echo "  pagebuilders      - Page builders and design plugins"
    echo "  all               - All available plugins"
    echo
    echo -e "${BOLD}OPTIONS:${NC}"
    echo "  --dry-run         - Show what would be installed without installing"
    echo "  --force           - Force installation/activation"
    echo "  --skip-activation - Install but don't activate plugins"
    echo "  --verbose         - Show detailed output"
    echo
    echo -e "${BOLD}EXAMPLES:${NC}"
    echo "  $0 install essential"
    echo "  $0 install wpackagist-plugin/contact-form-7"
    echo "  $0 activate all"
    echo "  $0 update"
    echo "  $0 list active"
}

check_prerequisites() {
    # Check if Docker container is running
    if ! docker ps | grep -q "$WP_CONTAINER"; then
        print_error "WordPress container is not running"
        print_info "Start with: docker-compose up -d"
        exit 1
    fi

    # Check if WP-CLI is available
    if ! docker exec "$WP_CONTAINER" which wp >/dev/null 2>&1; then
        print_error "WP-CLI is not available in the WordPress container"
        exit 1
    fi

    # Check if composer.json exists
    if [[ ! -f composer.json ]]; then
        print_error "composer.json not found. Run from project root directory."
        exit 1
    fi
}

install_plugins_by_category() {
    local category="$1"
    local dry_run="$2"
    local skip_activation="$3"

    if [[ "$category" == "all" ]]; then
        print_info "Installing all plugin categories..."
        for cat in "${!PLUGIN_CATEGORIES[@]}"; do
            install_plugins_by_category "$cat" "$dry_run" "$skip_activation"
        done
        return
    fi

    if [[ -z "${PLUGIN_CATEGORIES[$category]}" ]]; then
        print_error "Unknown plugin category: $category"
        print_info "Available categories: ${!PLUGIN_CATEGORIES[@]}"
        exit 1
    fi

    print_info "Installing $category plugins..."

    local plugins=(${PLUGIN_CATEGORIES[$category]})
    for plugin in "${plugins[@]}"; do
        if [[ -n "$plugin" ]]; then
            install_single_plugin "$plugin" "$dry_run" "$skip_activation"
        fi
    done
}

install_single_plugin() {
    local plugin="$1"
    local dry_run="$2"
    local skip_activation="$3"

    # Extract plugin name from composer package
    local plugin_name
    if [[ "$plugin" == wpackagist-plugin/* ]]; then
        plugin_name="${plugin#wpackagist-plugin/}"
    else
        plugin_name="$plugin"
    fi

    print_info "Processing plugin: $plugin_name"

    if [[ "$dry_run" == true ]]; then
        print_info "DRY RUN: Would install $plugin"
        return
    fi

    # Install via Composer if it's a wpackagist plugin
    if [[ "$plugin" == wpackagist-plugin/* ]]; then
        if composer require "$plugin" --no-interaction 2>/dev/null; then
            print_success "Installed $plugin_name via Composer"
        else
            print_error "Failed to install $plugin_name via Composer"
            return 1
        fi
    fi

    # Activate plugin via WP-CLI
    if [[ "$skip_activation" != true ]]; then
        if docker exec "$WP_CONTAINER" wp plugin activate "$plugin_name" --allow-root 2>/dev/null; then
            print_success "Activated $plugin_name"
        else
            print_warning "Failed to activate $plugin_name (may already be active or not installed)"
        fi
    fi
}

activate_plugins() {
    local category="$1"

    if [[ "$category" == "all" ]] || [[ -z "$category" ]]; then
        print_info "Activating all installed plugins..."

        # Get list of installed plugins
        local installed_plugins
        installed_plugins=$(docker exec "$WP_CONTAINER" wp plugin list --field=name --status=inactive --allow-root 2>/dev/null || echo "")

        if [[ -n "$installed_plugins" ]]; then
            while IFS= read -r plugin; do
                if [[ -n "$plugin" ]]; then
                    if docker exec "$WP_CONTAINER" wp plugin activate "$plugin" --allow-root 2>/dev/null; then
                        print_success "Activated $plugin"
                    else
                        print_error "Failed to activate $plugin"
                    fi
                fi
            done <<< "$installed_plugins"
        else
            print_info "No inactive plugins found"
        fi
    else
        # Activate plugins from specific category
        local plugins=(${PLUGIN_CATEGORIES[$category]})
        for plugin in "${plugins[@]}"; do
            if [[ -n "$plugin" ]]; then
                local plugin_name="${plugin#wpackagist-plugin/}"
                if docker exec "$WP_CONTAINER" wp plugin activate "$plugin_name" --allow-root 2>/dev/null; then
                    print_success "Activated $plugin_name"
                else
                    print_warning "Failed to activate $plugin_name"
                fi
            fi
        done
    fi
}

update_plugins() {
    print_info "Updating all plugins..."

    # Update via Composer
    print_info "Updating Composer packages..."
    if composer update --no-dev --optimize-autoloader; then
        print_success "Composer packages updated"
    else
        print_error "Failed to update Composer packages"
    fi

    # Update via WP-CLI
    print_info "Updating plugins via WP-CLI..."
    if docker exec "$WP_CONTAINER" wp plugin update --all --allow-root; then
        print_success "Plugins updated via WP-CLI"
    else
        print_warning "Some plugin updates may have failed"
    fi
}

list_plugins() {
    local status="$1"

    print_info "Listing plugins..."

    case $status in
        active)
            docker exec "$WP_CONTAINER" wp plugin list --status=active --allow-root
            ;;
        inactive)
            docker exec "$WP_CONTAINER" wp plugin list --status=inactive --allow-root
            ;;
        must-use)
            docker exec "$WP_CONTAINER" wp plugin list --status=must-use --allow-root
            ;;
        *)
            docker exec "$WP_CONTAINER" wp plugin list --allow-root
            ;;
    esac
}

search_plugins() {
    local search_term="$1"

    if [[ -z "$search_term" ]]; then
        print_error "Search term is required"
        exit 1
    fi

    print_info "Searching for plugins: $search_term"
    docker exec "$WP_CONTAINER" wp plugin search "$search_term" --allow-root
}

backup_plugin_config() {
    print_info "Creating plugin configuration backup..."

    mkdir -p "$PLUGIN_BACKUP_DIR"

    local backup_file="$PLUGIN_BACKUP_DIR/plugins_backup_${DATE}.json"

    # Export plugin list and settings
    docker exec "$WP_CONTAINER" wp plugin list --format=json --allow-root > "$backup_file"

    # Backup active plugin configurations
    local config_backup="$PLUGIN_BACKUP_DIR/plugin_configs_${DATE}.sql"
    docker exec legacy-concierge-mysql mysqladump -u root -p"${DB_ROOT_PASSWORD}" "${DB_NAME}" --where="option_name LIKE '%plugin%' OR option_name LIKE '%widget%'" > "$config_backup"

    print_success "Plugin backup created:"
    print_info "Plugin list: $backup_file"
    print_info "Configurations: $config_backup"
}

show_plugin_status() {
    print_header

    print_info "Plugin Statistics:"
    local total_plugins
    total_plugins=$(docker exec "$WP_CONTAINER" wp plugin list --field=name --allow-root | wc -l)
    local active_plugins
    active_plugins=$(docker exec "$WP_CONTAINER" wp plugin list --status=active --field=name --allow-root | wc -l)
    local inactive_plugins
    inactive_plugins=$(docker exec "$WP_CONTAINER" wp plugin list --status=inactive --field=name --allow-root | wc -l)

    echo "Total plugins: $total_plugins"
    echo "Active plugins: $active_plugins"
    echo "Inactive plugins: $inactive_plugins"
    echo

    print_info "Recently Active Plugins:"
    docker exec "$WP_CONTAINER" wp plugin list --status=active --format=table --allow-root | head -10
    echo

    print_info "Premium Plugins Requiring Manual Installation:"
    echo "$PREMIUM_PLUGINS" | while read -r plugin; do
        if [[ -n "$plugin" ]]; then
            echo "- $plugin"
        fi
    done
}

show_premium_plugins_info() {
    print_info "Premium plugins that require manual installation:"
    echo
    echo "$PREMIUM_PLUGINS" | while read -r plugin; do
        if [[ -n "$plugin" ]]; then
            echo -e "${YELLOW}• $plugin${NC}"
            case $plugin in
                "all-in-one-wp-migration-unlimited-extension")
                    echo "  → Premium extension for unlimited migrations"
                    ;;
                "bridge-core")
                    echo "  → Core functionality for Bridge theme"
                    ;;
                "elementor-pro")
                    echo "  → Pro version of Elementor page builder"
                    ;;
                "instagram-feed-pro")
                    echo "  → Premium Instagram feed plugin"
                    ;;
                "revslider")
                    echo "  → Revolution Slider premium plugin"
                    ;;
                "seedprod-coming-soon-pro-5")
                    echo "  → Premium coming soon page plugin"
                    ;;
            esac
            echo
        fi
    done

    print_warning "To install premium plugins:"
    print_warning "1. Download plugin files from your account"
    print_warning "2. Upload via WordPress admin or place in wp-content/plugins/"
    print_warning "3. Activate via WP-CLI: wp plugin activate [plugin-name]"
}

main() {
    local command="$1"
    local target="$2"
    local dry_run=false
    local force=false
    local skip_activation=false
    local verbose=false

    # Parse options
    shift 2 2>/dev/null || shift $#
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                dry_run=true
                shift
                ;;
            --force)
                force=true
                shift
                ;;
            --skip-activation)
                skip_activation=true
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
        install)
            check_prerequisites
            if [[ -z "$target" ]]; then
                print_error "Category or plugin name is required"
                usage
                exit 1
            fi

            if [[ "${PLUGIN_CATEGORIES[$target]+isset}" ]] || [[ "$target" == "all" ]]; then
                install_plugins_by_category "$target" "$dry_run" "$skip_activation"
            else
                install_single_plugin "$target" "$dry_run" "$skip_activation"
            fi
            ;;
        activate)
            check_prerequisites
            activate_plugins "$target"
            ;;
        update)
            check_prerequisites
            update_plugins
            ;;
        list)
            check_prerequisites
            list_plugins "$target"
            ;;
        search)
            check_prerequisites
            search_plugins "$target"
            ;;
        backup)
            check_prerequisites
            backup_plugin_config
            ;;
        status)
            check_prerequisites
            show_plugin_status
            ;;
        premium)
            show_premium_plugins_info
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
    show_plugin_status
    echo
    echo "Run '$0 help' for available commands"
    echo "Run '$0 premium' for premium plugin information"
else
    main "$@"
fi
    "wpackagist-plugin/instagram-feed-pro"
    "wpackagist-plugin/jetpack"
    "wpackagist-plugin/lead-call-buttons"
    "wpackagist-plugin/leadin"
    "wpackagist-plugin/litespeed-cache"
    "wpackagist-plugin/qi-addons-for-elementor"
    "wpackagist-plugin/revslider"
    "wpackagist-plugin/seedprod-coming-soon-pro-5"
    "wpackagist-plugin/wordpress-seo"
    "wpackagist-plugin/wp-sitemap-page"
)

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Installing WordPress plugins via Composer...${NC}"
echo ""

successful=()
failed=()

# Loop through each plugin and try to install it
for plugin in "${plugins[@]}"; do
    echo -e "Installing: ${YELLOW}$plugin${NC}"

    if composer require "$plugin" --no-update; then
        echo -e "${GREEN}✓ Successfully added: $plugin${NC}"
        successful+=("$plugin")
    else
        echo -e "${RED}✗ Failed to add: $plugin${NC}"
        failed+=("$plugin")
    fi
    echo ""
done

echo "======================================="
echo -e "${GREEN}Successfully added (${#successful[@]} plugins):${NC}"
for plugin in "${successful[@]}"; do
    echo "  ✓ $plugin"
done

echo ""
echo -e "${RED}Failed to add (${#failed[@]} plugins):${NC}"
for plugin in "${failed[@]}"; do
    echo "  ✗ $plugin"
done

echo ""
echo -e "${YELLOW}Running composer update to install dependencies...${NC}"
composer update

echo ""
echo -e "${GREEN}Plugin installation process complete!${NC}"
echo -e "${YELLOW}Note: Failed plugins are likely premium plugins not available on WPackagist.${NC}"
