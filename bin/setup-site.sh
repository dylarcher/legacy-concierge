#!/bin/bash

# WordPress Site Setup Script for Legacy Concierge - Simple Version
# This script configures the Docker environment to load the correct content

set -e

# Define colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_status "Starting Legacy Concierge WordPress setup..."

# Check if Docker Compose is running
if ! docker-compose ps | grep -q "Up"; then
    print_status "Starting Docker containers..."
    docker-compose up -d
    print_status "Waiting for containers to start..."
    sleep 15
fi

# Wait for database to be ready
print_status "Waiting for database to be ready..."
for i in {1..30}; do
    if docker-compose exec mysql mysqladmin ping -h"localhost" --silent 2>/dev/null; then
        print_status "Database is ready!"
        break
    fi
    if [ $i -eq 30 ]; then
        print_error "Database failed to start after 30 attempts"
        exit 1
    fi
    echo -n "."
    sleep 2
done

# Install/update Composer dependencies
print_status "Installing Composer dependencies..."
docker-compose exec -T wordpress composer install --no-dev --optimize-autoloader 2>/dev/null || {
    print_warning "Composer install failed or not needed"
}

# Check WordPress installation
print_status "Checking WordPress installation status..."
if docker-compose exec -T wordpress wp core is-installed --allow-root 2>/dev/null; then
    print_status "WordPress is installed. Updating URLs..."

    # Update site URLs
    docker-compose exec -T wordpress wp option update home "http://localhost:8080" --allow-root 2>/dev/null || true
    docker-compose exec -T wordpress wp option update siteurl "http://localhost:8080/legacy-concierge" --allow-root 2>/dev/null || true

    print_status "URLs updated successfully!"
else
    print_warning "WordPress is not installed yet."
    print_warning "Please visit http://localhost:8080/legacy-concierge/ to complete the installation."
fi

# Activate essential plugins that should be available
print_status "Checking plugin status..."
ESSENTIAL_PLUGINS=("classic-editor" "contact-form-7" "wordpress-seo")

for plugin in "${ESSENTIAL_PLUGINS[@]}"; do
    if docker-compose exec -T wordpress wp plugin is-installed "$plugin" --allow-root 2>/dev/null; then
        if ! docker-compose exec -T wordpress wp plugin is-active "$plugin" --allow-root 2>/dev/null; then
            docker-compose exec -T wordpress wp plugin activate "$plugin" --allow-root 2>/dev/null && \
                print_status "✅ Activated plugin: $plugin" || \
                print_warning "⚠️  Could not activate plugin: $plugin"
        else
            print_status "✅ Plugin already active: $plugin"
        fi
    else
        print_warning "⚠️  Plugin not installed: $plugin"
    fi
done

# Clear caches if possible
print_status "Clearing caches..."
docker-compose exec -T wordpress wp cache flush --allow-root 2>/dev/null || true

print_status ""
print_status "🎉 Setup complete!"
print_status ""
print_status "🌐 Your Legacy Concierge site is available at:"
print_status "   📱 Main Site: http://localhost:8080"
print_status "   ⚙️  WordPress Admin: http://localhost:8080/legacy-concierge/wp-admin/"
print_status "   🗄️  Database Admin: http://localhost:8081"
print_status ""
print_status "📊 Database Information:"
print_status "   Database: legacy_concierge_wp"
print_status "   Username: wpuser"
print_status "   Password: wppassword"
print_status ""

# Test site accessibility
print_status "Testing site accessibility..."
if curl -s --max-time 10 -o /dev/null -w "%{http_code}" http://localhost:8080 2>/dev/null | grep -q "200\|301\|302"; then
    print_status "✅ Site is responding!"
    print_status ""
    print_status "🚀 Ready to go! Visit http://localhost:8080 to see your site."
else
    print_warning "⚠️  Site may not be fully ready yet."
    print_warning "   Give it a minute and try visiting http://localhost:8080"
    print_warning "   Check logs if needed: docker-compose logs -f wordpress"
fi
