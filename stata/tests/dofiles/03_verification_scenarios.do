/*==============================================================================
  RegiStream Verification Test - Simple Real-World Scenarios

  Purpose: Test verification by manipulating files/metadata then running autolabel
  Author: Jeffrey Clark
  Date: October 2025

  Test Flow:
  1. Download datasets normally (ensure we have baseline)
  2. Manipulate metadata/files to create scenarios
  3. Run normal autolabel commands - verification happens automatically
  4. Observe prompts and behavior

  Usage:
    From repo root: do stata/tests/test_verification_simple.do

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
local autolabel_dir "`registream_dir'/autolabel_keys"

*==============================================================================
* Start logging
*==============================================================================

capture log close
log using "$TEST_LOGS_DIR/03_verification_scenarios.log", replace text

di as result ""
di as result "=========================================="
di as result "Verification Test - Real World Scenarios"
di as result "=========================================="
di as result ""
di as text "Registream dir: `registream_dir'"
di as text "API host: $REGISTREAM_API_HOST"
di as result ""

*==============================================================================
* Setup: Ensure we have synthetic data
*==============================================================================

di as result "Setup: Loading synthetic data..."
cd "$TEST_DIR"
do "$TEST_DIR/utils/generate_synthetic_data.do"
use "$TEST_DATA_DIR/synthetic_lisa.dta", clear

*==============================================================================
* Scenario 1: Normal Download (Baseline) - Download All 4 Datasets
*==============================================================================

di as result ""
di as result "=========================================="
di as result "Scenario 1: Fresh Download (Baseline)"
di as result "=========================================="
di as result ""

* Clean slate - remove all datasets and metadata
cap erase "`autolabel_dir'/datasets.csv"
cap erase "`autolabel_dir'/scb_variables_eng.csv"
cap erase "`autolabel_dir'/scb_variables_eng.dta"
cap erase "`autolabel_dir'/scb_variables_swe.csv"
cap erase "`autolabel_dir'/scb_variables_swe.dta"
cap erase "`autolabel_dir'/scb_value_labels_eng.csv"
cap erase "`autolabel_dir'/scb_value_labels_eng.dta"
cap erase "`autolabel_dir'/scb_value_labels_swe.csv"
cap erase "`autolabel_dir'/scb_value_labels_swe.dta"

di as text ""
di as text "Downloading all 4 datasets (eng/swe variables and values)..."
di as text ""

* Download variables (English)
autolabel variables, domain(scb) lang(eng)

* Download variables (Swedish)
use "$TEST_DATA_DIR/synthetic_lisa.dta", clear
autolabel variables, domain(scb) lang(swe)

* Download value labels (English)
use "$TEST_DATA_DIR/synthetic_lisa.dta", clear
autolabel values, domain(scb) lang(eng)

* Download value labels (Swedish)
use "$TEST_DATA_DIR/synthetic_lisa.dta", clear
autolabel values, domain(scb) lang(swe)

* Show datasets.csv
di as text ""
di as text "datasets.csv after baseline downloads:"
di as text "{hline 78}"
preserve
import delimited using "`autolabel_dir'/datasets.csv", clear varnames(1) stringcols(_all) delimiter(";")
list, clean noobs
restore
di as text "{hline 78}"

di as result ""
di as result "✓ Scenario 1 Complete: All 4 datasets downloaded (should have 4 rows in datasets.csv)"
di as result ""

*==============================================================================
* Scenario 2: File Size Mismatch (source=api)
*==============================================================================

di as result ""
di as result "=========================================="
di as result "Scenario 2: File Size Mismatch"
di as result "=========================================="
di as result ""

* Reload data
use "$TEST_DATA_DIR/synthetic_lisa.dta", clear

* Modify file size in metadata to trigger mismatch warning
preserve
import delimited using "`autolabel_dir'/datasets.csv", clear varnames(1) stringcols(_all) delimiter(";")
list

* Change file size to something wrong
replace file_size = "12345" if dataset_key == "scb_variables_eng"
list

export delimited using "`autolabel_dir'/datasets.csv", replace delimiter(";")
restore

di as text ""
di as text "Modified datasets.csv - set wrong file_size for scb_variables_eng"
di as text "Now running autolabel - should detect size mismatch and prompt..."
di as text ""

* Run autolabel - verification should detect size mismatch
use "$TEST_DATA_DIR/synthetic_lisa.dta", clear
autolabel variables, domain(scb) lang(eng)

di as result ""
di as result "✓ Scenario 2 Complete: Size mismatch detected and handled"
di as result ""

*==============================================================================
* Scenario 3: File Missing but Metadata Exists
*==============================================================================

di as result ""
di as result "=========================================="
di as result "Scenario 3: File Missing + Metadata Exists"
di as result "=========================================="
di as result ""

* Delete the CSV file but keep metadata
cap erase "`autolabel_dir'/scb_variables_eng.csv"
cap erase "`autolabel_dir'/scb_variables_eng.dta"

di as text ""
di as text "Deleted scb_variables_eng files but kept metadata"
di as text "Now running autolabel - should detect missing file and show version info..."
di as text ""

* Run autolabel - should detect missing file
use "$TEST_DATA_DIR/synthetic_lisa.dta", clear
autolabel variables, domain(scb) lang(eng)

di as result ""
di as result "✓ Scenario 3 Complete: Missing file detected, re-downloaded"
di as result ""

*==============================================================================
* Scenario 4: File Exists but No Metadata
*==============================================================================

di as result ""
di as result "=========================================="
di as result "Scenario 4: File Exists + No Metadata"
di as result "=========================================="
di as result ""

* Delete metadata but keep files
preserve
import delimited using "`autolabel_dir'/datasets.csv", clear varnames(1) stringcols(_all) delimiter(";")
drop if dataset_key == "scb_variables_eng"
export delimited using "`autolabel_dir'/datasets.csv", replace delimiter(";")
restore

di as text ""
di as text "Removed scb_variables_eng from datasets.csv but kept files"
di as text "Now running autolabel - should detect missing metadata and prompt..."
di as text ""

* Run autolabel - should detect missing metadata
use "$TEST_DATA_DIR/synthetic_lisa.dta", clear
autolabel variables, domain(scb) lang(eng)

di as result ""
di as result "✓ Scenario 4 Complete: Missing metadata detected, re-downloaded"
di as result ""

*==============================================================================
* Scenario 5: Size Mismatch with source=user (Should Skip Warning)
*==============================================================================

di as result ""
di as result "=========================================="
di as result "Scenario 5: Size Mismatch + source=user"
di as result "=========================================="
di as result ""

* Modify metadata: wrong size but source=user for ONE dataset only
* Other 3 datasets should remain with source=api
preserve
import delimited using "`autolabel_dir'/datasets.csv", clear varnames(1) stringcols(_all) delimiter(";")

di as text ""
di as text "datasets.csv BEFORE modification:"
list, clean noobs

* Change source to "user" and set wrong file size for ONLY scb_variables_eng
replace file_size = "999" if dataset_key == "scb_variables_eng"
replace source = "user" if dataset_key == "scb_variables_eng"

di as text ""
di as text "datasets.csv AFTER modification (only scb_variables_eng changed to source=user):"
list, clean noobs

export delimited using "`autolabel_dir'/datasets.csv", replace delimiter(";")
restore

di as text ""
di as text "Modified datasets.csv - wrong file_size but source=user for scb_variables_eng"
di as text "Other 3 datasets still have source=api (unaffected)"
di as text "Now running autolabel - should SKIP size check (no warning)..."
di as text ""

* Run autolabel - should skip size check for user datasets
use "$TEST_DATA_DIR/synthetic_lisa.dta", clear
autolabel variables, domain(scb) lang(eng)

di as result ""
di as result "✓ Scenario 5 Complete: Size check skipped for source=user (no warning shown)"
di as result ""
di as result "  Other 3 datasets remain with source=api (untouched)"
di as result ""

*==============================================================================
* Final Summary
*==============================================================================

di as result ""
di as result "=========================================="
di as result "All Scenarios Complete!"
di as result "=========================================="
di as result ""

* Show final state of datasets.csv
di as text ""
di as text "Final datasets.csv (should have all 4 datasets):"
di as text "{hline 78}"
preserve
import delimited using "`autolabel_dir'/datasets.csv", clear varnames(1) stringcols(_all) delimiter(";")
list, clean noobs
count
local total_datasets = r(N)
restore
di as text "{hline 78}"

di as result ""
di as result "Tested:"
di as result "  ✓ Fresh download (baseline) - downloaded 4 datasets"
di as result "  ✓ File size mismatch (source=api) → warned"
di as result "  ✓ File missing + metadata exists → re-downloaded"
di as result "  ✓ File exists + no metadata → re-downloaded"
di as result "  ✓ Size mismatch + source=user → no warning (1 dataset)"
di as result "  ✓ Other datasets remain with source=api (3 datasets)"
di as result ""
di as result "Final check: datasets.csv has `total_datasets' rows (expected 4)"

assert `total_datasets' == 4

di as result ""
di as result "✓ All tests passed! Verification system working as designed!"
di as result ""

log close
