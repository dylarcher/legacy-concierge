#!/bin/bash

# Docker Health Check Script for WordPress
# This script monitors the health of WordPress and database containers

# Load environment variables
if [ -f .env ]; then
    source .env
fi

echo "=== Docker Container Health Check ==="
echo "Date: $(date)"
echo ""

# Check if containers are running
echo "Container Status:"
docker-compose ps

echo ""
echo "WordPress Health Check:"
curl -f http://localhost:8000/wp-admin/admin-ajax.php?action=heartbeat &> /dev/null
if [ $? -eq 0 ]; then
    echo "✅ WordPress is responding"
else
    echo "❌ WordPress is not responding"
fi

echo ""
echo "Database Health Check:"
docker-compose exec -T db mysql -u"${MYSQL_USER:-wordpress_user}" -p"${MYSQL_PASSWORD:-secure_password}" -e "SELECT 1;" &> /dev/null
if [ $? -eq 0 ]; then
    echo "✅ Database is responding"
else
    echo "❌ Database is not responding (this may be normal if credentials are not accessible)"
fi

echo ""
echo "=== Health check complete ==="
