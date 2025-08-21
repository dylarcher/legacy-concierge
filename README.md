# Legacy Concierge WordPress - Complete Project Guide

**Project Status**: Production Ready | **Last Updated**: August 20, 2025
**Environment**: Docker Containerized WordPress with MySQL 8.0

---

## 🚀 Quick Start

### Prerequisites

- Docker & Docker Compose installed
- Git for version control
- 2GB+ available RAM

### Launch Environment

```bash
cd /Users/darcher/dev/legacy-concierge
docker-compose up -d
```

### Environment Setup

1. **Copy Environment Variables**

   ```bash
   cp .env.example .env
   ```

2. **Configure Database Settings** (edit `.env` file)

   ```bash
   DB_NAME=legacy_concierge_wp
   DB_USER=wpuser
   DB_PASSWORD=your_secure_password
   DB_ROOT_PASSWORD=your_root_password
   WP_HOME=http://localhost:8080
   WP_SITEURL=${WP_HOME}
   ```

3. **Generate Security Keys**
   Visit <https://api.wordpress.org/secret-key/1.1/salt/> and replace the keys in `.env`

### Access Points

- **Website**: <http://localhost:8080>
- **WordPress Admin**: <http://localhost:8080/wp-admin/>
- **Database Admin (phpMyAdmin)**: <http://localhost:8081>

### Monitoring & Maintenance

```bash
npm run status                   # Comprehensive status report
npm run maintenance              # Run maintenance tasks
npm run clean                    # Clean repository structure
npm run security:check           # Security audit
npm run db:sync                  # Sync database from production
composer update                  # Update PHP dependencies
docker-compose ps               # Container status
```

---

## 📦 Modern Development Workflow

### Repository Philosophy

This project follows **"ignore by default"** Git strategy - only custom code and essential configuration is tracked.

### Available Scripts

```bash
# Project Setup & Management
npm run setup                    # Initial project setup
npm run clean                    # Clean non-tracked files

# Version & Changelog Management
npm run changelog                # Generate changelog
npm run changelog:patch          # Version bump + changelog (patch)
npm run changelog:minor          # Version bump + changelog (minor)
npm run changelog:major          # Version bump + changelog (major)

# Development & Deployment
npm run deploy                   # Deploy to production
npm run theme:manage             # Theme management utilities
npm run docker:backup            # Backup database
```

### What's Tracked vs Ignored

**Tracked** ✅: Custom themes, plugins, configuration, documentation
**Ignored** ❌: WordPress core, third-party plugins, uploads, cache

---

## 🏗️ Project Architecture

### Modern WordPress Stack

```plaintext
├── Docker Environment
│   ├── WordPress 6.8+ (PHP 8.2 + Apache)
│   ├── MySQL 8.0 Database
│   └── phpMyAdmin Interface
│
├── Dependency Management
│   ├── Composer (PHP packages)
│   ├── WPackagist (WordPress plugins)
│   └── Automated installation scripts
│
├── Security Features
│   ├── Environment variables (.env)
│   ├── File edit restrictions
│   ├── Security headers
│   └── Memory limits & optimizations
│
└── Development Tools
    ├── Automated setup scripts
    ├── Health check monitoring
    └── Status reporting tools
```

### File Structure

```plaintext
legacy-concierge/
├── 🐳 docker-compose.yml     # Container orchestration
├── 🐳 Dockerfile            # Custom WordPress container
├── 🔐 .env.example          # Environment variables template
├── 📦 composer.json         # PHP dependencies
├── ⚙️  wp-config.php         # WordPress configuration
├── 🛠️  bin/                  # Utility scripts (17 scripts)
├── 🎨 components/           # React components
├── 🖼️  sigimg/              # Signature images
├── �️  wordpress/           # WordPress core (Composer managed)
├── 🎭 wp-content/           # Themes, plugins, uploads
├── 📁 .backup/              # Archived backups (*.tar.gz)
├── �️  .db/                 # Database dumps
├── 📂 .tmp/                 # Temporary WordPress files
├── ⚙️  .vscode/             # VS Code configuration
├── 🏗️  .github/             # GitHub Actions & templates
└── 🐋 mysql/               # MySQL configuration
```

---

## 🛠️ Management Commands

### Container Management

```bash
# Start environment
docker-compose up -d

# Stop environment
docker-compose down

# View logs
docker-compose logs -f wordpress

# Database shell
docker-compose exec mysql mysql -u wpuser -p legacy_concierge_wp

# WordPress shell
docker-compose exec wordpress bash
```

### Site Management

```bash
# Run initial setup
./bin/setup-site.sh

# Check comprehensive status
./bin/status.sh

# Audit system health
./bin/audit-status.sh

# Health check monitoring
./bin/health-check.sh

# Database operations
./bin/optimize-database.sh
./bin/wp-database-backup.sh

# Install plugins
./bin/install_plugins.sh

# Security check
./bin/securityCheck.sh

# Health check
./bin/healthCheck.sh
```

### Development Workflow

```bash
# Update dependencies
docker-compose exec wordpress composer update

# Clear caches
docker-compose exec wordpress wp cache flush --allow-root

# Fix permissions
docker-compose exec wordpress chown -R www-data:www-data /var/www/html
```

---

## 🔒 Security Configuration

### Applied Security Measures ✅

- **File Editing Disabled**: `DISALLOW_FILE_EDIT = true`
- **Environment Variables**: Database credentials secured
- **Memory Limits**: 512MB standard, 1024MB admin
- **Security Headers**: Comprehensive headers via .htaccess
- **WordPress Salts**: Secure session management
- **Debug Settings**: Configured for development safety

