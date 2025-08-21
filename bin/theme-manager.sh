#!/bin/bash

# WordPress Theme Management Script
# Handles theme development, building, and deployment tasks

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
THEMES_DIR="$PROJECT_ROOT/wp-content/themes"
ENV_FILE="$PROJECT_ROOT/.env"

# Load environment variables if available
if [[ -f "$ENV_FILE" ]]; then
    set -a
    source "$ENV_FILE"
    set +a
fi

# Default configuration
DEFAULT_THEME_NAME="${DEFAULT_THEME_NAME:-custom-theme}"
WP_PATH="${WP_PATH:-$PROJECT_ROOT/wordpress}"

# Function to display usage
usage() {
    echo -e "${BLUE}WordPress Theme Management Script${NC}"
    echo
    echo "Usage: $0 [COMMAND] [THEME_NAME] [OPTIONS]"
    echo
    echo "Commands:"
    echo "  list                       List all installed themes"
    echo "  create <name>             Create new theme from starter template"
    echo "  activate <name>           Activate a theme"
    echo "  build [theme]             Build theme assets (CSS, JS)"
    echo "  watch [theme]             Watch and auto-build theme assets"
    echo "  package <theme>           Package theme for distribution"
    echo "  install <theme.zip>       Install theme from zip file"
    echo "  update <theme>            Update theme dependencies"
    echo "  validate <theme>          Validate theme code and structure"
    echo "  export <theme>            Export theme for backup/sharing"
    echo
    echo "Options:"
    echo "  --production              Build for production (minified)"
    echo "  --verbose                 Show detailed output"
    echo "  --help                    Show this help message"
    echo
    echo "Examples:"
    echo "  $0 list                           # List all themes"
    echo "  $0 create my-theme                # Create new theme"
    echo "  $0 build my-theme --production    # Build theme for production"
    echo "  $0 watch my-theme                 # Watch theme files for changes"
}

# Function to check if WP-CLI is available
check_wp_cli() {
    if ! command -v wp >/dev/null 2>&1; then
        echo -e "${RED}Error: WP-CLI is required but not installed${NC}"
        echo "Please install WP-CLI: https://wp-cli.org/"
        exit 1
    fi
}

# Function to list themes
list_themes() {
    echo -e "${BLUE}=== Installed Themes ===${NC}"

    if [[ -d "$THEMES_DIR" ]]; then
        for theme_dir in "$THEMES_DIR"/*; do
            if [[ -d "$theme_dir" ]]; then
                local theme_name=$(basename "$theme_dir")
                local style_css="$theme_dir/style.css"

                if [[ -f "$style_css" ]]; then
                    local theme_title=$(grep -m1 "Theme Name:" "$style_css" 2>/dev/null | sed 's/.*Theme Name:\s*//' | sed 's/\*\///')
                    local version=$(grep -m1 "Version:" "$style_css" 2>/dev/null | sed 's/.*Version:\s*//' | sed 's/\*\///')
                    local description=$(grep -m1 "Description:" "$style_css" 2>/dev/null | sed 's/.*Description:\s*//' | sed 's/\*\///')

                    echo -e "${GREEN}$theme_name${NC}"
                    [[ -n "$theme_title" ]] && echo "  Title: $theme_title"
                    [[ -n "$version" ]] && echo "  Version: $version"
                    [[ -n "$description" ]] && echo "  Description: $description"

                    # Check if it's the active theme
                    if wp --path="$WP_PATH" theme status "$theme_name" 2>/dev/null | grep -q "Active"; then
                        echo -e "  ${GREEN}Status: Active${NC}"
                    else
                        echo -e "  ${YELLOW}Status: Inactive${NC}"
                    fi

                    # Check for package.json (Node.js build process)
                    if [[ -f "$theme_dir/package.json" ]]; then
                        echo -e "  ${BLUE}Build: Node.js available${NC}"
                    fi

                    echo
                else
                    echo -e "${YELLOW}$theme_name (No style.css found)${NC}"
                fi
            fi
        done
    else
        echo -e "${RED}Themes directory not found: $THEMES_DIR${NC}"
    fi
}

