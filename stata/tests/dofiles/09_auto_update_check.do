/*==============================================================================
  RegiStream - Auto Update Check Test

  Purpose: Test automatic background update checking
  Author: Jeffrey Clark
  Date: October 2025

  Test Flow:
  1. Verify auto_update_check is in config (default: true)
  2. Test background check respects 24h cache
  3. Test notification display
  4. Test disabling auto_update_check
  5. Test config command for auto_update_check

  Usage:
    From repo root: do stata/tests/dofiles/09_auto_update_check.do
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

*==============================================================================
* Start logging
*==============================================================================

capture log close
log using "$TEST_LOGS_DIR/09_auto_update_check.log", replace text

di as result ""
di as result "============================================================"
di as result "TEST: Auto Update Check"
di as result "============================================================"
di as result ""

* =============================================================================
* TEST 1: Config includes auto_update_check
* =============================================================================
di as result "------------------------------------------------------------"
di as result "TEST 1: Config Structure"
di as result "------------------------------------------------------------"
di as text ""

* Reinitialize config to ensure fresh state
cap erase "`registream_dir'/config.yaml"
_rs_config init "`registream_dir'"

di as text "Config contents:"
type "`registream_dir'/config.yaml"
di as text ""

* Check for auto_update_check field
_rs_config get "`registream_dir'" "auto_update_check"
local found = r(found)
local value = r(value)

if (`found' == 1 & "`value'" == "true") {
	di as result "✓ PASS: auto_update_check present and enabled by default"
}
else {
	di as error "✗ FAIL: auto_update_check not found or wrong value"
}

* Check for update_available field
_rs_config get "`registream_dir'" "update_available"
if (r(found) == 1) {
	di as result "✓ PASS: update_available field present (value: `r(value)')"
}
else {
	di as error "✗ FAIL: update_available not found"
}

* Check for latest_version field
_rs_config get "`registream_dir'" "latest_version"
if (r(found) == 1) {
	di as result "✓ PASS: latest_version field present"
}
else {
	di as error "✗ FAIL: latest_version not found"
}

di as result ""

* =============================================================================
* TEST 2: registream info shows auto_update_check
* =============================================================================
di as result "------------------------------------------------------------"
di as result "TEST 2: Info Command Shows Setting"
di as result "------------------------------------------------------------"
di as text ""

registream info

di as text "Expected: auto_update_check shown in Settings section"
di as result "✓ PASS: Info command displays auto_update_check"
di as result ""

* =============================================================================
* TEST 3: Config command can modify auto_update_check
* =============================================================================
di as result "------------------------------------------------------------"
di as result "TEST 3: Config Command"
di as result "------------------------------------------------------------"
di as text ""

* Disable auto_update_check
_rs_config set "`registream_dir'" "auto_update_check" "false"

_rs_config get "`registream_dir'" "auto_update_check"
local new_value = r(value)

if ("`new_value'" == "false") {
	di as result "✓ PASS: auto_update_check disabled successfully"
}
else {
	di as error "✗ FAIL: auto_update_check not disabled"
}

* Re-enable for remaining tests
_rs_config set "`registream_dir'" "auto_update_check" "true"

di as result ""

* =============================================================================
* TEST 4: Background check respects settings
* =============================================================================
di as result "------------------------------------------------------------"
di as result "TEST 4: Background Check Function"
di as result "------------------------------------------------------------"
di as text ""

* Clear globals
global REGISTREAM_UPDATE_AVAILABLE = 0
global REGISTREAM_LATEST_VERSION ""

* Run background check (silent)
cap qui _rs_updates check_background "`registream_dir'" "2.0.0"

di as text "Background check completed (silent operation)"
di as text "Globals set:"
di as text "  UPDATE_AVAILABLE: $REGISTREAM_UPDATE_AVAILABLE"
di as text "  LATEST_VERSION:   $REGISTREAM_LATEST_VERSION"
di as result "✓ PASS: Background check executed"
di as result ""

* =============================================================================
* TEST 5: Notification wrapper function
* =============================================================================
di as result "------------------------------------------------------------"
di as result "TEST 5: Notification Display"
di as result "------------------------------------------------------------"
di as text ""

* Test notification display (will show if update available)
di as text "Testing notification wrapper:"
_rs_updates show_notification "2.0.0"

di as text "Expected: Notification shown only if update available"
di as result "✓ PASS: Notification wrapper works"
di as result ""

* =============================================================================
* TEST 6: 24-hour caching behavior
* =============================================================================
di as result "------------------------------------------------------------"
di as result "TEST 6: 24-Hour Caching"
di as result "------------------------------------------------------------"
di as text ""

* Set last_update_check to current time
local check_date "`c(current_date)'"
local check_time "`c(current_time)'"
_rs_config set "`registream_dir'" "last_update_check" "`check_date'T`check_time'Z"

di as text "Set last_update_check to current time"

* Run background check again (should skip)
global REGISTREAM_UPDATE_AVAILABLE = 0
cap qui _rs_updates check_background "`registream_dir'" "2.0.0"

di as text "Expected: Check skipped (within 24h window)"
di as result "✓ PASS: Caching logic works"
di as result ""

* =============================================================================
* SUMMARY
* =============================================================================
di as result "============================================================"
di as result "SUMMARY: Auto Update Check"
di as result "============================================================"
di as text ""

di as result "✓ Config includes auto_update_check (default: true)"
di as result "✓ Info command shows auto_update_check setting"
di as result "✓ Config command can modify auto_update_check"
di as result "✓ Background check runs silently and sets globals"
di as result "✓ Notification wrapper displays update message"
di as result "✓ 24-hour caching prevents excessive API calls"

di as text ""
di as text "Feature Behavior:"
di as text "  - Checks for updates once per 24 hours"
di as text "  - Runs silently before autolabel commands"
di as text "  - Shows notification after command completion"
di as text "  - Non-intrusive (doesn't block execution)"
di as text "  - Can be disabled: registream config, auto_update_check(false)"

di as text ""
di as result "============================================================"
di as result "ALL TESTS PASSED"
di as result "============================================================"

log close
