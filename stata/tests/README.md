# RegiStream Stata Test Suite

Comprehensive test suite for RegiStream Stata implementation v2.0.0.

## Overview

**14 test files** covering all major features with **100% standalone** execution capability.

- ✅ Config auto-initialization
- ✅ Basic autolabel workflow (variables + values, English + Swedish)
- ✅ File/metadata verification (5 scenarios)
- ✅ 24-hour cache mechanism
- ✅ Online vs offline mode (9 scenarios)
- ✅ Version & update system
- ✅ Update default behavior
- ✅ Version & citation commands
- ✅ Auto-update check
- ✅ Update notifications
- ✅ Telemetry and config system (12 sub-tests)
- ✅ Bug fixes validation (4 bug fixes)
- ✅ **Version resolution priority (22 sub-tests)**
- ✅ Clean state restoration

## Quick Start

```bash
# From repository root
cd ~/Github/registream
stata -b do stata/tests/run_all_tests.do
```

**Requirements:**
- Local API server running at `localhost:5000`
- `.project_root` file in repo root

## Test Suite Structure

```
stata/tests/
├── README.md                          # This file
├── run_all_tests.do                   # Master test suite (14 tests)
├── dofiles/                           # Test scripts (all standalone)
│   ├── 01_config_initialization.do
│   ├── 02_basic_workflow.do
│   ├── 03_verification_scenarios.do
│   ├── 04_caching.do
│   ├── 05_offline_mode.do
│   ├── 06_comprehensive_update_system.do
│   ├── 07_update_default_behavior.do
│   ├── 08_version_and_cite_commands.do
│   ├── 09_auto_update_check.do
│   ├── 10_update_notification.do
│   ├── 11_telemetry_config.do
│   ├── 12_bug_fixes_validation.do
│   ├── 13_version_resolution_priority.do   
│   └── 99_cleanup.do
├── data/                              # Synthetic test datasets (git-ignored)
│   └── synthetic_lisa.dta
├── logs/                              # Test output logs (git-ignored)
│   ├── 01_config_initialization.log
│   ├── ...
│   └── 99_cleanup.log
└── utils/                             # Testing utilities
    └── generate_synthetic_data.do
```

## All Test Files

### Test 01: Config Initialization
**File:** `01_config_initialization.do`
**Purpose:** Verify `config.yaml` auto-creation with correct defaults

**Tests:**
1. Delete config.yaml
2. Run autolabel (triggers init)
3. Verify config created
4. Verify defaults (`telemetry_enabled: true`, `internet_access: true`)
5. Modify config and verify persistence
6. Verify simple format (no installation metadata)

### Test 02: Basic Workflow
**File:** `02_basic_workflow.do`
**Purpose:** End-to-end autolabel functionality

**Tests:**
1. Generate synthetic data (1,000 obs)
2. Apply English variable labels
3. Apply English value labels
4. Apply Swedish variable labels
5. Apply Swedish value labels
6. Verify metadata tracking
7. Verify usage logging

### Test 03: Verification Scenarios
**File:** `03_verification_scenarios.do`
**Purpose:** File/metadata verification under various scenarios

**Tests:**
1. Fresh download baseline
2. File size mismatch (source=api)
3. File missing + metadata exists
4. File exists + no metadata
5. Size mismatch + source=user (skip warning)

### Test 04: Caching
**File:** `04_caching.do`
**Purpose:** 24-hour cache mechanism

**Tests:**
1. Fresh download sets `last_checked` to today
2. Same-day re-run uses cache (no API ping)
3. Old `last_checked` triggers API ping

### Test 05: Offline Mode
**File:** `05_offline_mode.do`
**Purpose:** `internet_access` config behavior

**Tests:**
1. Invalid domain (ONLINE) - API error
2. Invalid domain (OFFLINE) - Local validation
3. Invalid language (ONLINE) - API error
4. Invalid language (OFFLINE) - Local validation
5. Valid dataset OFFLINE without file - Cannot download
6. Valid dataset ONLINE - Download success
7. Valid dataset OFFLINE with file - Works locally
8. Size mismatch OFFLINE - Skip API check
9. File missing OFFLINE - Cannot re-download

### Test 06: Comprehensive Update System
**File:** `06_comprehensive_update_system.do`
**Purpose:** Version & update system validation

