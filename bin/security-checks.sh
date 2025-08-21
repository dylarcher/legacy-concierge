#!/bin/bash

# WordPress Security Monitor Script
# Run this script periodically to check for security issues

echo "=== WordPress Security Check ==="
echo "Date: $(date)"
echo ""

# Check file permissions
echo "Checking file permissions..."
find /var/www/html -type f -perm 777 -ls 2>/dev/null | head -10
find /var/www/html -type d -perm 777 -ls 2>/dev/null | head -10

# Check for suspicious files
echo ""
echo "Checking for suspicious files..."
find /var/www/html -name "*.php" -exec grep -l "eval\|base64_decode\|exec\|shell_exec" {} \; 2>/dev/null | head -10

# Check WordPress core integrity
echo ""
echo "Checking WordPress core files..."
wp core verify-checksums --allow-root 2>/dev/null || echo "WP-CLI not available"

# Check plugin updates
echo ""
echo "Checking for plugin updates..."
wp plugin list --update=available --allow-root 2>/dev/null || echo "WP-CLI not available"

# Check theme updates
echo ""
echo "Checking for theme updates..."
wp theme list --update=available --allow-root 2>/dev/null || echo "WP-CLI not available"

# Check for failed login attempts (if log file exists)
echo ""
echo "Recent failed login attempts:"
if [ -f "/var/log/auth.log" ]; then
    grep "wp-login" /var/log/auth.log | tail -5 2>/dev/null || echo "No auth log found"
else
    echo "Auth log not available"
fi

echo ""
echo "=== Security check complete ==="
