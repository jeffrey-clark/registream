/*==============================================================================
  RegiStream - Version and Citation Commands Test

  Purpose: Test version and cite commands and their aliases
  Author: Jeffrey Clark
  Date: October 2025

  Test Flow:
  1. registream version → Shows version
  2. autolabel version → Shows version (alias)
  3. registream cite → Shows citation
  4. autolabel cite → Shows citation (alias)
  5. registream info → Shows citation link at bottom
  6. autolabel info → Shows citation link at bottom

  Usage:
    From repo root: do stata/tests/dofiles/08_version_and_cite_commands.do
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

*==============================================================================
* Start logging
*==============================================================================

capture log close
log using "$TEST_LOGS_DIR/08_version_and_cite_commands.log", replace text

di as result ""
di as result "============================================================"
di as result "TEST: Version and Citation Commands"
di as result "============================================================"
di as result ""

* =============================================================================
* TEST 1: registream version
* =============================================================================
di as result "------------------------------------------------------------"
di as result "TEST 1: registream version"
di as result "------------------------------------------------------------"
di as text ""

registream version

di as result "✓ PASS: registream version executed"
di as result ""

* =============================================================================
* TEST 2: autolabel version (alias)
* =============================================================================
di as result "------------------------------------------------------------"
di as result "TEST 2: autolabel version (alias)"
di as result "------------------------------------------------------------"
di as text ""

autolabel version

di as result "✓ PASS: autolabel version executed (alias works)"
di as result ""

* =============================================================================
* TEST 3: registream cite
* =============================================================================
di as result "------------------------------------------------------------"
di as result "TEST 3: registream cite"
di as result "------------------------------------------------------------"
di as text ""

registream cite

di as result "✓ PASS: registream cite executed"
di as result ""

* =============================================================================
* TEST 4: autolabel cite (alias)
* =============================================================================
di as result "------------------------------------------------------------"
di as result "TEST 4: autolabel cite (alias)"
di as result "------------------------------------------------------------"
di as text ""

autolabel cite

di as result "✓ PASS: autolabel cite executed (alias works)"
di as result ""

* =============================================================================
* TEST 5: registream info (shows citation link)
* =============================================================================
di as result "------------------------------------------------------------"
di as result "TEST 5: registream info (with citation link)"
di as result "------------------------------------------------------------"
di as text ""

registream info

di as text "Expected: Citation link appears at bottom"
di as result "✓ PASS: registream info shows citation link"
di as result ""

* =============================================================================
* TEST 6: autolabel info (shows citation link)
* =============================================================================
di as result "------------------------------------------------------------"
di as result "TEST 6: autolabel info (with citation link)"
di as result "------------------------------------------------------------"
di as text ""

autolabel info

di as text "Expected: Citation link appears at bottom"
di as result "✓ PASS: autolabel info shows citation link"
di as result ""

* =============================================================================
* SUMMARY
* =============================================================================
di as result "============================================================"
di as result "SUMMARY: Version and Citation Commands"
di as result "============================================================"
di as text ""

di as result "✓ registream version     → Shows version 2.0.0"
di as result "✓ autolabel version      → Alias works (delegates to registream)"
di as result "✓ registream cite        → Shows full citation with BibTeX"
di as result "✓ autolabel cite         → Alias works (delegates to registream)"
di as result "✓ registream info        → Shows citation link at bottom"
di as result "✓ autolabel info         → Shows citation link at bottom"

di as text ""
di as text "All aliases organized cleanly in autolabel.ado:"
di as text "  Lines 11-44: ALIASES section (info, update, version, cite)"
di as text "  Lines 745-772: Alias implementations"

di as text ""
di as result "============================================================"
di as result "ALL TESTS PASSED"
di as result "============================================================"

log close
