/*==============================================================================
  RegiStream - Test Config Initialization

  Purpose: Test that config.yaml is automatically created when missing
  Author: Jeffrey Clark
  Date: October 2025

  Test Flow:
  1. Delete config.yaml
  2. Run autolabel command
  3. Verify config.yaml was created with correct defaults
  4. Verify settings are readable

  Usage:
    From repo root: do stata/tests/test_config_initialization.do

  Requirements:
    - API server running at localhost:5000
    - $permission = "yes" for auto-approval
==============================================================================*/

clear all
version 16.0

*==============================================================================
* Find project root using .project_root marker file
*==============================================================================

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

if "`project_root'" == "" {
	di as error "ERROR: Could not find .project_root file"
	exit 601
}

*==============================================================================
* Set up paths and config
*==============================================================================

global PROJECT_ROOT "`project_root'"
global TEST_DIR "$PROJECT_ROOT/stata/tests"
global SRC_DIR "$PROJECT_ROOT/stata/src"
global TEST_DATA_DIR "$TEST_DIR/data"
global TEST_LOGS_DIR "$TEST_DIR/logs"

* Create logs directory
cap mkdir "$TEST_LOGS_DIR"

* Enable auto-approve for test mode (bypasses user prompts)
global REGISTREAM_AUTO_APPROVE "yes"

* Clear all cached programs and load fresh
discard
adopath + "$SRC_DIR"
do "$SRC_DIR/_rs_utils.ado"
cap do "$SRC_DIR/_rs_dev_utils.ado"

* Get registream directory
_rs_utils get_dir
local registream_dir "`r(dir)'"
local config_file "`registream_dir'/config.yaml"

*==============================================================================
* Start logging
*==============================================================================

capture log close
log using "$TEST_LOGS_DIR/01_config_initialization.log", replace text

di as result ""
di as result "========================================================"
di as result "Test: Config Initialization"
di as result "========================================================"
di as result ""
di as text "Registream dir: `registream_dir'"
di as text "Config file: `config_file'"
di as result ""

*==============================================================================
* Setup: Load synthetic data
*==============================================================================

di as result "Setup: Loading synthetic data..."
cd "$TEST_DIR"
do "$TEST_DIR/utils/generate_synthetic_data.do"
use "$TEST_DATA_DIR/synthetic_lisa.dta", clear

*==============================================================================
* Test 1: Delete config.yaml and verify it's gone
*==============================================================================

di as result ""
di as result "========================================================"
di as result "Test 1: Delete config.yaml"
di as result "========================================================"
di as result ""

cap erase "`config_file'"

cap confirm file "`config_file'"
if (_rc == 0) {
	di as error "✗ FAILED: config.yaml still exists after deletion"
	exit 1
}
else {
	di as result "✓ config.yaml successfully deleted"
}

di as text ""

*==============================================================================
* Test 2: Run autolabel (triggers config initialization)
*==============================================================================

di as result ""
di as result "========================================================"
di as result "Test 2: Run autolabel (Should Create Config)"
di as result "========================================================"
di as result ""

di as text "Running: autolabel variables, domain(scb) lang(eng)"
di as text "This should trigger automatic config initialization..."
di as text ""

use "$TEST_DATA_DIR/synthetic_lisa.dta", clear
autolabel variables, domain(scb) lang(eng)

di as text ""

*==============================================================================
* Test 3: Verify config.yaml was created
*==============================================================================

di as result ""
di as result "========================================================"
di as result "Test 3: Verify config.yaml Created"
di as result "========================================================"
di as result ""

cap confirm file "`config_file'"
if (_rc != 0) {
	di as error "✗ FAILED: config.yaml was not created"
	exit 1
}
else {
	di as result "✓ config.yaml exists"
}

* Display config file contents
di as text ""
di as text "Config file contents:"
di as text "{hline 60}"
type "`config_file'"
di as text "{hline 60}"
di as text ""

*==============================================================================
* Test 4: Verify config has correct default values
*==============================================================================

di as result ""
di as result "========================================================"
di as result "Test 4: Verify Default Values"
di as result "========================================================"
di as result ""

