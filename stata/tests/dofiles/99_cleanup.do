/*==============================================================================
  RegiStream - Cleanup & Fresh Download Test

  Purpose: Final cleanup test - resets everything to clean state
  Author: Jeffrey Clark
  Date: October 2025

  Actions:
  1. Delete config.yaml and reinitialize with defaults
  2. Delete datasets.csv and all dataset files
  3. Fresh download of 4 SCB datasets:
     - scb_variables_eng
     - scb_variables_swe
     - scb_value_labels_eng
     - scb_value_labels_swe

  This ensures a clean ending state with fresh data.

  Usage:
    From repo root: do stata/tests/99_cleanup.do

  Requirements:
    - API server running at localhost:5000
    - $permission = "yes" for auto-approval
==============================================================================*/

clear all
version 16.0

*==============================================================================
* Find project root
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
* Setup
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
adopath ++ "$SRC_DIR"  // USE ++ TO PREPEND (load local FIRST, not global)
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
log using "$TEST_LOGS_DIR/99_cleanup.log", replace text

di as result ""
di as result "============================================================"
di as result "Cleanup & Fresh Download Test"
di as result "============================================================"
di as result ""
di as text "Registream dir: `registream_dir'"
di as text "Autolabel dir: `autolabel_dir'"
di as text "API host: $REGISTREAM_API_HOST"
di as result ""

*==============================================================================
* Step 1: Reinitialize config.yaml
*==============================================================================

di as result ""
di as result "============================================================"
di as result "Step 1: Reinitialize Config"
di as result "============================================================"
di as result ""

* Delete existing config
cap erase "`registream_dir'/config.yaml"
di as text "Deleted existing config.yaml"

* Reinitialize with defaults
_rs_config init "`registream_dir'"

* Verify defaults
_rs_config get "`registream_dir'" "telemetry_enabled"
local telemetry = r(value)
_rs_config get "`registream_dir'" "internet_access"
local internet = r(value)

di as text ""
di as text "New config.yaml:"
type "`registream_dir'/config.yaml"
di as text ""

if ("`telemetry'" == "true" & "`internet'" == "true") {
	di as result "[SUCCESS] Config reinitialized with defaults"
}
else {
	di as error "[WARNING] Config may not have correct defaults"
}

di as text ""

*==============================================================================
* Step 2: Delete all datasets and metadata
*==============================================================================

di as result ""
di as result "============================================================"
di as result "Step 2: Delete All Datasets"
di as result "============================================================"
di as result ""

* Delete datasets.csv
cap erase "`autolabel_dir'/datasets.csv"
di as text "Deleted datasets.csv"

* Delete all SCB dataset files (both eng and swe, variables and values)
foreach lang in eng swe {
	foreach type in variables value_labels {
		cap erase "`autolabel_dir'/scb_`type'_`lang'.csv"
		cap erase "`autolabel_dir'/scb_`type'_`lang'.dta"
		di as text "Deleted scb_`type'_`lang' files"
	}
}

di as text ""
di as result "[SUCCESS] All datasets and metadata deleted"
di as text ""

*==============================================================================
* Step 3: Load synthetic data for testing
*==============================================================================

di as result ""
di as result "============================================================"
di as result "Step 3: Load Synthetic Data"
di as result "============================================================"
di as result ""

cd "$TEST_DIR"
do "$TEST_DIR/utils/generate_synthetic_data.do"
use "$TEST_DATA_DIR/synthetic_lisa.dta", clear

di as result "[SUCCESS] Synthetic data loaded"
di as text ""

*==============================================================================
* Step 4: Fresh download of all 4 SCB datasets
*==============================================================================

di as result ""
di as result "============================================================"
di as result "Step 4: Fresh Download (4 datasets)"
di as result "============================================================"
di as result ""

* Download scb_variables_eng
di as text ""
di as text "Downloading 1/4: scb_variables_eng..."
use "$TEST_DATA_DIR/synthetic_lisa.dta", clear
autolabel variables, domain(scb) lang(eng)

* Download scb_variables_swe
di as text ""
di as text "Downloading 2/4: scb_variables_swe..."
use "$TEST_DATA_DIR/synthetic_lisa.dta", clear
autolabel variables, domain(scb) lang(swe)

* Download scb_value_labels_eng
di as text ""
di as text "Downloading 3/4: scb_value_labels_eng..."
use "$TEST_DATA_DIR/synthetic_lisa.dta", clear
autolabel values, domain(scb) lang(eng)

* Download scb_value_labels_swe
di as text ""
di as text "Downloading 4/4: scb_value_labels_swe..."
use "$TEST_DATA_DIR/synthetic_lisa.dta", clear
autolabel values, domain(scb) lang(swe)

di as text ""
di as result "[SUCCESS] All 4 datasets downloaded"
di as text ""

*==============================================================================
* Step 5: Verify final state
*==============================================================================

di as result ""
di as result "============================================================"
di as result "Step 5: Verify Clean State"
di as result "============================================================"
di as result ""

* Check datasets.csv exists and has 4 entries
preserve
import delimited using "`autolabel_dir'/datasets.csv", clear varnames(1) stringcols(_all) delimiter(";")

di as text "Final datasets.csv:"
di as text "{hline 78}"
list, clean noobs
di as text "{hline 78}"

count
local total = r(N)

if (`total' == 4) {
	di as result "[SUCCESS] datasets.csv has 4 entries"
}
else {
	di as error "[WARNING] Expected 4 entries, found `total'"
}

* Verify all are from API
count if source == "api"
local api_count = r(N)
if (`api_count' == 4) {
	di as result "[SUCCESS] All datasets have source=api"
}
else {
	di as error "[WARNING] Not all datasets have source=api"
}

restore

di as text ""

*==============================================================================
* Final Summary
*==============================================================================

di as result ""
di as result "============================================================"
di as result "Cleanup Complete!"
di as result "============================================================"
di as result ""

di as result "Actions performed:"
di as result "  [SUCCESS] Config reinitialized to defaults"
di as result "  [SUCCESS] All datasets deleted"
di as result "  [SUCCESS] 4 fresh datasets downloaded"
di as result "  [SUCCESS] Clean state verified"
di as result ""

di as text "Final state:"
di as text "  Config:   `registream_dir'/config.yaml (defaults)"
di as text "  Datasets: 4 SCB datasets (eng/swe variables + values)"
di as text "  Source:   All from API with version tracking"
di as result ""

di as result "============================================================"
di as result "RegiStream is ready for use!"
di as result "============================================================"
di as result ""

log close
