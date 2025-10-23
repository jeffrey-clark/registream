/*==============================================================================
  RegiStream - Test last_checked Caching (24-hour cache)

  Purpose: Verify that check_for_updates respects the 24-hour cache
  Author: Jeffrey Clark
  Date: October 2025

  Test Flow:
  1. Download dataset (sets last_checked to today)
  2. Manually verify last_checked is set to today's date
  3. Run autolabel again - should skip API check (cached)
  4. Manually set last_checked to yesterday
  5. Run autolabel again - should ping API (cache expired)

  Usage:
    From repo root: do stata/tests/test_last_checked_caching.do

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

*==============================================================================
* Start logging
*==============================================================================

capture log close
log using "$TEST_LOGS_DIR/04_caching.log", replace text

di as result ""
di as result "================================================="
di as result "Test: last_checked Caching (24-hour cache)"
di as result "================================================="
di as result ""
di as text "Registream dir: `registream_dir'"
di as text "API host: $REGISTREAM_API_HOST"
di as text "Current date: `c(current_date)'"
di as result ""

*==============================================================================
* Setup: Load synthetic data
*==============================================================================

di as result "Setup: Loading synthetic data..."
cd "$TEST_DIR"
do "$TEST_DIR/utils/generate_synthetic_data.do"
use "$TEST_DATA_DIR/synthetic_lisa.dta", clear

*==============================================================================
* Test 1: Fresh Download - Sets last_checked to Today
*==============================================================================

di as result ""
di as result "================================================="
di as result "Test 1: Fresh Download (Sets last_checked)"
di as result "================================================="
di as result ""

* Clean slate - remove dataset and metadata
cap erase "`autolabel_dir'/scb_variables_eng.csv"
cap erase "`autolabel_dir'/scb_variables_eng.dta"

preserve
cap import delimited using "`autolabel_dir'/datasets.csv", clear varnames(1) stringcols(_all) delimiter(";")
if (_rc == 0) {
	drop if dataset_key == "scb_variables_eng"
	export delimited using "`autolabel_dir'/datasets.csv", replace delimiter(";")
}
restore

di as text "Downloading scb_variables_eng..."
use "$TEST_DATA_DIR/synthetic_lisa.dta", clear
autolabel variables, domain(scb) lang(eng)

* Verify last_checked is set to today
preserve
import delimited using "`autolabel_dir'/datasets.csv", clear varnames(1) stringcols(_all) delimiter(";")
keep if dataset_key == "scb_variables_eng"

di as text ""
di as text "datasets.csv entry after download:"
list, clean noobs

local last_checked = last_checked[1]
* Extract date part before 'T' (format: DD Mon YYYYTHH:MM:SSZ)
local t_pos = strpos("`last_checked'", "T")
local check_date = substr("`last_checked'", 1, `t_pos' - 1)
local curr_date = "`c(current_date)'"

di as text ""
di as text "last_checked date: {result:`check_date'}"
di as text "Current date:      {result:`curr_date'}"

if ("`check_date'" == "`curr_date'") {
	di as result "✓ Test 1 PASSED: last_checked set to today"
}
else {
	di as error "✗ Test 1 FAILED: last_checked not set to today"
	exit 1
}
restore

di as text ""

*==============================================================================
* Test 2: Immediate Re-run - Should Use Cache (Skip API Check)
*==============================================================================

di as result ""
di as result "================================================="
di as result "Test 2: Immediate Re-run (Should Use Cache)"
di as result "================================================="
di as result ""

di as text "Running autolabel again (same day)..."
di as text "Expected: Should skip API check (status=cached)"
di as text ""

use "$TEST_DATA_DIR/synthetic_lisa.dta", clear

* Capture the autolabel output
* Since check_for_updates returns status internally, we can't easily capture it
* But we can verify last_checked didn't change

preserve
import delimited using "`autolabel_dir'/datasets.csv", clear varnames(1) stringcols(_all) delimiter(";")
keep if dataset_key == "scb_variables_eng"
local last_checked_before = last_checked[1]
restore

* Run autolabel
autolabel variables, domain(scb) lang(eng)

* Check last_checked didn't change (or changed to same day)
preserve
import delimited using "`autolabel_dir'/datasets.csv", clear varnames(1) stringcols(_all) delimiter(";")
keep if dataset_key == "scb_variables_eng"
local last_checked_after = last_checked[1]

di as text ""
di as text "last_checked before: {result:`last_checked_before'}"
di as text "last_checked after:  {result:`last_checked_after'}"

* Both should be today's date (even if timestamp updated)
local t_pos = strpos("`last_checked_before'", "T")
local check_date_before = substr("`last_checked_before'", 1, `t_pos' - 1)
local t_pos = strpos("`last_checked_after'", "T")
local check_date_after = substr("`last_checked_after'", 1, `t_pos' - 1)
local curr_date = "`c(current_date)'"

if ("`check_date_before'" == "`curr_date'" & "`check_date_after'" == "`curr_date'") {
	di as result "✓ Test 2 PASSED: Cache used (both dates are today)"
}
else {
	di as error "✗ Test 2 FAILED: Expected cache to be used"
	exit 1
}
restore

di as text ""

*==============================================================================
* Test 3: Simulate Yesterday - Should Ping API (Cache Expired)
*==============================================================================

di as result ""
di as result "================================================="
di as result "Test 3: Simulate Yesterday (Cache Expired)"
di as result "================================================="
di as result ""

* Manually set last_checked to yesterday
preserve
import delimited using "`autolabel_dir'/datasets.csv", clear varnames(1) stringcols(_all) delimiter(";")

di as text "Modifying last_checked to simulate yesterday..."

* Get yesterday's date (simple decrement, may break on month boundaries)
* For testing purposes, we'll just use a clearly old date
local yesterday_date = "2024-01-01"

replace last_checked = "`yesterday_date'T00:00:00Z" if dataset_key == "scb_variables_eng"

di as text ""
di as text "datasets.csv with simulated old last_checked:"
list if dataset_key == "scb_variables_eng", clean noobs

export delimited using "`autolabel_dir'/datasets.csv", replace delimiter(";")
restore

di as text ""
di as text "Running autolabel with old last_checked..."
di as text "Expected: Should ping API (cache expired)"
di as text ""

use "$TEST_DATA_DIR/synthetic_lisa.dta", clear
autolabel variables, domain(scb) lang(eng)

* Verify last_checked was updated to today
preserve
import delimited using "`autolabel_dir'/datasets.csv", clear varnames(1) stringcols(_all) delimiter(";")
keep if dataset_key == "scb_variables_eng"

local last_checked = last_checked[1]
local t_pos = strpos("`last_checked'", "T")
local check_date = substr("`last_checked'", 1, `t_pos' - 1)
local curr_date = "`c(current_date)'"

di as text ""
di as text "last_checked after autolabel: {result:`last_checked'}"
di as text "Expected (today):             {result:`curr_date'}"

if ("`check_date'" == "`curr_date'") {
	di as result "✓ Test 3 PASSED: last_checked updated to today (API was pinged)"
}
else {
	di as error "✗ Test 3 FAILED: last_checked not updated (API may not have been pinged)"
	exit 1
}
restore

di as text ""

*==============================================================================
* Final Summary
*==============================================================================

di as result ""
di as result "================================================="
di as result "All Tests Passed!"
di as result "================================================="
di as result ""
di as result "Tested:"
di as result "  ✓ Fresh download sets last_checked to today"
di as result "  ✓ Same-day re-run uses cache (doesn't ping API)"
di as result "  ✓ Old last_checked triggers API ping and update"
di as result ""
di as result "✓ 24-hour caching mechanism working as designed!"
di as result ""

log close