### Test 07: Update Default Behavior
**File:** `07_update_default_behavior.do`
**Purpose:** Default update behavior validation

### Test 08: Version and Cite Commands
**File:** `08_version_and_cite_commands.do`
**Purpose:** Version/cite commands & aliases

**Tests:**
1. `registream version` command
2. `registream cite` command
3. `autolabel version` alias
4. `autolabel cite` alias

### Test 09: Auto Update Check
**File:** `09_auto_update_check.do`
**Purpose:** Auto-update check feature

### Test 10: Update Notification
**File:** `10_update_notification.do`
**Purpose:** Update notification when newer version available

### Test 11: Telemetry Config
**File:** `11_telemetry_config.do`
**Purpose:** Telemetry and config system (12 sub-tests)

**Tests:**
1. AUTO_APPROVE defaults to Full Mode
2. Empty config re-initialization
3-12. Various telemetry and config scenarios

### Test 12: Bug Fixes Validation
**File:** `12_bug_fixes_validation.do`
**Purpose:** Critical bug fixes validation

**Tests:**
1. `escape_ascii` return local syntax
2. Invalid `$registream_dir` error messages
3. `autolabel info` shows `usage_logging` setting
4. `registream stats` doesn't log itself (no recursion)

### ⭐ Test 13: Version Resolution Priority (Comprehensive)
**File:** `13_version_resolution_priority.do`
**Purpose:** **22 sub-tests** validating 2-level priority system (dev/production)

**Priority Levels:**
1. **Dev mode:** `_rs_dev_utils` (git-ignored, localhost)
2. **Production:** Hardcoded `{{VERSION}}` and `https://registream.org`

**Test Scenarios:**
- **Scenario A** (3 tests): Dev default values (2.0.0, localhost:5000) + autolabel
- **Scenario B** (3 tests): Test globals (1.5.0-CUSTOM, localhost:8888) + autolabel
- **Scenario C** (3 tests): Clear globals → dev defaults + autolabel
- **Scenario D** (2 tests): Different globals (3.0.0-BETA) + autolabel
- **Scenario E** (3 tests): Production fallback ({{VERSION}}) + autolabel
- **Scenario F** (2 tests): Restore dev override + autolabel
- **Scenario G** (5 tests): Rapid switches (4 versions) + autolabel
- **Scenario H** (1 test): Usage tracking verification

**Versions Tested:**
- `2.0.0` (dev default)
- `1.5.0-CUSTOM` (test global)
- `3.0.0-BETA` (test global)
- `{{VERSION}}` (production fallback) ✅
- `0.9.0-ALPHA` (rapid switch)
- `2.1.0-RC1` (rapid switch)
- `1.0.0-STABLE` (rapid switch)

**All versions logged to `~/.registream/usage_stata.csv` for verification!**

### Test 99: Cleanup
**File:** `99_cleanup.do`
**Purpose:** Clean state restoration

**Tests:**
1. Delete config.yaml and reinitialize
2. Delete all datasets and metadata
3. Load synthetic data
4. Fresh download of 4 SCB datasets
5. Verify clean state (4 datasets, source=api)

## Running Tests

### Run All Tests

```bash
# From repository root
cd ~/Github/registream
stata -b do stata/tests/run_all_tests.do
```

**Expected output:**
```
============================================================
RegiStream Master Test Suite
============================================================

Test 1/14: Config Auto-Initialization
============================================================
[PASS] Test 1

... (tests 2-13) ...

Test 14/14: Clean State Restoration
============================================================
[PASS] Test 14

============================================================
Test Suite Summary
============================================================

Total Tests:  14
Passed:       14
Failed:       0
Pass Rate:    100%

============================================================
[SUCCESS] ALL TESTS PASSED!
============================================================
```

### Run Individual Tests

Each test is **standalone** and can run from any directory:

```stata
* From anywhere
do stata/tests/dofiles/13_version_resolution_priority.do

* Or change to test directory
cd stata/tests
do dofiles/02_basic_workflow.do
```

**Features:**
- Automatic project root detection (searches up 5 levels for `.project_root`)
- Automatic synthetic data generation (if missing)
- Independent logging to `stata/tests/logs/NN_testname.log`
- Fresh program loading (`discard` + explicit `do`)

## Test Configuration

### Standalone Setup Pattern

All tests use this pattern:

```stata
clear all
version 16.0

* Find project root
local cwd = "`c(pwd)'"
local project_root ""

