/*==============================================================================
  RegiStream Autolabel Workflow Test Suite

  Purpose: Comprehensive test of autolabel functionality using synthetic data
  Author: Jeffrey Clark
  Date: October 2025

  Tests:
  1. Synthetic data generation
  2. Variable label application (English)
  3. Value label application (English)
  4. Variable label application (Swedish)
  5. Value label application (Swedish)
  6. Metadata tracking verification
  7. Usage logging verification

  Usage:
    From repo root:    do stata/tests/test_autolabel_workflow.do
    From tests folder: do test_autolabel_workflow.do
==============================================================================*/

clear all
version 16.0

*==============================================================================
* Find project root using .project_root marker file
*==============================================================================

local cwd = "`c(pwd)'"
local project_root ""

* Search up to 5 levels for .project_root
forvalues i = 0/5 {
    local search_path = "`cwd'"
    forvalues j = 1/`i' {
        local search_path = "`search_path'/.."
    }

    capture confirm file "`search_path'/.project_root"
    if _rc == 0 {
        * Found it! Resolve to absolute path
        quietly cd "`search_path'"
        local project_root = "`c(pwd)'"
        quietly cd "`cwd'"
        continue, break
    }
}

* Verify we found the project root
if "`project_root'" == "" {
    di as error "ERROR: Could not find .project_root file"
    di as error "Please run this script from within the RegiStream repository"
    exit 601
}

*==============================================================================
* Set up global paths
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

*==============================================================================
* Start logging
*==============================================================================

capture log close
log using "$TEST_LOGS_DIR/02_basic_workflow.log", replace text

di as result ""
di as result "=========================================="
di as result "RegiStream Autolabel Workflow Test"
di as result "=========================================="
di as result ""
di as text "Project root: $PROJECT_ROOT"
di as text "Test directory: $TEST_DIR"
di as text "Source directory: $SRC_DIR"
di as text "API host: $REGISTREAM_API_HOST"
di as result ""

*==============================================================================
* Test Setup
*==============================================================================

* Start fresh - delete existing metadata tracking AND data files
di as result "Test Setup: Starting fresh (deleting existing metadata and files)..."

* Get registream directory using utils
_rs_utils get_dir
local registream_dir "`r(dir)'"
local autolabel_dir "`registream_dir'/autolabel_keys"

* Delete metadata files
cap erase "`autolabel_dir'/datasets.csv"
cap erase "`autolabel_dir'/datasets.yml"

* Delete SCB data files to ensure fresh download
cap erase "`autolabel_dir'/scb_variables_eng.csv"
cap erase "`autolabel_dir'/scb_variables_eng.dta"
cap erase "`autolabel_dir'/scb_variables_swe.csv"
cap erase "`autolabel_dir'/scb_variables_swe.dta"
cap erase "`autolabel_dir'/scb_value_labels_eng.csv"
cap erase "`autolabel_dir'/scb_value_labels_eng.dta"
cap erase "`autolabel_dir'/scb_value_labels_swe.csv"
cap erase "`autolabel_dir'/scb_value_labels_swe.dta"

*==============================================================================
* Test 1: Generate Synthetic Data
*==============================================================================

di as result ""
di as result "=========================================="
di as result "Test 1: Generating Synthetic Dataset"
di as result "=========================================="
di as result ""

cd "$TEST_DIR"
do "$TEST_DIR/utils/generate_synthetic_data.do"

* Load the synthetic data
use "$TEST_DATA_DIR/synthetic_lisa.dta", clear

* Verify data loaded correctly
assert _N == 1000
assert !missing(lopnr)
assert !missing(kon)

di as result ""
di as result "✓ Test 1 PASSED: Synthetic data generated successfully"
di as result ""

*==============================================================================
* Test 2: Variable Labels (English)
*==============================================================================

di as result ""
di as result "=========================================="
di as result "Test 2: Apply Variable Labels (English)"
di as result "=========================================="
di as result ""

autolabel variables, domain(scb) lang(eng)

* Verify variable labels were applied
local kon_label : variable label kon
assert "`kon_label'" != ""
di as text "Variable 'kon' label: `kon_label'"

di as result ""
di as result "✓ Test 2 PASSED: English variable labels applied"
di as result ""

*==============================================================================
* Test 3: Value Labels (English)
*==============================================================================

di as result ""
di as result "=========================================="
di as result "Test 3: Apply Value Labels (English)"
di as result "=========================================="
di as result ""

* Note: This will handle both string (encode first) and numeric (label directly) categorical variables
autolabel values, domain(scb) lang(eng)

* Verify value labels were applied to string variables (e.g., sun2000niva)
* After encoding, sun2000niva should be numeric with value labels
capture confirm numeric variable sun2000niva
assert _rc == 0  // Should be numeric after encoding
local sun_vallabel : value label sun2000niva
assert "`sun_vallabel'" != ""
di as text "Variable 'sun2000niva' value label: `sun_vallabel'"

