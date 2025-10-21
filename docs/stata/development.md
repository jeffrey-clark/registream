# RegiStream Stata Development Guide

## Table of Contents

- [Development Override System](#development-override-system)
- [Local API Testing](#local-api-testing)
- [Test Suite](#test-suite)

---

## Development Override System

RegiStream uses a **2-level priority system** for version and API host that allows developers to work with localhost and test different versions without modifying source code.

### Overview

- ✅ **2-level priority:** Dev override → Production hardcoded
- ✅ **Single source of truth:** Production values hardcoded in `_rs_utils.ado` (ONE location each)
- ✅ **Single override file:** Dev overrides in `_rs_dev_utils.ado` (ONE location, git-ignored)
- ✅ **Dynamic testing:** Use `$REGISTREAM_TEST_VERSION` and `$REGISTREAM_TEST_HOST` globals for testing
- ✅ **Safe:** Users cannot access dev overrides (file never ships with package)
- ✅ **Auto-reload:** All subprograms have `cap program drop` statements for easy reloading

### How It Works

#### Production Mode (Hardcoded in `_rs_utils.ado`)

```stata
* In _rs_utils.ado (line 395-406):
cap program drop _utils_get_version
program define _utils_get_version, rclass
    cap qui _rs_dev_utils get_version
    if (_rc == 0) {
        return local version "`r(version)'"  // Dev override
    }
    else {
        return local version "{{VERSION}}"   // Production (line 405)
    }
end

* In _rs_utils.ado (line 185-197):
cap program drop _utils_get_api_host
program define _utils_get_api_host, rclass
    cap qui _rs_dev_utils get_host
    if (_rc == 0) {
        return local host "`r(host)'"               // Dev override
    }
    else {
        return local host "https://registream.org"  // Production (line 195)
    }
end
```

**Production behavior:** `_rs_dev_utils` doesn't exist → `cap qui` fails → returns hardcoded values.

#### Development Mode (Override in `_rs_dev_utils.ado`)

Copy the template to enable dev mode:
```bash
cp stata/src/_rs_dev_utils.ado.template stata/src/_rs_dev_utils.ado
```

The dev file mirrors `_rs_utils` structure with subcommands:

```stata
* In _rs_dev_utils.ado:
cap program drop _rs_dev_utils
program define _rs_dev_utils, rclass
    version 16.0
    gettoken subcmd 0 : 0, parse(" ,")

    if ("`subcmd'" == "get_version") {
        * For testing: can override with $REGISTREAM_TEST_VERSION
        if ("$REGISTREAM_TEST_VERSION" != "") {
            return local version "$REGISTREAM_TEST_VERSION"
        }
        else {
            return local version "2.0.0"  // Dev default
        }
    }
    else if ("`subcmd'" == "get_host") {
        * For testing: can override with $REGISTREAM_TEST_HOST
        if ("$REGISTREAM_TEST_HOST" != "") {
            return local host "$REGISTREAM_TEST_HOST"
        }
        else {
            return local host "http://localhost:5000"  // Dev default
        }
    }
end
```

**Dev behavior:** `_rs_dev_utils` exists → `cap qui` succeeds → returns dev values.

### Testing with Globals

For test suites, set globals to override dev defaults dynamically:

```stata
* Test with custom version
global REGISTREAM_TEST_VERSION "99.9.9-TEST"
_rs_utils get_version  // Returns: 99.9.9-TEST

* Test with custom API host
global REGISTREAM_TEST_HOST "http://test-server:9999"
_rs_utils get_api_host  // Returns: http://test-server:9999

* Clear globals to restore dev defaults
global REGISTREAM_TEST_VERSION ""
global REGISTREAM_TEST_HOST ""
```

**Security:** Test globals only work when `_rs_dev_utils.ado` exists (developers only).

All commands call the helper functions to get version and API host:

```stata
program define registream
    version 16.0

    * Get version (auto-loads dev config if it exists)
    _rs_utils get_version
    local REGISTREAM_VERSION "`r(version)'"

    * Get API host (dev config already loaded)
    _rs_utils get_api_host
    local api_host "`r(host)'"

    * Use throughout command...
end
```

**No manual loading needed** - the utility functions auto-load `_rs_dev_config.ado` if it exists.

The same pattern is used in:
- `registream.ado` (uses both version and API host)
- `autolabel.ado` (uses version and API host)
- `_rs_usage.ado` (uses API host for telemetry)
- `_rs_updates.ado` (uses API host for update checks)

### Setting Up Development Mode

1. **Copy the template (ONE file):**
   ```bash
   cd ~/Github/registream
   cp stata/src/_rs_dev_config.ado.template stata/src/_rs_dev_config.ado
   ```

2. **Customize if needed (optional):**
   ```stata
   * In _rs_dev_config.ado, edit the override functions:

   cap program drop _rs_get_dev_version
   program define _rs_get_dev_version, rclass
       return local version "2.1.0-alpha"  # Your custom version
   end

   cap program drop _rs_get_dev_host
   program define _rs_get_dev_host, rclass
       return local host "http://localhost:8000"  # Your custom port
   end
   ```

3. **Git ignores your copy** - The `.gitignore` file ensures `_rs_dev_config.ado` is never committed

### Test Mode Override

For automated testing, test suites can redefine `_rs_utils get_version` directly:

```stata
* In test file
cap program drop _rs_get_version
program define _rs_get_version, rclass
    return local version "99.99.99"
end

* Now all commands use test version
registream version
* Output: RegiStream version 99.99.99
```

### Benefits Over Alternatives

#### Compared to Global Variables

**Old approach (global-based):**
```stata
* Risk: End users could accidentally set this
global REGISTREAM_VERSION "1.0.0"
```

**New approach (function-based):**
```stata
* Safe: End users can't interfere with internal function
_rs_utils get_version
```

#### Compared to Code Stripping

**Old approach (code stripping):**
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
Requires build-time code removal between `{{DEV}}` tags.

**New approach (file existence):**
```stata
* No tags needed - just try to call dev function
cap qui _rs_get_dev_version
if (_rc == 0) {
    * Dev function exists
}
```
Simpler export process - only replace `{{VERSION}}`, no line removal.

### Verification

Test the complete development setup:

```bash
cd ~/Github/registream
stata -b do stata/tests/run_all_tests.do
```

This runs the comprehensive test suite (13 tests) including version management and configuration tests.

### Architecture Diagram

```
Production:
  registream.ado → _rs_utils get_version → cap _rs_get_dev_version (fails)
                                   → return "{{VERSION}}"

Development:
  registream.ado → _rs_dev_config (defines _rs_get_dev_version)
                → _rs_utils get_version → cap _rs_get_dev_version (succeeds)
                                   → return "2.0.0"
```

### For Package Maintainers

When exporting the package:

1. The `{{VERSION}}` placeholder in `_rs_utils.ado` (line 425) gets replaced with actual version
2. `_rs_dev_config.ado` is never included (gitignored)
3. `_rs_dev_config.ado.template` is included for other developers
4. No code stripping or line removal needed

This keeps the export process simple and maintainable.

---

## Local API Testing

This guide shows how to test RegiStream Stata commands against a local Flask API server running on your machine.

### Quick Start

1. **Enable Development Mode (ONE simple step):**

   ```bash
   cd ~/Github/registream
   cp stata/src/_rs_dev_config.ado.template stata/src/_rs_dev_config.ado
   ```

   This file defines two override functions:
   - `_rs_get_dev_host` returns "http://localhost:5000"
   - `_rs_get_dev_version` returns "2.0.0"

   **Customize port if needed:**
   ```stata
   * Edit stata/src/_rs_dev_config.ado:
   cap program drop _rs_get_dev_host
   program define _rs_get_dev_host, rclass
       return local host "http://localhost:8000"  # Your custom port
   end
   ```

2. **Start Local Flask API:**
   ```bash
   cd /path/to/your/flask/app
   flask run --host=0.0.0.0 --port=5000
   ```

3. **Run Stata Commands:**
   ```stata
   clear all
   adopath + "/path/to/registream/stata/src"

   * No manual setup needed - dev config auto-loads!
   * Commands automatically hit localhost
   set obs 100
   gen age = _n + 20

   autolabel variables age, domain(scb) lang(eng)
   * [DEV MODE] Using API host: http://localhost:5000
   ```

### How It Works

The development override uses the dev config file:

1. **Dev Config File** - `stata/src/_rs_dev_config.ado` (git-ignored)
   - Defines `_rs_get_dev_host` returning "http://localhost:5000"
   - Defines `_rs_get_dev_version` returning "2.0.0"
   - Auto-loaded by utility functions when it exists

2. **Clean Architecture**:
   - Production values: Hardcoded in `_rs_utils.ado` (ONE place)
   - Dev overrides: Defined in `_rs_dev_config.ado` (ONE place)
   - No globals - all values passed via return locals

When the dev config file exists, all API calls go to localhost instead of production.

### Disable Development Mode

```bash
# Rename the dev config
mv stata/src/_rs_dev_config.ado stata/src/_rs_dev_config.ado.disabled

# Test in Stata (will use https://registream.org)
```

Re-enable:
```bash
mv stata/src/_rs_dev_config.ado.disabled stata/src/_rs_dev_config.ado
```

### Test API Host Resolution

```stata
* Check which API host will be used
_rs_utils get_api_host
display "`r(host)'"

* With dev mode: http://localhost:5000
* Without dev mode: https://registream.org
```

### For Other Developers

If another developer clones the repo:

1. They'll see `_rs_dev_config.ado.template`
2. They copy it: `cp stata/src/_rs_dev_config.ado.template stata/src/_rs_dev_config.ado`
3. They customize the port/host if needed
4. Git ignores their copy (never committed)

### Testing Checklist

- [ ] Start local Flask API on port 5000 with API v1 endpoints
- [ ] Set dev mode (global variable, environment variable, or config file)
- [ ] Run Stata, check for `[DEV MODE]` messages
- [ ] Test command: `_rs_utils get_api_host` → should show localhost
- [ ] Test variable download: `autolabel variables age, domain(scb) lang(eng)`
- [ ] Test value label download: `autolabel values country, domain(scb) lang(eng)`
- [ ] Check Flask logs to confirm requests hit localhost at `/api/v1/datasets/{domain}/{type}/{lang}/latest`
- [ ] Verify Schema v1.0 files are served (column `variable_name` exists)
- [ ] Test both English and Swedish downloads
- [ ] Check usage logging in `~/.registream/usage_stata.csv`
- [ ] Disable dev mode, test production still works

### Common Development Workflow

```bash
# Terminal 1: Flask API (API v1)
cd ~/registream_api
flask run --port=5000

# Terminal 2: Monitor API logs
tail -f /path/to/flask/logs

# Terminal 3: Stata testing
stata
# Set dev mode and run autolabel commands
```

### Flask API v1 Implementation

Your local Flask API needs to implement API v1 endpoints. See `API_V1_REFERENCE.md` for complete details.

**Key endpoints:**
```python
@app.route('/api/v1/datasets/<domain>/<type>/<lang>/latest')
def serve_latest(domain, type, lang):
    # Map 'values' to 'value_labels' for file lookup
    if type == 'values':
        file_type = 'value_labels'
    else:
        file_type = type

    # Build filename: {domain}_{file_type}_{lang}_latest.zip
    filename = f"{domain}_{file_type}_{lang}_latest.zip"
    filepath = os.path.join(DATA_DIR, filename)

    return send_file(filepath)
```

**Important:**
- API uses clean naming: `/api/v1/datasets/scb/values/eng/latest` (not `value_labels`)
- Files are stored as: `scb_value_labels_eng_latest.zip`
- Flask maps `values` → `value_labels` internally
- ZIP files must have folder structure: `scb_variables/scb_variables_0000.csv`

### Troubleshooting

**"Still hitting production even with dev config?"**
- Check file exists: `ls stata/src/_rs_dev_config.ado`
- Verify functions are defined: Open file and check `_rs_get_dev_host` exists
- Check current directory when running Stata (file path is relative: `stata/src/_rs_dev_config.ado`)
- Run from repo root or use absolute path in utility functions
- Restart Stata session (dev config loaded once per session)

**"Getting 404 errors from localhost?"**
- Verify Flask is implementing `/api/v1/datasets/{domain}/{type}/{lang}/latest` endpoints
- Check that type mapping is correct: API uses `values`, files use `value_labels`
- Verify ZIP files exist in data directory with `_latest` suffix
- Check Flask logs for the exact URL being requested

**"Getting 'variable variable_name not found' error?"**
- Your localhost is serving old Schema 0.5 files
- Make sure Flask is serving Schema v1.0 files with `variable_name` column (not `variable`)
- Check ZIP contents: `unzip -l scb_variables_eng_latest.zip`

**"ZIP structure issues?"**
- Ensure ZIP files have folder structure: `scb_variables/scb_variables_0000.csv`
- Not flat structure (CSVs at root level)
- Check with: `unzip -l scb_variables_eng_latest.zip | head -20`

**"Want to test specific error responses?"**
- Modify your local Flask API to return errors
- Test how Stata handles different HTTP status codes
- Check error message display

**"How do I know if dev mode is active?"**
- You'll see `[DEV MODE] Using API host: http://localhost:5000` message
- Check `_rs_utils get_api_host` output
- Look for localhost URLs in Flask logs

### Safety

✅ Git ignores `_rs_dev_config.ado` - can't accidentally commit
✅ Users never see this file (not in releases)
✅ Global variable override works in test files
✅ Production behavior unchanged without dev mode
✅ Clear visual indicators when dev mode active (`[DEV MODE]` prefix)

---

**Version:** 2.0.0
**Last Updated:** 2025-10-21
