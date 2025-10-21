# Version and API Host Management System

**Quick Reference for Developers**

## TL;DR

RegiStream uses a **function-based override system** for version and API host:

```stata
* Production: _rs_utils get_version returns "{{VERSION}}"
*             _rs_utils get_api_host returns "https://registream.org"
* Development: _rs_dev_config.ado defines override functions
```

**Setup in 1 step:**
```bash
cd ~/Github/registream
cp stata/src/_rs_dev_config.ado.template stata/src/_rs_dev_config.ado
```

Done! Your Stata commands now use:
- Dev version: `2.0.0` (instead of `{{VERSION}}`)
- Dev API host: `http://localhost:5000` (instead of `https://registream.org`)

---

## How It Works

### The Helper Functions (Production)

**File:** `_rs_utils.ado` (shipped to production)

**Hardcoded production values in ONE place:**

```stata
program define _utils_get_version, rclass
    * Auto-loads _rs_dev_config.ado if it exists
    * Then tries to call _rs_get_dev_version
    cap qui _rs_get_dev_version
    if (_rc == 0) {
        return local version "`r(version)'"  # Dev mode
    }
    else {
        return local version "{{VERSION}}"   # Production (line 425)
    }
end

program define _utils_get_api_host, rclass
    * Auto-loads _rs_dev_config.ado if it exists
    * Then tries to call _rs_get_dev_host
    cap qui _rs_get_dev_host
    if (_rc == 0) {
        return local host "`r(host)'"               # Dev mode
    }
    else {
        return local host "https://registream.org"  # Production (line 203)
    }
end
```

### The Dev Override (Development)

**File:** `_rs_dev_config.ado` (gitignored, copy from .template)

**Override values in ONE place:**

```stata
* Override version (called by _rs_utils get_version)
cap program drop _rs_get_dev_version
program define _rs_get_dev_version, rclass
    return local version "2.0.0"
end

* Override API host (called by _rs_utils get_api_host)
cap program drop _rs_get_dev_host
program define _rs_get_dev_host, rclass
    return local host "http://localhost:5000"
end
```

### Entry Points

**All commands use the utility functions:**

```stata
program define registream
    version 16.0

    * Get version (auto-loads dev config if it exists)
    _rs_utils get_version
    local REGISTREAM_VERSION "`r(version)'"

    * Get API host (auto-loads dev config if it exists)
    _rs_utils get_api_host
    local api_host "`r(host)'"

    * Use throughout command...
end
```

**No manual loading needed** - `_rs_dev_config.ado` is auto-loaded by the utility functions!

---

## Benefits

### vs. Global Variables

❌ **Old way (risky):**
```stata
* End users could accidentally set this!
global REGISTREAM_VERSION "1.0.0"
```

✅ **New way (safe):**
```stata
* Internal function - users can't interfere
_rs_utils get_version
```

### vs. Code Stripping

❌ **Old way (complex build):**
```stata
* {{DEV}}
if (dev_mode) {
    local version "2.0.0"
}
* {{DEV}}
else {
    local version "{{VERSION}}"
}
```
Requires build script to remove lines between `{{DEV}}` tags.

✅ **New way (simple build):**
```stata
* Just try to call dev function
cap qui _rs_get_dev_version
if (_rc == 0) {
    * Dev function exists
}
```
Only need to replace `{{VERSION}}` placeholder. No line removal.

---

## Quick Commands

### Check Current Version
```stata
registream version
autolabel version
```

### Test Version Management
```bash
# Run full test suite (includes version tests)
cd ~/Github/registream
stata -b do stata/tests/run_all_tests.do

# Or run specific version test
stata -b do stata/tests/dofiles/08_version_and_cite_commands.do
```

### Customize Dev Version
Edit `stata/src/_rs_dev_config.ado`:
```stata
cap program drop _rs_get_dev_version
program define _rs_get_dev_version, rclass
    return local version "2.1.0-alpha"
end
```

### Disable Dev Mode
```bash
# Option 1: Rename
mv stata/src/_rs_dev_config.ado stata/src/_rs_dev_config.ado.disabled

# Option 2: Delete
rm stata/src/_rs_dev_config.ado
```

---

## Architecture Flow

```
Production Package Export:
  1. _rs_dev_config.ado is gitignored (never shipped)
  2. export_stata_package.py replaces {{VERSION}} with "2.0.0" in _rs_utils.ado
  3. Users receive: _rs_utils get_version returns "2.0.0"
                    _rs_utils get_api_host returns "https://registream.org"
  4. No _rs_dev_config.ado exists → no override functions → uses hardcoded values

Development:
  1. Developer copies _rs_dev_config.ado.template → _rs_dev_config.ado
  2. It defines _rs_get_dev_version and _rs_get_dev_host
  3. When _rs_utils get_version is called:
     - Auto-loads _rs_dev_config.ado (first time only)
     - Tries _rs_get_dev_version → succeeds → returns "2.0.0"
  4. When _rs_utils get_api_host is called:
     - Auto-loads _rs_dev_config.ado (already loaded)
     - Tries _rs_get_dev_host → succeeds → returns "http://localhost:5000"
```

---

## For Test Suites

Tests can completely redefine `_rs_utils get_version`:

```stata
* In test file
cap program drop _rs_utils get_version
program define _rs_utils get_version, rclass
    return local version "99.99.99"
end

* All commands now use test version
registream version
* Output: RegiStream version 99.99.99
```

This is cleaner than using globals and gives full control.

---

## Migration Guide

### From Global-Based (v1.x)

**Before:**
```stata
if ("$REGISTREAM_DEV_VERSION" != "") {
    local version "$REGISTREAM_DEV_VERSION"
}
else if ("$REGISTREAM_VERSION" != "") {
    local version "$REGISTREAM_VERSION"
}
else {
    local version "{{VERSION}}"
}
```

**After:**
```stata
_rs_utils get_version
local version "`r(version)'"
```

**Benefits:**
- 3 lines instead of 9
- No global variable checks
- Safer (users can't interfere)
- Easier to understand

---

## Files Reference

```
stata/src/
├── _rs_utils.ado                    # Helper functions (shipped)
│                                    # - Line 425: return local version "{{VERSION}}"
│                                    # - Line 203: return local host "https://registream.org"
├── _rs_dev_config.ado.template      # Template for devs (shipped)
│                                    # Defines: _rs_get_dev_version, _rs_get_dev_host
├── _rs_dev_config.ado               # Dev config (gitignored, copy from template)
├── registream.ado                   # Uses _rs_utils get_version, get_api_host
├── autolabel.ado                    # Uses _rs_utils get_version
└── _rs_usage.ado                    # Uses _rs_utils get_api_host (for telemetry)

stata/tests/
└── run_all_tests.do                 # Redefines _rs_get_dev_version for testing
```

**Architecture summary:**
- **Production values:** Hardcoded in `_rs_utils.ado` (ONE place)
- **Dev overrides:** Defined in `_rs_dev_config.ado` (ONE place)
- **No globals:** All values passed via return locals
- **Auto-loading:** Dev config loaded automatically when needed

---

**See also:** [development.md](development.md) for complete development guide

**Last Updated:** 2025-10-21