* Check telemetry_enabled
_rs_config get "`registream_dir'" "telemetry_enabled"
local telemetry = r(value)
local telemetry_found = r(found)

if (`telemetry_found' == 0) {
	di as error "✗ FAILED: telemetry_enabled not found in config"
	exit 1
}

if ("`telemetry'" != "true") {
	di as error "✗ FAILED: telemetry_enabled = `telemetry' (expected: true)"
	exit 1
}

di as result "✓ telemetry_enabled = `telemetry' (correct)"

* Check internet_access
_rs_config get "`registream_dir'" "internet_access"
local internet = r(value)
local internet_found = r(found)

if (`internet_found' == 0) {
	di as error "✗ FAILED: internet_access not found in config"
	exit 1
}

if ("`internet'" != "true") {
	di as error "✗ FAILED: internet_access = `internet' (expected: true)"
	exit 1
}

di as result "✓ internet_access = `internet' (correct)"
di as text ""

*==============================================================================
* Test 5: Modify config and verify changes persist
*==============================================================================

di as result ""
di as result "========================================================"
di as result "Test 5: Modify and Re-read Config"
di as result "========================================================"
di as result ""

* Change internet_access to false
_rs_config set "`registream_dir'" "internet_access" "false"
di as text "Set internet_access to false"

* Re-read to verify
_rs_config get "`registream_dir'" "internet_access"
local internet_after = r(value)

if ("`internet_after'" != "false") {
	di as error "✗ FAILED: internet_access = `internet_after' (expected: false)"
	exit 1
}

di as result "✓ internet_access = `internet_after' (change persisted)"

* Restore to true
_rs_config set "`registream_dir'" "internet_access" "true"
di as text "Restored internet_access to true"
di as text ""

*==============================================================================
* Test 6: Verify config simplicity (no installation metadata)
*==============================================================================

di as result ""
di as result "========================================================"
di as result "Test 6: Verify Simple Config Format"
di as result "========================================================"
di as result ""

* Count lines in config file (should be short - around 5 lines)
tempname fh
file open `fh' using "`config_file'", read
local line_count = 0
file read `fh' line
while r(eof) == 0 {
	local ++line_count
	file read `fh' line
}
file close `fh'

di as text "Config file has `line_count' lines"

if (`line_count' > 10) {
	di as error "⚠ WARNING: Config file seems too long (`line_count' lines)"
	di as error "  Expected ~5-6 lines (header + 2 settings + blank lines)"
}
else {
	di as result "✓ Config file is appropriately simple"
}

* Verify no installation_id or installation_date
preserve
tempfile config_copy
copy "`config_file'" "`config_copy'", replace
cap infix strL line 1-200 using "`config_copy'", clear

if (_rc == 0) {
	local has_install_id = 0
	local has_install_date = 0

	forval i = 1/`=_N' {
		local current_line = line[`i']
		if (strpos("`current_line'", "installation_id") > 0) {
			local has_install_id = 1
		}
		if (strpos("`current_line'", "installation_date") > 0) {
			local has_install_date = 1
		}
	}

	if (`has_install_id' == 1 | `has_install_date' == 1) {
		di as error "✗ FAILED: Config contains installation metadata (should be removed)"
		exit 1
	}
	else {
		di as result "✓ Config does not contain installation metadata (simple format)"
	}
}
restore

di as text ""

*==============================================================================
* Final Summary
*==============================================================================

di as result ""
di as result "========================================================"
di as result "All Tests Passed!"
di as result "========================================================"
di as result ""

di as result "Tested:"
di as result "  ✓ Config deleted successfully"
di as result "  ✓ Config auto-created when missing"
di as result "  ✓ Default values correct (telemetry=true, internet=true)"
di as result "  ✓ Config changes persist across reads"
di as result "  ✓ Config format is simple (no installation metadata)"
di as result ""

di as text "Expected config format:"
di as text "  # RegiStream Configuration"
di as text "  "
di as text "  telemetry_enabled: true"
di as text "  internet_access: true"
di as result ""

di as result "✓ Config initialization working as designed!"
di as result ""

log close