# Function to create new theme
create_theme() {
    local theme_name="$1"
    local theme_dir="$THEMES_DIR/$theme_name"

    echo -e "${BLUE}Creating new theme: $theme_name${NC}"

    if [[ -d "$theme_dir" ]]; then
        echo -e "${RED}Error: Theme directory already exists: $theme_dir${NC}"
        exit 1
    fi

    # Create theme directory
    mkdir -p "$theme_dir"

    # Create basic theme files
    create_theme_files "$theme_dir" "$theme_name"

    # Initialize package.json for build tools
    create_package_json "$theme_dir" "$theme_name"

    echo -e "${GREEN}✓ Theme created successfully: $theme_dir${NC}"
    echo
    echo "Next steps:"
    echo "1. cd wp-content/themes/$theme_name"
    echo "2. npm install (to install build dependencies)"
    echo "3. $0 build $theme_name (to build assets)"
    echo "4. $0 activate $theme_name (to activate the theme)"
}

# Function to create basic theme files
create_theme_files() {
    local theme_dir="$1"
    local theme_name="$2"
    local theme_title=$(echo "$theme_name" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2)); print}')

    # style.css
    cat > "$theme_dir/style.css" <<EOF
/*
Theme Name: $theme_title
Description: A modern WordPress theme built with professional development practices.
Version: 1.0.0
Author: Your Name
Text Domain: $theme_name
*/

/* Theme styles will be compiled from SCSS */
EOF

    # index.php
    cat > "$theme_dir/index.php" <<'EOF'
<?php
/**
 * Main template file
 */

get_header(); ?>

<main id="main" class="site-main">
    <?php if (have_posts()) : ?>
        <?php while (have_posts()) : the_post(); ?>
            <article id="post-<?php the_ID(); ?>" <?php post_class(); ?>>
                <header class="entry-header">
                    <h2 class="entry-title">
                        <a href="<?php the_permalink(); ?>"><?php the_title(); ?></a>
                    </h2>
                </header>

                <div class="entry-content">
                    <?php the_excerpt(); ?>
                </div>
            </article>
        <?php endwhile; ?>

        <?php the_posts_navigation(); ?>
    <?php else : ?>
        <p><?php _e('No posts found.', 'text-domain'); ?></p>
    <?php endif; ?>
</main>

<?php
get_sidebar();
get_footer();
EOF

    # functions.php
    cat > "$theme_dir/functions.php" <<EOF
<?php
/**
 * Theme functions and definitions
 */

// Prevent direct access
if (!defined('ABSPATH')) {
    exit;
}

/**
 * Theme setup
 */
function ${theme_name//-/_}_setup() {
    // Add theme support for various WordPress features
    add_theme_support('title-tag');
    add_theme_support('post-thumbnails');
    add_theme_support('html5', array(
        'search-form',
        'comment-form',
        'comment-list',
        'gallery',
        'caption',
    ));

    // Register navigation menus
    register_nav_menus(array(
        'primary' => __('Primary Menu', '$theme_name'),
        'footer'  => __('Footer Menu', '$theme_name'),
    ));
}
add_action('after_setup_theme', '${theme_name//-/_}_setup');

/**
 * Enqueue scripts and styles
 */
function ${theme_name//-/_}_scripts() {
    // Main stylesheet
    wp_enqueue_style(
        '$theme_name-style',
        get_template_directory_uri() . '/dist/css/main.css',
        array(),
        wp_get_theme()->get('Version')
    );

    // Main JavaScript
    wp_enqueue_script(
        '$theme_name-script',
        get_template_directory_uri() . '/dist/js/main.js',
        array('jquery'),
        wp_get_theme()->get('Version'),
        true
    );
}
add_action('wp_enqueue_scripts', '${theme_name//-/_}_scripts');

/**
 * Register widget areas
 */
