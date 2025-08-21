# Changelog

All notable changes to **Legacy Concierge WordPress** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.2] - 2025-08-21

### Changed

- **BREAKING**: Renamed WordPress installation directory from `/wordpress/` to `/legacy-concierge/`
- Updated all script references to use new `/legacy-concierge/` directory path
- Updated Composer installation path for WordPress core to `/legacy-concierge/`
- Updated `.gitignore` to ignore `/legacy-concierge/` directory instead of `/wordpress/`
- Updated all shell scripts (`project-setup.sh`, `status.sh`, `clean-repo.sh`, `deploy.sh`, `maintenance.sh`, `git-workflow.sh`) with new directory paths
- Updated package.json version to 1.0.2

### Fixed

- Corrected all hardcoded `/wordpress/` path references in maintenance and deployment scripts
- Fixed symlink creation in project setup to point to correct directory structure
- Updated backup and archive creation to include correct directory paths

## [1.0.1] - 2025-08-21

### Fixed

- Resolved "Error establishing a database connection" issues
- Fixed WordPress configuration path resolution for subdirectory installation
- Corrected wp-config.php file paths for .env loading and vendor autoloader
- Fixed ABSPATH constant redefinition warning
- Updated Docker healthcheck to properly monitor WordPress in /wordpress/ subdirectory
- Resolved 500 internal server errors and PHP parse errors

### Changed

- WordPress now properly serves from both root (/) and `/wordpress/` paths
- Simplified wp-config.php configuration for better reliability
- Updated site URLs to support both `http://localhost:8080` and `http://localhost:8080/legacy-concierge/`

## [1.0.0] - 2025-08-21

### Added

- Initial WordPress project setup with modern development workflow
- Docker containerized environment with MySQL 8.0 and phpMyAdmin
- Composer-managed WordPress core and plugin dependencies
- Professional CI/CD pipeline with GitHub Actions
- Comprehensive shell scripts for project management and maintenance
- Modern "ignore by default" Git strategy for clean repository structure
- Environment-based configuration with .env files
- Automated database import and URL configuration for local development

### Fixed

- Docker networking configuration for proper container communication
- Database connectivity issues with correct user permissions
- WordPress healthcheck configuration for container monitoring
- Site URL configuration for localhost:8080 development environment

### Changed

- Repository structure to follow modern WordPress development practices
- Database configuration to use imported production data structure
- WordPress configuration to support containerized development environment

---

**Note**: This changelog reflects the complete setup of the Legacy Concierge WordPress development environment
