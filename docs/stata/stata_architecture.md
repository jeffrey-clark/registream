# RegiStream Stata Architecture

**Version:** 2.0.0
**Last Updated:** 2025-10-21

This document explains the internal architecture of the RegiStream Stata client for developers maintaining or extending the codebase.

---

## Table of Contents

- [Overview](#overview)
- [File Organization](#file-organization)
- [Wrapper System](#wrapper-system)
- [Core Systems](#core-systems)
- [Execution Flow](#execution-flow)
- [Module Reference](#module-reference)
- [Architecture Diagram](#architecture-diagram)

---

## Overview

The RegiStream Stata client is built around a **wrapper architecture** that ensures every command runs through consistent initialization and cleanup.

### Key Design Principles

1. **Universal Wrapping**: Every user-facing command is wrapped with initialization and cleanup logic
2. **Auto-Initialization**: Config, usage tracking, and updates are initialized automatically
3. **Fail-Safe Defaults**: Missing config files are recreated, network errors don't crash commands
4. **Modular Design**: Distinct modules for config, usage tracking, updates, and utilities
5. **Version Agnostic**: Same code works in dev (with version override) and production (with {{VERSION}} placeholder)

---

## File Organization

### User-Facing Commands

```
stata/src/
├── registream.ado          # Main command: registream {update|info|config|version|cite}
└── autolabel.ado            # Main command: autolabel {variables|values|lookup|info|...}
```

### Internal Modules

```
stata/src/
├── _rs_config.ado           # Config management (YAML operations)
├── _rs_usage.ado        # Usage logging and usage tracking
├── _rs_updates.ado          # Package & dataset update checks
├── _rs_utils.ado            # Core utilities (OS detection, prompts, API host)
├── _rs_autolabel_utils.ado  # Autolabel-specific utilities (download, merge, verify)
└── _rs_validate_schema.ado  # Schema 1.0 validation
```

### Development Files (Git-Ignored)

```
stata/src/
├── _rs_dev_utils.ado.template  # Template for dev override (copy to _rs_dev_utils.ado)
└── _rs_dev_utils.ado           # Git-ignored dev overrides (localhost API, version, test globals)
```

**Purpose:** Override production defaults for local development and testing without modifying source code.

---

## Wrapper System

### The Four Wrappers

RegiStream uses **4 wrapper functions** (2 pairs) that wrap every command:

| File | Function | Purpose |
|------|----------|---------|
| `registream.ado` | `_registream_wrapper_start` | Initialize before registream commands |
| `registream.ado` | `_registream_wrapper_end` | Cleanup after registream commands |
| `autolabel.ado` | `_autolabel_wrapper_start` | Initialize before autolabel commands |
| `autolabel.ado` | `_autolabel_wrapper_end` | Cleanup after autolabel commands |

### Wrapper Flow

Every command follows this pattern:

```
User Command
    ↓
[WRAPPER START]
├─ Get registream directory (~/.registream)
├─ Initialize config (creates if missing)
├─ Initialize usage tracking
├─ Log command usage
└─ Run background update check (24h cache)
    ↓
[ACTUAL COMMAND LOGIC]
    ↓
[WRAPPER END]
└─ Show update notification (if available)
```

### Why Wrappers?

Wrappers implement the DRY principle: initialization code is written once and applied consistently to all commands. This ensures every command gets config auto-creation, usage tracking logging, and update checks without duplicating code. It also provides easy testing through global variable overrides.

---

## Core Systems

### 1. Config System (`_rs_config.ado`)

**Purpose:** Manage `~/.registream/config.yaml`

**Key Functions:**
- `init` - Create config if missing (includes first-run setup prompt for SSC compliance)
- `get` - Read value, return in `r(value)`
- `set` - Write value

**Config Structure:**
```yaml
# RegiStream Configuration
telemetry_enabled: true
internet_access: true
auto_update_check: true
last_update_check: 20 Oct 2025T17:38:19Z
update_available: false
latest_version: 2.0.0
```

**First-Run Behavior:** If config doesn't exist, shows interactive prompt for user to choose Offline Mode or Full Mode. This ensures SSC compliance (no internet connections without explicit user consent).

**Testing Mode:** When `$REGISTREAM_AUTO_APPROVE = "yes"`, prompt is skipped and full mode defaults are used.

---

### 2. Usage Tracking System (`_rs_usage.ado`)

**Purpose:** Log command usage to `~/.registream/usage_stata.csv`

**Key Functions:**
- `init` - Create CSV if missing
- `log` - Append command log
- `enable/disable` - Toggle online telemetry
- `stats` - Show usage stats
- `export` - Export usage data

**CSV Format:**
```csv
timestamp,command,version,os,stata_version
2025-10-20T17:38:19Z,autolabel variables,2.0.0,darwin,16.0
```

**Privacy:** Logs only command type (not arguments or data), stays local on user's machine. See [usage_tracking.md](../../usage_tracking.md) for complete documentation.

---

### 3. Update Check System (`_rs_updates.ado`)

**Purpose:** Check for package and dataset updates

**Key Functions:**
- `check_package` - Check package version (foreground, interactive)
- `check_background` - Check package version (background, silent, 24h cache)
- `show_notification` - Display update banner if available
- `update_datasets_interactive` - Interactive dataset update workflow

**24-Hour Caching:** Update checks are expensive, so they're cached in config. Background checks only run if >24 hours elapsed since last check.

**Persistent Notifications:** Update notification shows after every command until user updates. This is intentional to encourage updates.

---

### 4. Utilities System (`_rs_utils.ado`)

**Purpose:** Core utility functions used across all modules

**Key Functions:**
- `get_dir` - Get registream directory (OS-aware: `~/.registream` or `%USERPROFILE%\.registream`)
- `get_api_host` - Get API host (2-level priority: dev override → production)
- `get_version` - Get RegiStream version (2-level priority: dev override → production)
- `prompt` - Interactive yes/no prompt (auto-approved in dev/test mode)
- `prompt_choice` - Multi-choice prompt (auto-selects option 1 in dev/test mode)
- `confirmdir` - Check if directory exists
- `del_folder_rec` - Recursive folder delete
- `escape_ascii` - Escape special characters

#### Version and API Host Resolution (2-Level Priority System)

**Priority order (highest to lowest):**
1. **Dev mode:** `_rs_dev_utils` (git-ignored, only exists on developer machines)
2. **Production:** Hardcoded values (shipped to users)

**How it works:**
```stata
* In _rs_utils.ado (line 395-406):
cap qui _rs_dev_utils get_version
if (_rc == 0) {
    return local version "`r(version)'"  // Dev override found
}
else {
    return local version "{{VERSION}}"   // Production (replaced during export)
}
```

**Production values (hardcoded in ONE location each):**
- **Version:** `{{VERSION}}` in `_rs_utils.ado` line 405 (replaced during package export)
- **API Host:** `https://registream.org` in `_rs_utils.ado` line 195

**Dev overrides (in `_rs_dev_utils.ado`, git-ignored):**
- **Version:** `2.0.0` (or `$REGISTREAM_TEST_VERSION` if set)
- **API Host:** `http://localhost:5000` (or `$REGISTREAM_TEST_HOST` if set)

**Security:** Users cannot affect behavior - `_rs_dev_utils.ado` never ships with the package. Test globals only work for developers who have the dev file.

---

### 5. Autolabel Utilities (`_rs_autolabel_utils.ado`)

**Purpose:** Functions specific to autolabel operations

**Key Functions:**
- `download_extract` - Download and extract metadata
- `append_csv` - Merge chunked CSV files
- `fetch_with_errors` - Download with smart error handling
- `store_dataset_metadata` - Save to `datasets.csv`
- `get_dataset_version` - Read from `datasets.csv`
- `check_for_updates` - Check dataset updates (24h cache)
- `verify_file_integrity` - Check file corruption
- `get_latest_version_from_api` - Query API `/info` endpoint
- `validate_domain_language_offline` - Offline validation via `datasets.csv`

**Metadata Tracking:** Maintains `~/.registream/autolabel_keys/datasets.csv` with download history, versions, and checksums.

**File Integrity Checks:** Detects missing files, missing metadata, and size mismatches (>5% difference triggers corruption warning).

---

### 6. Validation System (`_rs_validate_schema.ado`)

**Purpose:** Validate that datasets conform to Schema 1.0

**Usage:** `_rs_validate_schema, type(variables|values)`

**Checks:**
- Required columns for each type
- Valid data types
- Format compliance

**Behavior:** Errors and exits if validation fails.

---

## Execution Flow

### Flow 1: Simple Command (registream version)

1. User runs `registream version`
2. `_registream_wrapper_start` initializes config, usage tracking, runs background update check
3. Command displays version
4. `_registream_wrapper_end` shows update notification if available

### Flow 2: Complex Command (autolabel variables)

1. User runs `autolabel variables, domain(scb) lang(eng)`
2. `_autolabel_wrapper_start` initializes config, usage tracking, runs background update check
3. Command verifies file integrity → checks for updates → downloads if needed
4. Command applies labels to dataset
5. `_autolabel_wrapper_end` shows update notification if available

### Flow 3: Config Auto-Creation

1. User deletes `~/.registream/config.yaml`
2. User runs any command
3. `_registream_wrapper_start` calls `_rs_config init`
4. Config detects missing file, shows first-run setup prompt
5. User selects mode, config is created
6. Command continues normally

---

## Module Reference

### registream.ado

**User-facing commands:**
- `registream update [package|dataset|datasets]` - Check/apply updates
- `registream info` - Show configuration
- `registream config, <option>` - Edit configuration
- `registream version` - Show version
- `registream cite` - Show citation
- `registream stats [all]` - Show usage statistics

**Routing:** Parses subcommand and routes to appropriate internal function. All commands wrapped with `_registream_wrapper_start/end`.

---

### autolabel.ado

**User-facing commands:**
- `autolabel variables <varlist>, domain() lang()` - Label variables
- `autolabel values <varlist>, domain() lang()` - Label values (encode)
- `autolabel lookup <varlist>, domain() lang()` - Lookup definitions
- `autolabel info/update/version/cite` - Aliases to registream commands

**Routing:** Handles both aliases to registream commands and autolabel-specific operations. All commands wrapped with `_autolabel_wrapper_start/end`.

---

### _rs_config.ado

**Subcommands:**
- `init` - Create config if missing (shows first-run prompt)
- `get` - Read value (returns in `r(value)` and `r(found)`)
- `set` - Write value

**Implementation:** Uses Stata file I/O to read/write YAML format.

---

### _rs_usage.ado

**Subcommands:**
- `init` - Create CSV if missing
- `log` - Append log entry
- `enable/disable` - Toggle online telemetry
- `stats` - Display usage stats
- `export` - Export to user-specified file
- `send_online` - Send anonymized data to API (requires `telemetry_enabled=true` AND `internet_access=true`)

**Implementation:** Appends to CSV using file I/O.

---

### _rs_updates.ado

**Subcommands:**
- `check_package` - Check package version (foreground, interactive)
- `check_background` - Check package version (background, silent, 24h cache)
- `show_notification` - Display update banner if available
- `update_datasets_interactive` - Interactive dataset update workflow

**Implementation:** Parses semantic versions, compares major.minor.patch, sets globals for notification system.

---

### _rs_utils.ado

**Subcommands:**
- `get_dir` - Get registream directory (OS-aware)
- `get_api_host` - Get API host (prod vs dev)
- `prompt` - Yes/no prompt
- `prompt_choice` - Multi-choice prompt
- `confirmdir` - Check directory exists
- `del_folder_rec` - Recursive delete
- `escape_ascii` - Escape special characters

**Implementation:** OS detection via `c(os)`, environment variable checking, interactive prompts.

---

### _rs_autolabel_utils.ado

**Key subcommands:**
- `download_extract` - Download and extract ZIP
- `verify_file_integrity` - Integrity checks (missing files, metadata, size mismatch)
- `check_for_updates` - Check dataset updates (24h cache)
- `store_dataset_metadata` - Write to `datasets.csv`
- `validate_domain_language_offline` - Offline validation via local metadata

**Implementation:** Downloads via `copy` command, unzips, merges chunked CSVs, tracks metadata in `datasets.csv`.

---

### _rs_validate_schema.ado

**Usage:** `_rs_validate_schema, type(variables|values)`

**Variables Schema:**
- Required: `variable_name`, `variable_label`, `variable_type`
- Optional: `variable_definition`, `variable_unit`, `value_label_id`
- Valid types: `categorical`, `continuous`, `text`, `date`, `binary`

**Values Schema:**
- Required: `variable_name`, `value_label_id`, `value_labels_stata`
- Format: `value_labels_stata` contains space-separated quoted pairs

**Implementation:** Checks column existence and data types, errors if validation fails.

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                      User Commands                          │
│  registream {update|info|config|version|cite}               │
│  autolabel {variables|values|lookup|info|...}               │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
         ┌─────────────────────────────┐
         │   Wrapper Start             │
         │  (Every Command)            │
         ├─────────────────────────────┤
         │ • Get registream dir        │
         │ • Init config (auto-create) │
         │ • Init usage tracking            │
         │ • Log command               │
         │ • Background update check   │
         └──────────┬──────────────────┘
                    │
                    ▼
         ┌─────────────────────────────┐
         │   Command Logic             │
         │  (Subprograms)              │
         ├─────────────────────────────┤
         │ • Route to subcommand       │
         │ • Execute business logic    │
         │ • Call utilities as needed  │
         └──────────┬──────────────────┘
                    │
                    ▼
         ┌─────────────────────────────┐
         │   Wrapper End               │
         │  (Every Command)            │
         ├─────────────────────────────┤
         │ • Show update notification  │
         └─────────────────────────────┘
                    │
                    ▼
         ┌─────────────────────────────────────────┐
         │        Core Systems (Modules)           │
         ├─────────────────────────────────────────┤
         │                                         │
         │  ┌─────────────────────────────────┐   │
         │  │ _rs_config.ado                  │   │
         │  │ • YAML read/write               │   │
         │  │ • Auto-create defaults          │   │
         │  └─────────────────────────────────┘   │
         │                                         │
         │  ┌─────────────────────────────────┐   │
         │  │ _rs_usage.ado               │   │
         │  │ • CSV append logging            │   │
         │  │ • Stats & export                │   │
         │  └─────────────────────────────────┘   │
         │                                         │
         │  ┌─────────────────────────────────┐   │
         │  │ _rs_updates.ado                 │   │
         │  │ • Version comparison            │   │
         │  │ • 24h cache                     │   │
         │  │ • Interactive updater           │   │
         │  └─────────────────────────────────┘   │
         │                                         │
         │  ┌─────────────────────────────────┐   │
         │  │ _rs_utils.ado                   │   │
         │  │ • OS detection                  │   │
         │  │ • API host resolution           │   │
         │  │ • Prompts, file ops             │   │
         │  └─────────────────────────────────┘   │
         │                                         │
         │  ┌─────────────────────────────────┐   │
         │  │ _rs_autolabel_utils.ado         │   │
         │  │ • Download & extract            │   │
         │  │ • Metadata tracking             │   │
         │  │ • File integrity checks         │   │
         │  └─────────────────────────────────┘   │
         │                                         │
         │  ┌─────────────────────────────────┐   │
         │  │ _rs_validate_schema.ado         │   │
         │  │ • Schema 1.0 validation         │   │
         │  └─────────────────────────────────┘   │
         │                                         │
         └─────────────────────────────────────────┘
                    │
                    ▼
         ┌─────────────────────────────┐
         │   External Resources        │
         ├─────────────────────────────┤
         │ • ~/.registream/config.yaml │
         │ • ~/.registream/usage_stata.csv   │
         │ • ~/.registream/autolabel_keys/  │
         │ • API: registream.org       │
         └─────────────────────────────┘
```

---

## Development Notes

### Version and API Host Management

**Production:** Hardcoded in `_rs_utils.ado` (ONE place)
- Version: `{{VERSION}}` (line 425, replaced by export script)
- API host: `https://registream.org` (line 203)

**Development:** Override via `_rs_dev_config.ado` (ONE place, git-ignored)
- Defines `_rs_get_dev_version` returning "2.0.0"
- Defines `_rs_get_dev_host` returning "http://localhost:5000"
- Auto-loaded by utility functions when it exists

See [version_management.md](version_management.md) for complete documentation.

### Testing

Test suite located in `stata/tests/`. Run via `stata -b do stata/tests/run_all_tests.do`. Tests override behavior via:
- `_rs_get_dev_version` - Program redefinition (defined in `run_all_tests.do`)
- `$REGISTREAM_AUTO_APPROVE` - Global for skipping prompts
- `$REGISTREAM_API_HOST` - Global for localhost (set by test suite)

See [stata/tests/README.md](../../stata/tests/README.md) for test documentation.

### Best Practices

1. **Always use wrappers** - Never bypass wrapper system for user-facing commands
2. **Use utilities for common tasks** - Don't reinvent OS detection, API host resolution, etc.
3. **Respect config settings** - Always check config before optional behavior (internet access, usage tracking)
4. **Return values consistently** - Use `rclass` and return values
5. **Handle errors gracefully** - Use `cap` for network operations, provide user-friendly error messages

---

**Last Updated:** 2025-10-21
**Version:** 2.0.0
