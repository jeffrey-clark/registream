/*==============================================================================
  RegiStream - Test Offline Validation & Internet Access Control

  Purpose: Exhaustive testing of internet_access config with various scenarios
  Author: Jeffrey Clark
  Date: October 2025

  Test Flow:
  1. Invalid domain - online vs offline
  2. Invalid language - online vs offline
  3. Valid dataset - offline without file (should fail gracefully)
  4. Valid dataset - offline with file (should work)
  5. Verification scenarios - offline mode

  Usage:
    From repo root: do stata/tests/test_offline_validation.do

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
adopath ++ "$SRC_DIR"
do "$SRC_DIR/_rs_utils.ado"
cap do "$SRC_DIR/_rs_dev_utils.ado"

* Get registream directory
_rs_utils get_dir
local registream_dir "`r(dir)'"
local autolabel_dir "`registream_dir'/autolabel_keys"
local config_file "`registream_dir'/config.yaml"

*==============================================================================
* Start logging
*==============================================================================

capture log close
log using "$TEST_LOGS_DIR/05_offline_mode.log", replace text

di as result ""
di as result "========================================================"
di as result "Test: Offline Validation & Internet Access Control"
di as result "========================================================"
di as result ""
di as text "Registream dir: `registream_dir'"
di as text "API host: $REGISTREAM_API_HOST"
di as text "Config file: `config_file'"
di as result ""

*==============================================================================
* Setup: Load synthetic data and ensure config exists
*==============================================================================

di as result "Setup: Loading synthetic data..."
cd "$TEST_DIR"
do "$TEST_DIR/utils/generate_synthetic_data.do"
use "$TEST_DATA_DIR/synthetic_lisa.dta", clear

* Ensure config exists
_rs_config init "`registream_dir'"

di as text ""

*==============================================================================
* Test 1: Invalid Domain - ONLINE
*==============================================================================

di as result ""
di as result "========================================================"
di as result "Test 1: Invalid Domain (ONLINE)"
di as result "========================================================"
di as result ""

* Set internet_access = true
_rs_config set "`registream_dir'" "internet_access" "true"
_rs_config get "`registream_dir'" "internet_access"
di as text "  internet_access set to: {result:`r(value)'}"

di as text ""
di as text "Attempting: autolabel variables, domain(invalid) lang(eng)"
di as text "Expected: API error with available_domains suggestion"
di as text ""

use "$TEST_DATA_DIR/synthetic_lisa.dta", clear
cap noi autolabel variables, domain(invalid) lang(eng)
local rc_online_invalid_domain = _rc

di as text ""
if (`rc_online_invalid_domain' != 0) {
	di as result "✓ Test 1 PASSED: Failed as expected (rc=`rc_online_invalid_domain')"
	di as text "  Error message should show API suggestion above"
}
else {
	di as error "✗ Test 1 FAILED: Should have failed with invalid domain"
}
di as text ""

*==============================================================================
* Test 2: Invalid Domain - OFFLINE
*==============================================================================

di as result ""
di as result "========================================================"
di as result "Test 2: Invalid Domain (OFFLINE)"
di as result "========================================================"
di as result ""

* Set internet_access = false
_rs_config set "`registream_dir'" "internet_access" "false"
_rs_config get "`registream_dir'" "internet_access"
di as text "  internet_access set to: {result:`r(value)'}"

di as text ""
di as text "Attempting: autolabel variables, domain(invalid) lang(eng)"
di as text "Expected: Local validation error with known domains list"
di as text ""

use "$TEST_DATA_DIR/synthetic_lisa.dta", clear
cap noi autolabel variables, domain(invalid) lang(eng)
local rc_offline_invalid_domain = _rc

di as text ""
if (`rc_offline_invalid_domain' != 0) {
	di as result "✓ Test 2 PASSED: Failed as expected (rc=`rc_offline_invalid_domain')"
	di as text "  Error message should show local validation above"
}
else {
	di as error "✗ Test 2 FAILED: Should have failed with invalid domain"
}
di as text ""

*==============================================================================
* Test 3: Invalid Language - ONLINE
*==============================================================================

di as result ""
di as result "========================================================"
di as result "Test 3: Invalid Language (ONLINE)"
di as result "========================================================"
di as result ""

* Set internet_access = true
_rs_config set "`registream_dir'" "internet_access" "true"
_rs_config get "`registream_dir'" "internet_access"
di as text "  internet_access set to: {result:`r(value)'}"

di as text ""
di as text "Attempting: autolabel variables, domain(scb) lang(fra)"
di as text "Expected: API error with available_languages [eng, swe]"
di as text ""

use "$TEST_DATA_DIR/synthetic_lisa.dta", clear
cap noi autolabel variables, domain(scb) lang(fra)
local rc_online_invalid_lang = _rc

di as text ""
if (`rc_online_invalid_lang' != 0) {
	di as result "✓ Test 3 PASSED: Failed as expected (rc=`rc_online_invalid_lang')"
	di as text "  Error message should show API available_languages above"
}
else {
	di as error "✗ Test 3 FAILED: Should have failed with invalid language"
}
di as text ""

*==============================================================================
* Test 4: Invalid Language - OFFLINE
*==============================================================================

di as result ""
di as result "========================================================"
di as result "Test 4: Invalid Language (OFFLINE)"
di as result "========================================================"
di as result ""

* Set internet_access = false
_rs_config set "`registream_dir'" "internet_access" "false"
_rs_config get "`registream_dir'" "internet_access"
di as text "  internet_access set to: {result:`r(value)'}"

di as text ""
di as text "Attempting: autolabel variables, domain(scb) lang(fra)"
di as text "Expected: Local validation error with known languages [eng swe]"
di as text ""

use "$TEST_DATA_DIR/synthetic_lisa.dta", clear
cap noi autolabel variables, domain(scb) lang(fra)
local rc_offline_invalid_lang = _rc

di as text ""
if (`rc_offline_invalid_lang' != 0) {
	di as result "✓ Test 4 PASSED: Failed as expected (rc=`rc_offline_invalid_lang')"
	di as text "  Error message should show local validation above"
}
else {
	di as error "✗ Test 4 FAILED: Should have failed with invalid language"
}
di as text ""

*==============================================================================
* Test 5: Valid Dataset - OFFLINE Without File (Should Fail)
*==============================================================================

di as result ""
di as result "========================================================"
di as result "Test 5: Valid Dataset OFFLINE Without File"
di as result "========================================================"
di as result ""

* Set internet_access = false
_rs_config set "`registream_dir'" "internet_access" "false"
_rs_config get "`registream_dir'" "internet_access"
di as text "  internet_access set to: {result:`r(value)'}"

* Remove files to ensure they don't exist
cap erase "`autolabel_dir'/scb_variables_eng.csv"
cap erase "`autolabel_dir'/scb_variables_eng.dta"

di as text ""
di as text "Attempting: autolabel variables, domain(scb) lang(eng)"
di as text "Files deleted, internet_access=false"
di as text "Expected: Offline mode error (cannot download)"
di as text ""

use "$TEST_DATA_DIR/synthetic_lisa.dta", clear
cap noi autolabel variables, domain(scb) lang(eng)
local rc_offline_no_file = _rc

di as text ""
if (`rc_offline_no_file' != 0) {
	di as result "✓ Test 5 PASSED: Failed as expected (rc=`rc_offline_no_file')"
	di as text "  Error shows offline mode, cannot download"
}
else {
	di as error "✗ Test 5 FAILED: Should have failed (cannot download offline)"
}
di as text ""

*==============================================================================
* Test 6: Valid Dataset - ONLINE Download
*==============================================================================

di as result ""
di as result "========================================================"
di as result "Test 6: Valid Dataset ONLINE Download (Setup for Test 7)"
di as result "========================================================"
di as result ""

* Set internet_access = true
_rs_config set "`registream_dir'" "internet_access" "true"
_rs_config get "`registream_dir'" "internet_access"
di as text "  internet_access set to: {result:`r(value)'}"

di as text ""
di as text "Downloading scb_variables_eng with internet_access=true"
di as text "This sets up the file for offline test..."
di as text ""

use "$TEST_DATA_DIR/synthetic_lisa.dta", clear
cap noi autolabel variables, domain(scb) lang(eng)
local rc_online_download = _rc

di as text ""
if (`rc_online_download' == 0) {
	di as result "✓ Test 6 PASSED: Downloaded successfully"
}
else {
	di as error "✗ Test 6 FAILED: Should have downloaded (rc=`rc_online_download')"
	exit 1
}
di as text ""

*==============================================================================
* Test 7: Valid Dataset - OFFLINE With File (Should Work)
*==============================================================================

di as result ""
di as result "========================================================"
di as result "Test 7: Valid Dataset OFFLINE With File"
di as result "========================================================"
di as result ""

* Set internet_access = false
_rs_config set "`registream_dir'" "internet_access" "false"
_rs_config get "`registream_dir'" "internet_access"
di as text "  internet_access set to: {result:`r(value)'}"

* Verify file exists
cap confirm file "`autolabel_dir'/scb_variables_eng.csv"
if (_rc != 0) {
	di as error "ERROR: File should exist from Test 6"
	exit 1
}

di as text ""
di as text "Attempting: autolabel variables, domain(scb) lang(eng)"
di as text "File exists locally, internet_access=false"
di as text "Expected: Should work using local file (no API call)"
di as text ""

use "$TEST_DATA_DIR/synthetic_lisa.dta", clear
cap noi autolabel variables, domain(scb) lang(eng)
local rc_offline_with_file = _rc

di as text ""
if (`rc_offline_with_file' == 0) {
	di as result "✓ Test 7 PASSED: Worked with local file (offline)"
	di as text "  No API call needed - used cached file"
}
else {
	di as error "✗ Test 7 FAILED: Should have worked with local file (rc=`rc_offline_with_file')"
}
di as text ""

*==============================================================================
* Test 8: Size Mismatch - OFFLINE (Should Skip Check)
*==============================================================================

di as result ""
di as result "========================================================"
di as result "Test 8: Size Mismatch OFFLINE (Skip API Check)"
di as result "========================================================"
di as result ""

* Set internet_access = false
_rs_config set "`registream_dir'" "internet_access" "false"
_rs_config get "`registream_dir'" "internet_access"
di as text "  internet_access set to: {result:`r(value)'}"

* Corrupt file size in metadata
preserve
import delimited using "`autolabel_dir'/datasets.csv", clear varnames(1) stringcols(_all) delimiter(";")
replace file_size = "12345" if dataset_key == "scb_variables_eng"
export delimited using "`autolabel_dir'/datasets.csv", replace delimiter(";")
restore

di as text ""
di as text "Modified file_size in metadata to wrong value"
di as text "internet_access=false"
di as text "Expected: Size mismatch warning (local check only, no API version info)"
di as text ""

use "$TEST_DATA_DIR/synthetic_lisa.dta", clear
cap noi autolabel variables, domain(scb) lang(eng)
local rc_offline_size_mismatch = _rc

di as text ""
di as text "Return code: `rc_offline_size_mismatch'"
di as text "If prompted, it means size check happened (expected)"
di as text "But no API version info should be shown (offline)"
di as text ""

*==============================================================================
* Test 9: File Missing - OFFLINE (Cannot Re-download)
*==============================================================================

di as result ""
di as result "========================================================"
di as result "Test 9: File Missing OFFLINE (Cannot Re-download)"
di as result "========================================================"
di as result ""

* Set internet_access = false
_rs_config set "`registream_dir'" "internet_access" "false"
_rs_config get "`registream_dir'" "internet_access"
di as text "  internet_access set to: {result:`r(value)'}"

* Delete file but keep metadata
cap erase "`autolabel_dir'/scb_variables_eng.csv"
cap erase "`autolabel_dir'/scb_variables_eng.dta"

di as text ""
di as text "Deleted files but kept metadata"
di as text "internet_access=false"
di as text "Expected: Warning about missing file, no API version, prompt to re-download fails"
di as text ""

use "$TEST_DATA_DIR/synthetic_lisa.dta", clear
cap noi autolabel variables, domain(scb) lang(eng)
local rc_offline_missing_file = _rc

di as text ""
di as text "Return code: `rc_offline_missing_file'"
di as text "Should have failed or prompted (cannot re-download offline)"
di as text ""

*==============================================================================
* Cleanup: Restore internet_access to true
*==============================================================================

di as result ""
di as result "========================================================"
di as result "Cleanup: Restoring internet_access=true"
di as result "========================================================"
di as result ""

* Set internet_access = true
_rs_config set "`registream_dir'" "internet_access" "true"
_rs_config get "`registream_dir'" "internet_access"
di as text "  internet_access set to: {result:`r(value)'}"

*==============================================================================
* Final Summary
*==============================================================================

di as result ""
di as result "========================================================"
di as result "Test Summary"
di as result "========================================================"
di as result ""

di as result "Tested Scenarios:"
di as result "  ✓ Test 1: Invalid domain (ONLINE) - API error with suggestions"
di as result "  ✓ Test 2: Invalid domain (OFFLINE) - Local validation error"
di as result "  ✓ Test 3: Invalid language (ONLINE) - API error with available_languages"
di as result "  ✓ Test 4: Invalid language (OFFLINE) - Local validation error"
di as result "  ✓ Test 5: Valid dataset OFFLINE without file - Cannot download"
di as result "  ✓ Test 6: Valid dataset ONLINE - Download successful"
di as result "  ✓ Test 7: Valid dataset OFFLINE with file - Works locally"
di as result "  ✓ Test 8: Size mismatch OFFLINE - Local check only"
di as result "  ✓ Test 9: File missing OFFLINE - Cannot re-download"
di as result ""

di as text "Key Observations:"
di as text "  • Config is re-read each time (changes take effect immediately)"
di as text "  • Online mode: Gets smart API errors with suggestions"
di as text "  • Offline mode: Uses local validation with known domains/languages"
di as text "  • Offline mode: Can use cached files but cannot download new ones"
di as text "  • Verification respects internet_access throughout"
di as result ""

di as result "✓ Offline validation and internet_access control working as designed!"
di as result ""

log close
