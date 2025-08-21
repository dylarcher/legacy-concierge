#!/bin/bash

# Simple WordPress URL replacement shell script
# Run this from the WordPress root directory

# Update these variables for your environment
OLD_URL="https://legacyconcierge.com"   # Replace with your live URL
NEW_URL="http://localhost:8000"         # Your local URL
TABLE_PREFIX="wp8w_"                    # Update this to match your table prefix

# Load DB credentials from wp-config.php
# Parse DB_* values using grep and sed
WP_CONFIG="wp-config.php"
if [ ! -f "$WP_CONFIG" ]; then
  echo "wp-config.php not found! Run this script from your WordPress root directory."
  exit 1
fi

DB_NAME=$(grep -E "define\('DB_NAME'," $WP_CONFIG | sed "s/.*'DB_NAME', '\([^']*\)'.*/\1/")
DB_USER=$(grep -E "define\('DB_USER'," $WP_CONFIG | sed "s/.*'DB_USER', '\([^']*\)'.*/\1/")
DB_PASSWORD=$(grep -E "define\('DB_PASSWORD'," $WP_CONFIG | sed "s/.*'DB_PASSWORD', '\([^']*\)'.*/\1/")
DB_HOST=$(grep -E "define\('DB_HOST'," $WP_CONFIG | sed "s/.*'DB_HOST', '\([^']*\)'.*/\1/")

if [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ] || [ -z "$DB_HOST" ]; then
  echo "Failed to parse database credentials from wp-config.php"
  exit 1
fi

echo "Starting URL replacement..."

# Function to run SQL update
run_sql() {
  local sql="$1"
  echo "$sql" | mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME"
}

# Update options table
run_sql "UPDATE ${TABLE_PREFIX}options SET option_value = REPLACE(option_value, '$OLD_URL', '$NEW_URL');"
echo "Updated options table"

# Update posts table
run_sql "UPDATE ${TABLE_PREFIX}posts SET post_content = REPLACE(post_content, '$OLD_URL', '$NEW_URL');"
echo "Updated posts table"

# Update postmeta table
run_sql "UPDATE ${TABLE_PREFIX}postmeta SET meta_value = REPLACE(meta_value, '$OLD_URL', '$NEW_URL');"
echo "Updated postmeta table"

# Update comments table
run_sql "UPDATE ${TABLE_PREFIX}comments SET comment_content = REPLACE(comment_content, '$OLD_URL', '$NEW_URL');"
echo "Updated comments table"

echo "URL replacement completed!"
echo "Remember to clear any caching and check your site."