forvalues i = 0/5 {
    local search_path = "`cwd'"
    forvalues j = 1/`i' {
        local search_path = "`search_path'/.."
    }
    capture confirm file "`search_path'/.project_root"
    if _rc == 0 {
        quietly cd "`search_path'"
        local project_root = "`c(pwd)'"
        quietly cd "`cwd'"
        continue, break
    }
}

* Setup paths
global PROJECT_ROOT "`project_root'"
global SRC_DIR "$PROJECT_ROOT/stata/src"
global TEST_DIR "$PROJECT_ROOT/stata/tests"
global TEST_DATA_DIR "$TEST_DIR/data"
global TEST_LOGS_DIR "$TEST_DIR/logs"

* Create logs directory
cap mkdir "$TEST_LOGS_DIR"

* Enable auto-approve for test mode
global REGISTREAM_AUTO_APPROVE "yes"

* Clear all cached programs and load fresh
discard
adopath + "$SRC_DIR"
do "$SRC_DIR/_rs_utils.ado"
cap do "$SRC_DIR/_rs_dev_utils.ado"

* Start logging
log using "$TEST_LOGS_DIR/NN_testname.log", replace text
```

### Development Override System

Tests automatically use the **2-level priority system**:

1. **Dev mode** (if `_rs_dev_utils.ado` exists):
   - Version: `2.0.0` (or `$REGISTREAM_TEST_VERSION` if set)
   - API host: `http://localhost:5000` (or `$REGISTREAM_TEST_HOST` if set)

2. **Production mode** (no dev file):
   - Version: `{{VERSION}}`
   - API host: `https://registream.org`

**Enable dev mode:**
```bash
cp stata/src/_rs_dev_utils.ado.template stata/src/_rs_dev_utils.ado
```

**Disable dev mode:**
```bash
mv stata/src/_rs_dev_utils.ado stata/src/_rs_dev_utils.ado.disabled
```

## Synthetic Data

All tests use **synthetic data** (no real individuals):

```stata
* Generated automatically by test suite
do stata/tests/utils/generate_synthetic_data.do
```

**Properties:**
- 1,000 synthetic observations
- 10 LISA-like variables (lopnr, kon, kommun, etc.)
- Reproducible (seed: 20251018)
- Realistic value ranges
- Git-ignored (`stata/tests/data/*.dta`)

## Test Logs

Each test creates its own log in `stata/tests/logs/`:

```
01_config_initialization.log
02_basic_workflow.log
03_verification_scenarios.log
04_caching.log
05_offline_mode.log
06_comprehensive_update_system.log
07_update_default_behavior.log
08_version_and_cite_commands.log
09_auto_update_check.log
10_update_notification.log
12_bug_fixes_validation.log
13_version_resolution_priority.log    # 60KB - comprehensive!
99_cleanup.log
```

**Note:** Test 11 (telemetry) uses isolated test environment, doesn't log to `logs/`.

All log files are git-ignored (`.gitignore` includes `*.log`).

## Troubleshooting

### API Connection Errors

**Problem:** "Could not download dataset"

**Solution:**
```bash
# Verify API is running
curl http://localhost:5000/api/v1/datasets/scb/variables/eng/latest

# Check Flask logs
tail -f flask.log
```

### Test Failures

**Problem:** Test fails with unexpected error

**Solution:**
1. Check individual test log in `stata/tests/logs/NN_testname.log`
2. Run test standalone: `do stata/tests/dofiles/NN_testname.do`
3. Verify synthetic data exists: `ls stata/tests/data/synthetic_lisa.dta`
4. Check dev override: `ls stata/src/_rs_dev_utils.ado`

### Version Resolution Issues

**Problem:** Tests show wrong version in usage tracking

**Solution:**
```stata
* Check which system is active
_rs_utils get_version
display "`r(version)'"

* Dev mode: Returns "2.0.0"
* Production: Returns "{{VERSION}}"
```

## Adding New Tests

1. **Create test file:** `stata/tests/dofiles/NN_testname.do`
2. **Use standalone template** (see pattern above)
3. **Add to master suite:** Edit `run_all_tests.do`
4. **Update this README:** Add test description

---

**Last Updated:** 2025-10-21
**Author:** Jeffrey Clark
**Version:** 2.0.0
**Test Count:** 14 tests (61+ sub-tests total)
