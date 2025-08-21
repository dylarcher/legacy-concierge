# Changelog

All notable changes to **Legacy Concierge WordPress** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
