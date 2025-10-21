# Stata-Specific Documentation

This directory contains documentation specific to the RegiStream Stata client implementation.

## Documents

### [development.md](development.md)
**For:** Stata package developers and contributors

**Contents:**
- Version management system (function-based override pattern)
- Local API testing setup
- Development mode configuration
- Flask API integration
- Testing workflow

**Key Topics:**
- How `_rs_utils get_version` works
- Setting up `_rs_dev_config.ado` from template
- Testing against localhost API
- Dev mode vs. production mode

---

### [version_management.md](version_management.md)
**For:** Quick reference guide

**Contents:**
- TL;DR setup (2 steps)
- How the function-based system works
- Benefits over alternatives (globals, code stripping)
- Quick commands and examples
- Migration guide from v1.x

**Perfect for:** Getting started quickly or as a cheat sheet

---

### [stata_architecture.md](stata_architecture.md)
**For:** Developers maintaining or extending the Stata codebase

**Contents:**
- Internal architecture overview
- File organization
- Wrapper system design
- Core systems (config, usage tracking, updates, validation)
- Module reference
- Execution flow diagrams

**Key Topics:**
- Entry points (`registream.ado`, `autolabel.ado`)
- Helper modules (prefixed with `_rs_`)
- How wrappers handle usage tracking and update checks
- Command routing and subcommand structure

---

## General Documentation

For documentation that applies to all clients (Stata, Python, R), see the parent `docs/` directory:

- **[client_guide.md](../client_guide.md)** - Guide for building clients that consume the RegiStream API
- **[api_documentation.md](../api_documentation.md)** - API v1 endpoint reference
- **[schema.md](../schema.md)** - Data schema specifications
- **[metadata_system.md](../metadata_system.md)** - Metadata format and usage
- **[usage_tracking.md](../usage_tracking.md)** - Usage tracking system specification

---

## Quick Links

### For New Stata Developers

1. Start with [development.md](development.md) - Set up your dev environment
2. Read [stata_architecture.md](stata_architecture.md) - Understand the codebase
3. Check [../client_guide.md](../client_guide.md) - Learn the API

### For Package Export

1. Ensure `_rs_dev_config.ado` is gitignored
2. Verify `_rs_dev_config.ado.template` is included
3. Run `export_stata_package.py` which replaces `{{VERSION}}`
4. Test exported package in clean environment

---

**Last Updated:** 2025-10-21
