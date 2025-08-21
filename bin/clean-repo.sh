#!/bin/bash

# Repository Cleanup Script
# Removes files that shouldn't be tracked according to modern WordPress best practices
# Based on the "ignore by default" philosophy

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Legacy Concierge Repository Cleanup  ${NC}"
echo -e "${BLUE}========================================${NC}"
echo

echo -e "${YELLOW}This script will remove files that should NOT be in the repository:${NC}"
echo -e "• WordPress core files (managed by Composer)"
echo -e "• Third-party plugins (managed by Composer)"
echo -e "• Purchased/premium themes (manually managed)"
echo -e "• System files and temporary directories"
echo -e "• Docker development files"
echo -e "• Build artifacts and logs"
echo

echo -e "${RED}WARNING: This will permanently delete files!${NC}"
echo -e "${RED}Make sure you have backups and understand what will be removed.${NC}"
echo

read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

echo -e "${BLUE}Starting cleanup...${NC}"

# Remove WordPress core files (managed by Composer)
echo -e "${YELLOW}Removing WordPress core files...${NC}"
rm -rf wordpress/
rm -f wp-*.php
rm -f xmlrpc.php
rm -f index.php
rm -rf wp-admin/
rm -rf wp-includes/
echo -e "${GREEN}✓ WordPress core files removed${NC}"

# Remove third-party plugins (managed by Composer)
echo -e "${YELLOW}Removing third-party plugins...${NC}"
if [ -d "wp-content/plugins" ]; then
    # Keep only index.php files for security
    find wp-content/plugins/ -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} \;
    find wp-content/plugins/ -name "*.php" ! -name "index.php" -delete
fi
echo -e "${GREEN}✓ Third-party plugins removed${NC}"

# Remove third-party themes (keep only index.php)
echo -e "${YELLOW}Cleaning up themes directory...${NC}"
if [ -d "wp-content/themes" ]; then
    # Remove all themes except custom ones (you'll need to manually specify custom themes)
    rm -rf wp-content/themes/*/
    # Keep security index.php
    echo '<?php // Silence is golden' > wp-content/themes/index.php
fi
echo -e "${GREEN}✓ Third-party themes removed${NC}"

# Remove uploads and cache directories (stateful data)
echo -e "${YELLOW}Removing stateful data directories...${NC}"
rm -rf wp-content/uploads/
rm -rf wp-content/cache/
rm -rf wp-content/upgrade/
rm -rf wp-content/backups/
echo -e "${GREEN}✓ Stateful data directories removed${NC}"

# Remove system files
echo -e "${YELLOW}Removing system files...${NC}"
find . -name ".DS_Store" -delete
find . -name "Thumbs.db" -delete
find . -name "*.log" -delete
rm -rf .tmp/
rm -rf .backup/
rm -rf .db/
echo -e "${GREEN}✓ System files removed${NC}"

# Remove Docker development files (these shouldn't be in main repo)
echo -e "${YELLOW}Removing Docker development files...${NC}"
rm -f docker-compose.yml
rm -f docker-compose.override.yml
rm -f Dockerfile
rm -f .dockerignore
rm -rf mysql/
echo -e "${GREEN}✓ Docker files removed${NC}"

# Remove build dependencies
echo -e "${YELLOW}Removing build dependencies...${NC}"
rm -rf vendor/
rm -rf node_modules/
echo -e "${GREEN}✓ Build dependencies removed${NC}"

# Remove IDE/editor files
echo -e "${YELLOW}Removing IDE/editor files...${NC}"
rm -rf .vscode/
rm -f .editorconfig
echo -e "${GREEN}✓ IDE files removed${NC}"

# Remove sensitive configuration files
echo -e "${YELLOW}Removing sensitive files...${NC}"
rm -f wp-config.php
rm -f .env
rm -f .htaccess
echo -e "${GREEN}✓ Sensitive files removed${NC}"

# Clean up JavaScript files that were renamed but not needed in repo
echo -e "${YELLOW}Cleaning up legacy JavaScript files...${NC}"
rm -f legacy-concierge-*.js
echo -e "${GREEN}✓ Legacy JavaScript files removed${NC}"

echo
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✓ Repository cleanup complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo

echo -e "${YELLOW}Next steps:${NC}"
echo -e "1. Review the changes: ${GREEN}git status${NC}"
echo -e "2. Install dependencies: ${GREEN}composer install${NC}"
echo -e "3. Set up environment: ${GREEN}cp .env.example .env${NC}"
echo -e "4. Configure your .env file with database credentials"
echo -e "5. Commit the cleanup: ${GREEN}git add -A && git commit -m 'Clean repository structure'${NC}"
echo

echo -e "${BLUE}Repository now follows modern WordPress development best practices!${NC}"