function ${theme_name//-/_}_widgets_init() {
    register_sidebar(array(
        'name'          => __('Sidebar', '$theme_name'),
        'id'            => 'sidebar-1',
        'description'   => __('Add widgets here.', '$theme_name'),
        'before_widget' => '<section id="%1\$s" class="widget %2\$s">',
        'after_widget'  => '</section>',
        'before_title'  => '<h3 class="widget-title">',
        'after_title'   => '</h3>',
    ));
}
add_action('widgets_init', '${theme_name//-/_}_widgets_init');
EOF

    # header.php
    cat > "$theme_dir/header.php" <<EOF
<!DOCTYPE html>
<html <?php language_attributes(); ?>>
<head>
    <meta charset="<?php bloginfo('charset'); ?>">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <?php wp_head(); ?>
</head>

<body <?php body_class(); ?>>
<?php wp_body_open(); ?>

<div id="page" class="site">
    <header id="masthead" class="site-header">
        <div class="container">
            <div class="site-branding">
                <h1 class="site-title">
                    <a href="<?php echo esc_url(home_url('/')); ?>"><?php bloginfo('name'); ?></a>
                </h1>
                <p class="site-description"><?php bloginfo('description'); ?></p>
            </div>

            <nav id="site-navigation" class="main-navigation">
                <?php
                wp_nav_menu(array(
                    'theme_location' => 'primary',
                    'menu_id'        => 'primary-menu',
                    'fallback_cb'    => false,
                ));
                ?>
            </nav>
        </div>
    </header>

    <div id="content" class="site-content">
        <div class="container">
EOF

    # footer.php
    cat > "$theme_dir/footer.php" <<EOF
        </div><!-- .container -->
    </div><!-- #content -->

    <footer id="colophon" class="site-footer">
        <div class="container">
            <div class="site-info">
                <p>&copy; <?php echo date('Y'); ?> <?php bloginfo('name'); ?>. All rights reserved.</p>
            </div>
        </div>
    </footer>
</div><!-- #page -->

<?php wp_footer(); ?>
</body>
</html>
EOF

    # Create source directories
    mkdir -p "$theme_dir/src/scss"
    mkdir -p "$theme_dir/src/js"
    mkdir -p "$theme_dir/dist/css"
    mkdir -p "$theme_dir/dist/js"

    # Basic SCSS file
    cat > "$theme_dir/src/scss/main.scss" <<'EOF'
// Main SCSS file
// Import your partials here

@import 'variables';
@import 'base';
@import 'components';

// Variables
$primary-color: #0073aa;
$text-color: #333;
$background-color: #fff;

// Base styles
body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    line-height: 1.6;
    color: $text-color;
    background-color: $background-color;
}

.container {
    max-width: 1200px;
    margin: 0 auto;
    padding: 0 20px;
}

// Header
.site-header {
    background: $primary-color;
    padding: 1rem 0;

    .site-title a {
        color: white;
        text-decoration: none;
    }
}

// Navigation
.main-navigation {
    ul {
        list-style: none;
        margin: 0;
        padding: 0;
        display: flex;

        li {
            margin-right: 2rem;

            a {
                color: white;
                text-decoration: none;

                &:hover {
                    text-decoration: underline;
                }
            }
        }
    }
}
EOF

    # Basic JavaScript file
    cat > "$theme_dir/src/js/main.js" <<'EOF'
/**
 * Main JavaScript file
 */

(function($) {
    'use strict';

    // Document ready
    $(document).ready(function() {
        console.log('Theme JavaScript loaded');

        // Add your custom JavaScript here
        initializeTheme();
    });

    /**
     * Initialize theme functionality
     */
    function initializeTheme() {
        // Mobile menu toggle (if needed)
        handleMobileMenu();

        // Smooth scrolling for anchor links
        handleSmoothScrolling();
    }

    /**
     * Handle mobile menu functionality
     */
    function handleMobileMenu() {
        // Add mobile menu toggle if needed
    }

    /**
     * Handle smooth scrolling for anchor links
     */
    function handleSmoothScrolling() {
        $('a[href*="#"]:not([href="#"])').click(function() {
            if (location.pathname.replace(/^\//, '') === this.pathname.replace(/^\//, '') &&
                location.hostname === this.hostname) {
                var target = $(this.hash);
                target = target.length ? target : $('[name=' + this.hash.slice(1) + ']');
                if (target.length) {
                    $('html, body').animate({
                        scrollTop: target.offset().top
                    }, 1000);
                    return false;
                }
            }
        });
    }

})(jQuery);
EOF
}

