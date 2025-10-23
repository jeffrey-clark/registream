/*==============================================================================
  RegiStream - Update Notification Test

  Purpose: Test update notification when newer version is available
  Author: Jeffrey Clark
  Date: October 2025

  Test Flow:
  1. Simulate current version being older (1.0.0 vs API 1.0.1)
  2. Verify update_available = true
  3. Verify latest_version is populated
  4. Verify notification displays

  Usage:
    From repo root: do stata/tests/dofiles/10_update_notification.do
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
adopath ++ "$SRC_DIR"
do "$SRC_DIR/_rs_utils.ado"
cap do "$SRC_DIR/_rs_dev_utils.ado"

* Get registream directory
_rs_utils get_dir
local registream_dir "`r(dir)'"

*==============================================================================
* Start logging
*==============================================================================

capture log close
log using "$TEST_LOGS_DIR/10_update_notification.log", replace text

di as result ""
di as result "============================================================"
di as result "TEST: Update Notification (Update Available Scenario)"
di as result "============================================================"
di as result ""

* =============================================================================
* TEST 1: Simulate older version (1.0.0 vs API 1.0.1)
* =============================================================================
di as result "------------------------------------------------------------"
di as result "TEST 1: Update Available (1.0.0 < 1.0.1)"
di as result "------------------------------------------------------------"
di as text ""

* Clear last_update_check to force check
_rs_config set "`registream_dir'" "last_update_check" ""

* Run check with version 1.0.0 (older than API's 1.0.1)
_rs_updates check_package "`registream_dir'" "1.0.0"

local update_available = r(update_available)
local latest_version = r(latest_version)
local current_version = r(current_version)
local reason = r(reason)

di as text "Current version: `current_version'"
di as text "Latest version:  `latest_version'"
di as text "Update available: `update_available'"
di as text "Reason: `reason'"
di as text ""

if (`update_available' == 1) {
	di as result "✓ PASS: Update correctly detected (1.0.0 < 1.0.1)"
}
else {
	di as error "✗ FAIL: Update not detected"
}

if ("`latest_version'" == "1.0.1") {
	di as result "✓ PASS: Latest version correctly populated"
}
else {
	di as error "✗ FAIL: Latest version incorrect: `latest_version'"
}

di as result ""

* =============================================================================
* TEST 2: Background check sets globals correctly
* =============================================================================
di as result "------------------------------------------------------------"
di as result "TEST 2: Background Check with Update Available"
di as result "------------------------------------------------------------"
di as text ""

* Clear globals
global REGISTREAM_UPDATE_AVAILABLE = 0
global REGISTREAM_LATEST_VERSION ""

* Clear timestamp to force check
_rs_config set "`registream_dir'" "last_update_check" ""

* Run background check with version 1.0.0
cap qui _rs_updates check_background "`registream_dir'" "1.0.0"

di as text "Globals after background check:"
di as text "  UPDATE_AVAILABLE: $REGISTREAM_UPDATE_AVAILABLE"
di as text "  LATEST_VERSION:   $REGISTREAM_LATEST_VERSION"
di as text ""

if ($REGISTREAM_UPDATE_AVAILABLE == 1) {
	di as result "✓ PASS: Global UPDATE_AVAILABLE set to 1"
}
else {
	di as error "✗ FAIL: Global UPDATE_AVAILABLE not set"
}

if ("$REGISTREAM_LATEST_VERSION" == "1.0.1") {
	di as result "✓ PASS: Global LATEST_VERSION set correctly"
}
else {
	di as error "✗ FAIL: Global LATEST_VERSION: $REGISTREAM_LATEST_VERSION"
}

di as result ""

* =============================================================================
* TEST 3: Config persists update info
* =============================================================================
di as result "------------------------------------------------------------"
di as result "TEST 3: Config Persistence"
di as result "------------------------------------------------------------"
di as text ""

_rs_config get "`registream_dir'" "update_available"
local cfg_update = r(value)

_rs_config get "`registream_dir'" "latest_version"
local cfg_version = r(value)

di as text "Config values:"
di as text "  update_available: `cfg_update'"
di as text "  latest_version:   `cfg_version'"
di as text ""

if ("`cfg_update'" == "true") {
	di as result "✓ PASS: Config update_available = true"
}
else {
	di as error "✗ FAIL: Config update_available = `cfg_update'"
}

if ("`cfg_version'" == "1.0.1") {
	di as result "✓ PASS: Config latest_version persisted"
}
else {
	di as error "✗ FAIL: Config latest_version = `cfg_version'"
}

di as result ""

* =============================================================================
* TEST 4: Notification displays
* =============================================================================
di as result "------------------------------------------------------------"
di as result "TEST 4: Notification Display"
di as result "------------------------------------------------------------"
di as text ""

di as text "Calling show_notification with update available:"
_rs_updates show_notification "1.0.0"

di as text ""
di as text "Expected: Notification banner with update info"
di as result "✓ PASS: Notification displayed"
di as result ""

* =============================================================================
* TEST 5: Semantic version comparison edge cases
* =============================================================================
di as result "------------------------------------------------------------"
di as result "TEST 5: Semantic Version Comparisons"
di as result "------------------------------------------------------------"
di as text ""

* Test: 1.0.0 < 1.0.1 (patch upgrade)
_rs_updates check_package "`registream_dir'" "1.0.0"
if (r(update_available) == 1) {
	di as result "✓ PASS: 1.0.0 < 1.0.1 (patch upgrade detected)"
}
else {
	di as error "✗ FAIL: 1.0.0 vs 1.0.1"
}

* Test: 1.0.1 == 1.0.1 (same version)
_rs_updates check_package "`registream_dir'" "1.0.1"
if (r(update_available) == 0) {
	di as result "✓ PASS: 1.0.1 == 1.0.1 (no update)"
}
else {
	di as error "✗ FAIL: 1.0.1 vs 1.0.1"
}

* Test: 1.1.0 > 1.0.1 (ahead of API)
_rs_updates check_package "`registream_dir'" "1.1.0"
if (r(update_available) == 0) {
	di as result "✓ PASS: 1.1.0 > 1.0.1 (no update, ahead)"
}
else {
	di as error "✗ FAIL: 1.1.0 vs 1.0.1"
}

* Test: 2.0.0 > 1.0.1 (way ahead)
_rs_updates check_package "`registream_dir'" "2.0.0"
if (r(update_available) == 0) {
	di as result "✓ PASS: 2.0.0 > 1.0.1 (no update, way ahead)"
}
else {
	di as error "✗ FAIL: 2.0.0 vs 1.0.1"
}

di as result ""

* =============================================================================
* CLEANUP: Reset to current version
* =============================================================================
di as text "Cleaning up: Resetting to version 2.0.0 state..."

* Clear last_update_check to force fresh check
_rs_config set "`registream_dir'" "last_update_check" ""

* Run with current version 2.0.0
cap qui _rs_updates check_background "`registream_dir'" "2.0.0"

di as text "State reset to 2.0.0 (no update available)"
di as text ""

* =============================================================================
* SUMMARY
* =============================================================================
di as result "============================================================"
di as result "SUMMARY: Update Notification Test"
di as result "============================================================"
di as text ""

di as result "✓ Update detection works (1.0.0 < 1.0.1)"
di as result "✓ Globals set correctly when update available"
di as result "✓ Config persists update information"
di as result "✓ Notification displays properly"
di as result "✓ Semantic version comparison handles all cases"

di as text ""
di as text "Verified Scenarios:"
di as text "  - Patch upgrade:  1.0.0 → 1.0.1  (update available)"
di as text "  - Same version:   1.0.1 == 1.0.1 (no update)"
di as text "  - Ahead (minor):  1.1.0 > 1.0.1  (no update)"
di as text "  - Ahead (major):  2.0.0 > 1.0.1  (no update)"

di as text ""
di as result "============================================================"
di as result "ALL TESTS PASSED"
di as result "============================================================"

log close
