#!/bin/bash

# Professional WordPress Project Setup Script
# Sets up a clean, modern WordPress development environment
# Following industry best practices from the comprehensive development guide

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Professional WordPress Setup         ${NC}"
echo -e "${BLUE}========================================${NC}"
echo

# Check prerequisites
echo -e "${BLUE}Checking prerequisites...${NC}"

if ! command -v composer &> /dev/null; then
    echo -e "${RED}✗ Composer is required but not installed.${NC}"
    echo "Install from: https://getcomposer.org/"
    exit 1
fi

if ! command -v php &> /dev/null; then
    echo -e "${RED}✗ PHP is required but not installed.${NC}"
    exit 1
fi

PHP_VERSION=$(php -r "echo PHP_VERSION;" | cut -d. -f1,2)
if (( $(echo "$PHP_VERSION < 8.0" | bc -l) )); then
    echo -e "${RED}✗ PHP 8.0+ required. Current version: $PHP_VERSION${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Prerequisites met${NC}"
echo

# Install/Update Composer dependencies
echo -e "${BLUE}Installing Composer dependencies...${NC}"
if [ ! -f "composer.json" ]; then
    echo -e "${RED}✗ composer.json not found${NC}"
    exit 1
fi

composer install --optimize-autoloader
echo -e "${GREEN}✓ Composer dependencies installed${NC}"

# Set up environment configuration
echo -e "${BLUE}Setting up environment configuration...${NC}"
if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        cp .env.example .env
        echo -e "${GREEN}✓ Environment file created from .env.example${NC}"
        echo -e "${YELLOW}⚠ Please edit .env with your database credentials${NC}"
    else
        echo -e "${YELLOW}⚠ No .env.example found, creating basic .env${NC}"
        cat > .env << 'EOF'
# Database Configuration
DB_NAME=legacy_concierge_wp
DB_USER=root
DB_PASSWORD=root
DB_HOST=localhost

# WordPress Configuration
WP_ENV=development
WP_HOME=http://localhost:8080
WP_SITEURL=${WP_HOME}/wordpress

# Security Keys (Generate from: https://api.wordpress.org/secret-key/1.1/salt/)
AUTH_KEY='put your unique phrase here'
SECURE_AUTH_KEY='put your unique phrase here'
LOGGED_IN_KEY='put your unique phrase here'
NONCE_KEY='put your unique phrase here'
AUTH_SALT='put your unique phrase here'
SECURE_AUTH_SALT='put your unique phrase here'
LOGGED_IN_SALT='put your unique phrase here'
NONCE_SALT='put your unique phrase here'

# Debug Settings
WP_DEBUG=true
WP_DEBUG_LOG=true
WP_DEBUG_DISPLAY=false
EOF
        echo -e "${GREEN}✓ Basic .env file created${NC}"
    fi
else
    echo -e "${GREEN}✓ Environment file already exists${NC}"
fi

# Create necessary directories
echo -e "${BLUE}Creating project structure...${NC}"
mkdir -p wp-content/{themes,plugins,mu-plugins}
mkdir -p wp-content/themes
mkdir -p wp-content/plugins
mkdir -p wp-content/mu-plugins

# Create security index.php files
echo '<?php // Silence is golden' > wp-content/index.php
echo '<?php // Silence is golden' > wp-content/themes/index.php
echo '<?php // Silence is golden' > wp-content/plugins/index.php
echo '<?php // Silence is golden' > wp-content/mu-plugins/index.php

echo -e "${GREEN}✓ Project structure created${NC}"

# Create symlinks for WordPress core (if using johnpbloch/wordpress-core)
echo -e "${BLUE}Creating WordPress core symlinks...${NC}"
if [ -d "legacy-concierge" ]; then
    # Create symbolic links to WordPress core
    ln -sf legacy-concierge/wp-admin wp-admin 2>/dev/null || true
    ln -sf legacy-concierge/wp-includes wp-includes 2>/dev/null || true
    ln -sf legacy-concierge/index.php index.php 2>/dev/null || true
    ln -sf legacy-concierge/wp-config-sample.php wp-config-sample.php 2>/dev/null || true

    # Create other necessary WordPress files as symlinks
    for file in wordpress/wp-*.php; do
        if [ -f "$file" ] && [ "$(basename "$file")" != "wp-config.php" ]; then
            ln -sf "$file" "$(basename "$file")" 2>/dev/null || true
        fi
    done

    echo -e "${GREEN}✓ WordPress core symlinks created${NC}"