# Function to create package.json for theme
create_package_json() {
    local theme_dir="$1"
    local theme_name="$2"

    cat > "$theme_dir/package.json" <<EOF
{
  "name": "$theme_name",
  "version": "1.0.0",
  "description": "WordPress theme build configuration",
  "main": "dist/js/main.js",
  "scripts": {
    "build": "npm run build:css && npm run build:js",
    "build:css": "sass src/scss/main.scss dist/css/main.css --style=expanded",
    "build:js": "webpack --mode=development",
    "build:production": "npm run build:css:production && npm run build:js:production",
    "build:css:production": "sass src/scss/main.scss dist/css/main.css --style=compressed",
    "build:js:production": "webpack --mode=production",
    "watch": "npm run watch:css & npm run watch:js",
    "watch:css": "sass src/scss/main.scss dist/css/main.css --watch",
    "watch:js": "webpack --watch --mode=development",
    "lint:css": "stylelint src/scss/**/*.scss",
    "lint:js": "eslint src/js/**/*.js"
  },
  "devDependencies": {
    "sass": "^1.69.0",
    "webpack": "^5.88.0",
    "webpack-cli": "^5.1.0",
    "@babel/core": "^7.22.0",
    "@babel/preset-env": "^7.22.0",
    "babel-loader": "^9.1.0",
    "css-loader": "^6.8.0",
    "style-loader": "^3.3.0",
    "eslint": "^8.44.0",
    "stylelint": "^15.10.0",
    "stylelint-config-standard-scss": "^10.0.0"
  },
  "browserslist": [
    "> 1%",
    "last 2 versions",
    "not dead"
  ]
}
EOF

    # Create webpack.config.js
    cat > "$theme_dir/webpack.config.js" <<'EOF'
const path = require('path');

module.exports = {
    entry: './src/js/main.js',
    output: {
        filename: 'main.js',
        path: path.resolve(__dirname, 'dist/js'),
    },
    module: {
        rules: [
            {
                test: /\.js$/,
                exclude: /node_modules/,
                use: {
                    loader: 'babel-loader',
                    options: {
                        presets: ['@babel/preset-env']
                    }
                }
            }
        ]
    }
};
EOF
}

# Function to build theme assets
build_theme() {
    local theme_name="${1:-$DEFAULT_THEME_NAME}"
    local production="${2:-false}"
    local theme_dir="$THEMES_DIR/$theme_name"

    echo -e "${BLUE}Building theme: $theme_name${NC}"

    if [[ ! -d "$theme_dir" ]]; then
        echo -e "${RED}Error: Theme directory not found: $theme_dir${NC}"
        exit 1
    fi

    cd "$theme_dir"

    if [[ -f "package.json" ]]; then
        # Install dependencies if node_modules doesn't exist
        if [[ ! -d "node_modules" ]]; then
            echo -e "${YELLOW}Installing Node.js dependencies...${NC}"
            npm install
        fi

        # Build assets
        if [[ "$production" == "true" ]]; then
            echo -e "${YELLOW}Building for production...${NC}"
            npm run build:production
        else
            echo -e "${YELLOW}Building for development...${NC}"
            npm run build
        fi

        echo -e "${GREEN}✓ Theme built successfully${NC}"
    else
        echo -e "${YELLOW}No package.json found. Creating basic CSS from SCSS...${NC}"

        # Simple SCSS compilation if sass is available
        if command -v sass >/dev/null 2>&1; then
            if [[ -f "src/scss/main.scss" ]]; then
                mkdir -p "dist/css"
                if [[ "$production" == "true" ]]; then
                    sass src/scss/main.scss dist/css/main.css --style=compressed
                else
                    sass src/scss/main.scss dist/css/main.css --style=expanded
                fi
                echo -e "${GREEN}✓ SCSS compiled${NC}"
            fi
        else
            echo -e "${YELLOW}SASS not available. Install Node.js dependencies for full build process.${NC}"
        fi
    fi

    cd "$PROJECT_ROOT"
}