### Database Configuration

| Key      | Value              | Summary              |
| -------- | :----------------- | :------------------- |
| Host     | mysql              | container networking |
| Database | legacy_concierge_w |                      |
| Username | wpuser             |                      |
| Password | _stored in_ `.env` |                      |
| Port     | 3306               |                      |

### Critical Security Notes ⚠️

- Never commit `.env` files to version control
- Always backup before major changes
- Monitor security logs regularly
- Keep plugins updated monthly

---

## 📊 Plugin Management

### Successfully Installed (19/25 plugins)

- **Content**: classic-editor, contact-form-7, duplicate-post
- **SEO**: wordpress-seo, redirection, really-simple-ssl
- **Performance**: litespeed-cache, wp-optimize, wp-super-cache
- **Commerce**: woocommerce, mailchimp-for-wp
- **Development**: custom-post-type-ui, advanced-custom-fields
- **Security**: wordfence, updraftplus
- **Builder**: elementor, jetpack
- **Communication**: wp-mail-smtp

### Manual Installation Required (6 plugins)

Premium or custom plugins that require manual upload:

- Bridge theme extensions
- Premium licenses
- Custom developed plugins

### Plugin Management Commands

```bash
# Install via Composer
docker-compose exec wordpress composer require wpackagist-plugin/plugin-name

# Activate plugin
docker-compose exec wordpress wp plugin activate plugin-name --allow-root

# List installed plugins
docker-compose exec wordpress wp plugin list --allow-root
```

---

## 🚀 Performance Optimization

### Current Optimizations ✅

- **Caching**: LiteSpeed Cache + WP Super Cache
- **Database**: Optimized MySQL 8.0 configuration
- **Images**: Automated optimization pipeline ready
- **Memory**: Optimized PHP memory limits
- **Autoloader**: Composer autoloader optimized

### Performance Monitoring

```bash
# Check Core Web Vitals
./bin/healthCheck.sh

# Monitor resource usage
docker stats

# Database optimization
docker-compose exec mysql mysqlcheck -u wpuser -p --optimize --all-databases
```

---

## 📈 Development Workflow

### Local Development Process

1. **Start Environment**: `docker-compose up -d`
2. **Run Setup**: `./bin/setup-site-simple.sh`
3. **Access Site**: <http://localhost:8080>
4. **Make Changes**: Edit files in wp-content/
5. **Test Changes**: Verify functionality
6. **Commit Changes**: Git workflow

### Content Management

- **Theme Files**: `wp-content/themes/`
- **Plugin Files**: `wp-content/plugins/`
- **Media Files**: `wp-content/uploads/`
- **Custom Code**: `components/` directory

### Database Management

- **Access**: phpMyAdmin at <http://localhost:8081>
- **Backups**: Automated via UpdraftPlus plugin
- **Migration**: WP-CLI tools available in container

---

## 🎯 Next Steps

### Immediate Actions

1. **Complete WordPress Installation**: Visit <http://localhost:8080/wordpress/>
2. **Configure Database**: Use credentials from .env file
3. **Activate Theme**: Upload and activate your theme
4. **Configure Plugins**: Set up essential plugins

### Development Roadmap

1. **Week 1**: Complete WordPress setup and theme configuration
2. **Week 2**: Content migration and plugin configuration
3. **Week 3**: Performance optimization and testing
4. **Week 4**: Security audit and production preparation

### Maintenance Schedule

- **Daily**: Monitor logs and performance
- **Weekly**: Update plugins and run security scans
- **Monthly**: Database optimization and backup verification
- **Quarterly**: Security audit and documentation updates

---

## 🆘 Troubleshooting

### Common Issues

#### Site Not Loading

```bash
# Check container status
docker-compose ps

# Check logs
docker-compose logs wordpress

# Restart containers
docker-compose restart
```

#### Database Connection Issues

```bash
# Verify database is running
docker-compose exec mysql mysqladmin ping

# Check credentials in .env
cat .env

# Reset database connection
docker-compose restart mysql
```

#### Permission Issues

```bash
# Fix WordPress permissions
docker-compose exec wordpress chown -R www-data:www-data /var/www/html
docker-compose exec wordpress chmod -R 755 /var/www/html
```

#### Plugin Issues

```bash
# Check plugin status
docker-compose exec wordpress wp plugin list --allow-root

# Deactivate problematic plugin
docker-compose exec wordpress wp plugin deactivate plugin-name --allow-root
```

### Support Resources

- **Project Documentation**: All files in `docs/` directory
- **WordPress Codex**: <https://codex.wordpress.org/>
- **Docker Documentation**: <https://docs.docker.com/>
- **Composer Documentation**: <https://getcomposer.org/doc/>

---

## 📝 Project History

### Major Milestones ✅

- **August 18, 2025**: Docker environment created and configured
- **August 19, 2025**: Composer integration and plugin management implemented
- **August 20, 2025**: Security hardening and documentation consolidation
- **August 20, 2025**: File structure optimization and script automation

### Technical Achievements

- Reduced from 30+ loose files to organized containerized structure
- Implemented modern PHP dependency management
- Applied comprehensive security hardening
- Created automated setup and maintenance scripts
- Established professional development workflow

---

**🎉 Your Legacy Concierge WordPress environment is production-ready!**

Visit **<http://localhost:8080>** to complete the WordPress installation and begin development.

For detailed technical information, see the specific documentation files in the `docs/` directory.
