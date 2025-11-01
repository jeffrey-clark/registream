# Changelog

## [2.0.2] - 2025-11-01

### Bug Fixes
- Fixed JSON regex parsing incompatibility (Stata doesn't support POSIX character classes)
- Fixed file read pattern causing empty API responses
- All API endpoints now return Stata-optimized format

### Improvements
- Added `format=stata` API parameter support (simple key=value parsing)
- Replaced complex JSON regex with line-by-line parsing
- Native Stata `copy` command for downloads (removed shell curl dependencies)

### Infrastructure
- Separated config files by platform (`config_stata.yaml`) for future R/Python packages

## [2.0.1] - 2025-11-01

### Bug Fixes
- Fixed critical bug preventing specific version downloads with `version()` parameter
- Fixed parameter passing (added quotes for domain/lang/version)
- Fixed integrity check to only override when version is 'latest'
- Changed integrity check from 5% tolerance to exact byte match

### Improvements
- Better 'already at version' UX message
- Standardized horizontal lines to 60 dashes

## [2.0.0] - 2025-10-21

### Major Release
- API v1 migration with RESTful endpoints
- Schema 1.0 support with improved column names
- New `registream` command suite (info, config, update, stats, version, cite)
- Three-mode configuration (Offline/Standard/Full) with first-run setup
- Usage tracking with optional telemetry
- Automatic update checks with 24-hour caching
- File integrity verification and metadata tracking

### Breaking Changes
- Schema 1.0 required - users must re-download datasets
- Column renamed: `variable` → `variable_name`

## [1.0.1] - 2025-01-14

### Changes
- Migrated API host from registream.com to registream.org
- Fixed CSV apostrophe parsing in autolabel command

## [1.0.0] - 2024-09-28

### Initial Release
- Automatic variable and value labeling from SCB metadata
- Support for English and Swedish languages
- Schema v0.5 with basic metadata structure