# Function to watch theme files for changes
watch_theme() {
    local theme_name="${1:-$DEFAULT_THEME_NAME}"
    local theme_dir="$THEMES_DIR/$theme_name"

    echo -e "${BLUE}Watching theme: $theme_name${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop watching${NC}"

    if [[ ! -d "$theme_dir" ]]; then
        echo -e "${RED}Error: Theme directory not found: $theme_dir${NC}"
        exit 1
    fi

    cd "$theme_dir"

    if [[ -f "package.json" ]]; then
        npm run watch
    else
        echo -e "${RED}Error: No package.json found. Cannot start watch mode.${NC}"
        echo "Run: $0 create $theme_name to create a new theme with build tools"
        exit 1
    fi

    cd "$PROJECT_ROOT"
}

# Function to activate theme
activate_theme() {
    local theme_name="$1"

    check_wp_cli

    echo -e "${BLUE}Activating theme: $theme_name${NC}"

    if wp --path="$WP_PATH" theme activate "$theme_name"; then
        echo -e "${GREEN}✓ Theme activated successfully${NC}"
    else
        echo -e "${RED}✗ Failed to activate theme${NC}"
        exit 1
    fi
}

# Function to package theme
package_theme() {
    local theme_name="$1"
    local theme_dir="$THEMES_DIR/$theme_name"
    local package_dir="$PROJECT_ROOT/.backup"
    local package_name="${theme_name}_$(date +%Y%m%d_%H%M%S).zip"

    echo -e "${BLUE}Packaging theme: $theme_name${NC}"

    if [[ ! -d "$theme_dir" ]]; then
        echo -e "${RED}Error: Theme directory not found: $theme_dir${NC}"
        exit 1
    fi

    # Create package directory
    mkdir -p "$package_dir"

    # Create zip file
    cd "$THEMES_DIR"
    zip -r "$package_dir/$package_name" "$theme_name" \
        -x "*/node_modules/*" \
        -x "*/src/*" \
        -x "*/.git/*" \
        -x "*/.*" \
        -x "*/package-lock.json" \
        -x "*/yarn.lock"

    echo -e "${GREEN}✓ Theme packaged: $package_dir/$package_name${NC}"

    cd "$PROJECT_ROOT"
}

# Main function
main() {
    local command="${1:-}"
    local theme_name="${2:-}"
    local production=false
    local verbose=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --production)
                production=true
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
            *)
                if [[ -z "$command" ]]; then
                    command="$1"
                elif [[ -z "$theme_name" && "$command" != "list" ]]; then
                    theme_name="$1"
                fi
                shift
                ;;
        esac
    done

    # Execute command
    case "$command" in
        list)
            list_themes
            ;;
        create)
            if [[ -z "$theme_name" ]]; then
                echo -e "${RED}Error: Theme name required${NC}"
                usage
                exit 1
            fi
            create_theme "$theme_name"
            ;;
        build)
            build_theme "$theme_name" "$production"
            ;;
        watch)
            watch_theme "$theme_name"
            ;;
        activate)
            if [[ -z "$theme_name" ]]; then
                echo -e "${RED}Error: Theme name required${NC}"
                usage
                exit 1
            fi
            activate_theme "$theme_name"
            ;;
        package)
            if [[ -z "$theme_name" ]]; then
                echo -e "${RED}Error: Theme name required${NC}"
                usage
                exit 1
            fi
            package_theme "$theme_name"
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