else
    echo -e "${YELLOW}⚠ WordPress core not found. Run 'composer install' first.${NC}"
fi

# Set up wp-config.php if it doesn't exist
echo -e "${BLUE}Setting up WordPress configuration...${NC}"
if [ ! -f "wp-config.php" ]; then
    cat > wp-config.php << 'EOF'
<?php
/**
 * Professional WordPress Configuration
 * Uses environment variables for secure configuration management
 */

// Load Composer autoloader
require_once __DIR__ . '/vendor/autoload.php';

// Load environment variables
if (file_exists(__DIR__ . '/.env')) {
    $dotenv = Dotenv\Dotenv::createImmutable(__DIR__);
    $dotenv->load();
}

// Database Configuration
define('DB_NAME', $_ENV['DB_NAME']);
define('DB_USER', $_ENV['DB_USER']);
define('DB_PASSWORD', $_ENV['DB_PASSWORD']);
define('DB_HOST', $_ENV['DB_HOST']);
define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', '');

// WordPress URLs
define('WP_HOME', $_ENV['WP_HOME']);
define('WP_SITEURL', $_ENV['WP_SITEURL']);

// Security Keys
define('AUTH_KEY',         $_ENV['AUTH_KEY'] ?? '');
define('SECURE_AUTH_KEY',  $_ENV['SECURE_AUTH_KEY'] ?? '');
define('LOGGED_IN_KEY',    $_ENV['LOGGED_IN_KEY'] ?? '');
define('NONCE_KEY',        $_ENV['NONCE_KEY'] ?? '');
define('AUTH_SALT',        $_ENV['AUTH_SALT'] ?? '');
define('SECURE_AUTH_SALT', $_ENV['SECURE_AUTH_SALT'] ?? '');
define('LOGGED_IN_SALT',   $_ENV['LOGGED_IN_SALT'] ?? '');
define('NONCE_SALT',       $_ENV['NONCE_SALT'] ?? '');

// WordPress Table Prefix
$table_prefix = 'wp_';

// Debug Settings
define('WP_DEBUG', $_ENV['WP_DEBUG'] ?? false);
define('WP_DEBUG_LOG', $_ENV['WP_DEBUG_LOG'] ?? false);
define('WP_DEBUG_DISPLAY', $_ENV['WP_DEBUG_DISPLAY'] ?? false);

// Security Settings
define('DISALLOW_FILE_EDIT', true);
define('DISALLOW_FILE_MODS', false); // Allow plugin updates
define('FORCE_SSL_ADMIN', false); // Set to true in production

// Performance Settings
define('WP_MEMORY_LIMIT', '512M');
define('WP_MAX_MEMORY_LIMIT', '1024M');

// Environment-specific settings
if ($_ENV['WP_ENV'] === 'development') {
    define('WP_DEBUG', true);
    define('WP_DEBUG_LOG', true);
    define('WP_DEBUG_DISPLAY', true);
    define('SAVEQUERIES', true);
}

/* That's all, stop editing! Happy publishing. */

/** Absolute path to the WordPress directory. */
if (!defined('ABSPATH')) {
    define('ABSPATH', __DIR__ . '/wordpress/');
}

/** Sets up WordPress vars and included files. */
require_once ABSPATH . 'wp-settings.php';
EOF
    echo -e "${GREEN}✓ wp-config.php created${NC}"
else
    echo -e "${GREEN}✓ wp-config.php already exists${NC}"
fi

# Set up proper file permissions
echo -e "${BLUE}Setting file permissions...${NC}"
chmod 600 .env 2>/dev/null || true
chmod 644 wp-config.php 2>/dev/null || true
chmod 755 bin/*.sh 2>/dev/null || true
echo -e "${GREEN}✓ File permissions set${NC}"

echo
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✓ Professional WordPress setup complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo

echo -e "${YELLOW}Next steps:${NC}"
echo -e "1. Edit .env file with your database credentials"
echo -e "2. Set up your local development environment"
echo -e "3. Import your database if migrating from existing site"
echo -e "4. Install your custom themes/plugins in wp-content/"
echo -e "5. Access your site and complete WordPress installation"
echo

echo -e "${BLUE}Your project now follows modern WordPress development best practices!${NC}"
echo -e "• Dependencies managed by Composer"
echo -e "• Secure configuration with .env files"
echo -e "• Clean repository structure"
echo -e "• Professional development workflow ready"