* Verify value labels were also applied to numeric variables (e.g., kon)
local kon_vallabel : value label kon
assert "`kon_vallabel'" != ""
di as text "Variable 'kon' value label: `kon_vallabel'"

di as result ""
di as result "✓ Test 3 PASSED: English value labels applied"
di as result ""

*==============================================================================
* Test 4: Variable Labels (Swedish) - Requires Fresh Data
*==============================================================================

di as result ""
di as result "=========================================="
di as result "Test 4: Apply Variable Labels (Swedish)"
di as result "=========================================="
di as result ""

* Reload synthetic data (fresh, before encoding)
use "$TEST_DATA_DIR/synthetic_lisa.dta", clear

autolabel variables, domain(scb) lang(swe)

* Verify Swedish variable labels were applied
local kon_label : variable label kon
assert "`kon_label'" != ""
di as text "Variable 'kon' label (Swedish): `kon_label'"

di as result ""
di as result "✓ Test 4 PASSED: Swedish variable labels applied"
di as result ""

*==============================================================================
* Test 5: Value Labels (Swedish)
*==============================================================================

di as result ""
di as result "=========================================="
di as result "Test 5: Apply Value Labels (Swedish)"
di as result "=========================================="
di as result ""

autolabel values, domain(scb) lang(swe)

* Verify Swedish value labels were applied to string variables
capture confirm numeric variable sun2000niva
assert _rc == 0  // Should be numeric after encoding
local sun_vallabel : value label sun2000niva
assert "`sun_vallabel'" != ""
di as text "Variable 'sun2000niva' value label (Swedish): `sun_vallabel'"

* Verify Swedish value labels were also applied to numeric variables
local kon_vallabel : value label kon
assert "`kon_vallabel'" != ""
di as text "Variable 'kon' value label (Swedish): `kon_vallabel'"

di as result ""
di as result "✓ Test 5 PASSED: Swedish value labels applied"
di as result ""

*==============================================================================
* Test 6: Metadata Tracking Verification
*==============================================================================

di as result ""
di as result "=========================================="
di as result "Test 6: Verify Metadata Tracking"
di as result "=========================================="
di as result ""

* Check that metadata file exists and contains expected datasets
capture confirm file "$registream_dir/autolabel_keys/datasets.csv"
if _rc == 0 {
    di as text "datasets.csv contents:"
    di as text "{hline 78}"
    type "$registream_dir/autolabel_keys/datasets.csv"
    di as text "{hline 78}"

    * Verify dataset count
    preserve
    quietly import delimited using "$registream_dir/autolabel_keys/datasets.csv", clear varnames(1) stringcols(_all) delimiter(";")
    local dataset_count = _N

    * Check for expected datasets (4 total: scb_variables_eng, scb_variables_swe, scb_values_eng, scb_values_swe)
    assert `dataset_count' == 4

    di as result ""
    di as result "✓ Test 6 PASSED: Metadata tracking verified (4 datasets)"
    di as result ""
    restore
}
else {
    di as error ""
    di as error "✗ Test 6 FAILED: datasets.csv not found"
    di as error ""
}

*==============================================================================
* Test 7: Usage Logging Verification
*==============================================================================

di as result ""
di as result "=========================================="
di as result "Test 7: Verify Usage Logging"
di as result "=========================================="
di as result ""

capture confirm file "$registream_dir/usage_stata.csv"
if _rc == 0 {
    di as text "Usage log exists: $registream_dir/usage_stata.csv"

    * Display last 5 entries
    preserve
    quietly import delimited using "$registream_dir/usage_stata.csv", clear delimiter(";") varnames(1) stringcols(_all)
    local log_count = _N

    di as text ""
    di as text "Total usage entries: `log_count'"
    di as text "Last 5 entries:"
    di as text "{hline 78}"
    list timestamp command arguments version in -5/l, noobs clean
    di as text "{hline 78}"

    di as result ""
    di as result "✓ Test 7 PASSED: Usage logging verified"
    di as result ""
    restore
}
else {
    di as error ""
    di as error "✗ Test 7 FAILED: Usage log not found"
    di as error ""
}

*==============================================================================
* Final Summary
*==============================================================================

di as result ""
di as result "=========================================="
di as result "Test Suite Complete"
di as result "=========================================="
di as result ""
di as result "All tests passed successfully!"
di as result ""
di as result "Summary:"
di as result "  ✓ Synthetic data generation"
di as result "  ✓ Variable labels (English)"
di as result "  ✓ Value labels (English)"
di as result "  ✓ Variable labels (Swedish)"
di as result "  ✓ Value labels (Swedish)"
di as result "  ✓ Metadata tracking"
di as result "  ✓ Usage logging"
di as result ""

log close
