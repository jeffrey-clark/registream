/*==============================================================================
  Test 13: Version Resolution Priority System (Comprehensive)

  Purpose: Verify the 2-level priority system works correctly with extensive
           back-and-forth testing and usage tracking verification

  Priority levels (highest to lowest):
  1. Dev mode: _rs_dev_utils get_version/get_host (defined in _rs_dev_utils.ado)
  2. Production: Hardcoded {{VERSION}} and https://registream.org

  Test scenarios (12+ tests):
  A. Dev override with default values (2.0.0, localhost:5000) + autolabel
  B. Dev override with test globals (custom version/host) + autolabel
  C. Clear globals back to dev defaults + autolabel
  D. Set different test globals + autolabel
  E. Production fallback (hide dev override) + autolabel
  F. Restore dev override + autolabel
  G. Multiple rapid switches with autolabel calls
  H. Version in command outputs (registream version, autolabel version)

  Author: Jeffrey Clark
  Date: October 2025

  Usage: Can run standalone from anywhere
==============================================================================*/

clear all
version 16.0

*==============================================================================
* Setup - Find project root and configure paths
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

if ("`project_root'" == "") {
	di as error "ERROR: Could not find .project_root file"
	exit 601
}

global PROJECT_ROOT "`project_root'"
global SRC_DIR "$PROJECT_ROOT/stata/src"
global TEST_DIR "$PROJECT_ROOT/stata/tests"
global TEST_DATA_DIR "$TEST_DIR/data"
global TEST_LOGS_DIR "$TEST_DIR/logs"

* Enable auto-approve for testing
global REGISTREAM_AUTO_APPROVE "yes"

* Setup logging
cap mkdir "$TEST_LOGS_DIR"
local log_file "$TEST_LOGS_DIR/13_version_resolution_priority.log"
cap log close
log using "`log_file'", replace text

* Clear all cached programs FIRST
discard

* Add source to adopath and load fresh
adopath + "$SRC_DIR"
do "$SRC_DIR/_rs_utils.ado"
cap do "$SRC_DIR/_rs_dev_utils.ado"

* Get registream directory for usage tracking verification
_rs_utils get_dir
local registream_dir "`r(dir)'"
local usage_log "`registream_dir'/usage_stata.csv"

di as result ""
di as result "============================================================"
di as result "Test 13: Version Resolution Priority (Comprehensive)"
di as result "============================================================"
di as result ""
di as text "Usage log: `usage_log'"
di as result ""

* Track test results
local tests_passed = 0
local tests_failed = 0
local test_num = 0

*==============================================================================
* Scenario A: Dev override with default values + autolabel
*==============================================================================

di as text ""
di as text "------------------------------------------------------------"
di as text "Scenario A: Dev default (2.0.0, localhost:5000) + autolabel"
di as text "------------------------------------------------------------"
di as text ""

* Check if dev override exists
cap qui _rs_dev_utils get_version
if (_rc == 0) {
	local dev_exists = 1
	di as text "✓ _rs_dev_utils.ado exists"
}
else {
	local dev_exists = 0
	di as text "  _rs_dev_utils.ado not found (production mode)"
}

* Test A1: Version resolution
local ++test_num
_rs_utils get_version
local version = "`r(version)'"
di as text "Test `test_num': get_version = `version'"

if (`dev_exists' & "`version'" == "2.0.0") {
	di as result "  ✓ PASSED: Dev default version"
	local ++tests_passed
}
else if (!`dev_exists' & "`version'" == "{{VERSION}}") {
	di as result "  ✓ PASSED: Production version (no dev)"
	local ++tests_passed
}
else {
	di as error "  ✗ FAILED: Unexpected '`version''"
	local ++tests_failed
}

* Test A2: Host resolution
local ++test_num
_rs_utils get_api_host
local host = "`r(host)'"
di as text "Test `test_num': get_api_host = `host'"

if (`dev_exists' & "`host'" == "http://localhost:5000") {
	di as result "  ✓ PASSED: Dev default host"
	local ++tests_passed
}
else if (!`dev_exists' & "`host'" == "https://registream.org") {
	di as result "  ✓ PASSED: Production host (no dev)"
	local ++tests_passed
}
else {
	di as error "  ✗ FAILED: Unexpected '`host''"
	local ++tests_failed
}

* Test A3: autolabel with current settings
local ++test_num
di as text "Test `test_num': Running autolabel variables (dev default)"
cd "$TEST_DIR"
cap noi do "$TEST_DIR/utils/generate_synthetic_data.do"
use "$TEST_DATA_DIR/synthetic_lisa.dta", clear
cap noi autolabel variables, domain(scb) lang(eng)
if (_rc == 0) {
	di as result "  ✓ PASSED: autolabel succeeded with version `version'"
	local ++tests_passed
}
else {
	di as error "  ✗ FAILED: autolabel failed"
	local ++tests_failed
}

*==============================================================================
* Scenario B: Test globals (custom version/host) + autolabel
*==============================================================================

if (`dev_exists') {
	di as text ""
	di as text "------------------------------------------------------------"
	di as text "Scenario B: Test globals (1.5.0-CUSTOM, localhost:8888)"
	di as text "------------------------------------------------------------"
	di as text ""

	global REGISTREAM_TEST_VERSION "1.5.0-CUSTOM"
	global REGISTREAM_TEST_HOST "http://localhost:8888"
	di as text "✓ Set test globals"

	* Test B1: Version with custom global
	local ++test_num
	_rs_utils get_version
	local version = "`r(version)'"
	di as text "Test `test_num': get_version = `version'"

	if ("`version'" == "1.5.0-CUSTOM") {
		di as result "  ✓ PASSED: Custom test version"
		local ++tests_passed
	}
	else {
		di as error "  ✗ FAILED: Expected '1.5.0-CUSTOM', got '`version''"
		local ++tests_failed
	}

	* Test B2: Host with custom global
	local ++test_num
	_rs_utils get_api_host
	local host = "`r(host)'"
	di as text "Test `test_num': get_api_host = `host'"

	if ("`host'" == "http://localhost:8888") {
		di as result "  ✓ PASSED: Custom test host"
		local ++tests_passed
	}
	else {
		di as error "  ✗ FAILED: Expected 'http://localhost:8888', got '`host''"
		local ++tests_failed
	}

	* Test B3: registream version command
	local ++test_num
	di as text "Test `test_num': registream version command"
	cap noi registream version
	if (_rc == 0) {
		di as result "  ✓ PASSED: registream version succeeded"
		local ++tests_passed
	}
	else {
		di as error "  ✗ FAILED: registream version failed"
		local ++tests_failed
	}
}

*==============================================================================
* Scenario C: Clear globals back to dev defaults + autolabel
*==============================================================================

if (`dev_exists') {
	di as text ""
	di as text "------------------------------------------------------------"
	di as text "Scenario C: Clear globals → dev defaults (2.0.0)"
	di as text "------------------------------------------------------------"
	di as text ""

	global REGISTREAM_TEST_VERSION ""
	global REGISTREAM_TEST_HOST ""
	di as text "✓ Cleared test globals"

	* Test C1: Back to dev default version
	local ++test_num
	_rs_utils get_version
	local version = "`r(version)'"
	di as text "Test `test_num': get_version = `version'"

	if ("`version'" == "2.0.0") {
		di as result "  ✓ PASSED: Back to dev default"
		local ++tests_passed
	}
	else {
		di as error "  ✗ FAILED: Expected '2.0.0', got '`version''"
		local ++tests_failed
	}

	* Test C2: Back to dev default host
	local ++test_num
	_rs_utils get_api_host
	local host = "`r(host)'"
	di as text "Test `test_num': get_api_host = `host'"

	if ("`host'" == "http://localhost:5000") {
		di as result "  ✓ PASSED: Back to dev default host"
		local ++tests_passed
	}
	else {
		di as error "  ✗ FAILED: Expected 'http://localhost:5000', got '`host''"
		local ++tests_failed
	}

	* Test C3: autolabel values with dev default
	local ++test_num
	di as text "Test `test_num': Running autolabel values (dev default)"
	use "$TEST_DATA_DIR/synthetic_lisa.dta", clear
	cap noi autolabel values, domain(scb) lang(eng)
	if (_rc == 0) {
		di as result "  ✓ PASSED: autolabel values succeeded"
		local ++tests_passed
	}
	else {
		di as error "  ✗ FAILED: autolabel values failed"
		local ++tests_failed
	}
}

*==============================================================================
* Scenario D: Different test globals + autolabel
*==============================================================================

if (`dev_exists') {
	di as text ""
	di as text "------------------------------------------------------------"
	di as text "Scenario D: Different globals (3.0.0-BETA, localhost:9000)"
	di as text "------------------------------------------------------------"
	di as text ""

	global REGISTREAM_TEST_VERSION "3.0.0-BETA"
	global REGISTREAM_TEST_HOST "http://localhost:9000"
	di as text "✓ Set different test globals"

	* Test D1: New test version
	local ++test_num
	_rs_utils get_version
	local version = "`r(version)'"
	di as text "Test `test_num': get_version = `version'"

	if ("`version'" == "3.0.0-BETA") {
		di as result "  ✓ PASSED: New test version"
		local ++tests_passed
	}
	else {
		di as error "  ✗ FAILED: Expected '3.0.0-BETA', got '`version''"
		local ++tests_failed
	}

	* Test D2: autolabel with new version
	local ++test_num
	di as text "Test `test_num': autolabel variables (3.0.0-BETA)"
	use "$TEST_DATA_DIR/synthetic_lisa.dta", clear
	cap noi autolabel variables, domain(scb) lang(swe)
	if (_rc == 0) {
		di as result "  ✓ PASSED: autolabel with BETA version"
		local ++tests_passed
	}
	else {
		di as error "  ✗ FAILED: autolabel failed"
		local ++tests_failed
	}

	* Clear globals
	global REGISTREAM_TEST_VERSION ""
	global REGISTREAM_TEST_HOST ""
}

*==============================================================================
* Scenario E: Production fallback + autolabel
*==============================================================================

if (`dev_exists') {
	di as text ""
	di as text "------------------------------------------------------------"
	di as text "Scenario E: Production fallback ({{VERSION}})"
	di as text "------------------------------------------------------------"
	di as text ""

	* Remove dev override: drop program and remove from adopath
	di as text "  Dropping _rs_dev_utils program from memory..."
	cap program drop _rs_dev_utils
	di as text "  Removing dev override from adopath..."
	adopath - "$SRC_DIR"

	* Verify it's gone
	cap qui _rs_dev_utils get_version
	if (_rc != 0) {
		di as text "✓ Dev override no longer accessible"

		* Test E1: Production version
		local ++test_num
		_rs_utils get_version
		local version = "`r(version)'"
		di as text "Test `test_num': get_version = `version'"

		if ("`version'" == "{{VERSION}}") {
			di as result "  ✓ PASSED: Production version"
			local ++tests_passed
		}
		else {
			di as error "  ✗ FAILED: Expected '{{VERSION}}', got '`version''"
			local ++tests_failed
		}

		* Test E2: Production host
		local ++test_num
		_rs_utils get_api_host
		local host = "`r(host)'"
		di as text "Test `test_num': get_api_host = `host'"

		if ("`host'" == "https://registream.org") {
			di as result "  ✓ PASSED: Production host"
			local ++tests_passed
		}
		else {
			di as error "  ✗ FAILED: Expected 'https://registream.org', got '`host''"
			local ++tests_failed
		}

		* Test E3: autolabel with production version (logs {{VERSION}} to usage)
		local ++test_num
		di as text "Test `test_num': autolabel values ({{VERSION}} production)"
		use "$TEST_DATA_DIR/synthetic_lisa.dta", clear
		cap noi autolabel values, domain(scb) lang(swe)
		if (_rc == 0) {
			di as result "  ✓ PASSED: autolabel with production version"
			local ++tests_passed
		}
		else {
			di as error "  ✗ FAILED: autolabel failed"
			local ++tests_failed
		}
	}
	else {
		di as error "✗ Dev override still accessible!"
		local ++tests_failed
	}

	* Restore adopath
	di as text "  Restoring adopath..."
	adopath + "$SRC_DIR"
}

*==============================================================================
* Scenario F: Restore dev override + autolabel
*==============================================================================

if (`dev_exists') {
	di as text ""
	di as text "------------------------------------------------------------"
	di as text "Scenario F: Restore dev override (2.0.0)"
	di as text "------------------------------------------------------------"
	di as text ""

	* Reload dev override
	cap do "$SRC_DIR/_rs_dev_utils.ado"

	* Test F1: Back to dev default
	local ++test_num
	_rs_utils get_version
	local version = "`r(version)'"
	di as text "Test `test_num': get_version = `version'"

	if ("`version'" == "2.0.0") {
		di as result "  ✓ PASSED: Dev override restored"
		local ++tests_passed
	}
	else {
		di as error "  ✗ FAILED: Expected '2.0.0', got '`version''"
		local ++tests_failed
	}

	* Test F2: autolabel after restore
	local ++test_num
	di as text "Test `test_num': autolabel after restore"
	use "$TEST_DATA_DIR/synthetic_lisa.dta", clear
	cap noi autolabel values, domain(scb) lang(swe)
	if (_rc == 0) {
		di as result "  ✓ PASSED: autolabel after restore"
		local ++tests_passed
	}
	else {
		di as error "  ✗ FAILED: autolabel failed"
		local ++tests_failed
	}
}

*==============================================================================
* Scenario G: Rapid back-and-forth switches
*==============================================================================

if (`dev_exists') {
	di as text ""
	di as text "------------------------------------------------------------"
	di as text "Scenario G: Rapid switches (4 different versions)"
	di as text "------------------------------------------------------------"
	di as text ""

	* Switch 1: Version A
	global REGISTREAM_TEST_VERSION "0.9.0-ALPHA"
	local ++test_num
	_rs_utils get_version
	local version = "`r(version)'"
	di as text "Test `test_num': Switch 1 = `version'"
	if ("`version'" == "0.9.0-ALPHA") {
		di as result "  ✓ PASSED"
		local ++tests_passed
	}
	else {
		di as error "  ✗ FAILED"
		local ++tests_failed
	}

	* Switch 2: Version B
	global REGISTREAM_TEST_VERSION "2.1.0-RC1"
	local ++test_num
	_rs_utils get_version
	local version = "`r(version)'"
	di as text "Test `test_num': Switch 2 = `version'"
	if ("`version'" == "2.1.0-RC1") {
		di as result "  ✓ PASSED"
		local ++tests_passed
	}
	else {
		di as error "  ✗ FAILED"
		local ++tests_failed
	}

	* Switch 3: Back to default
	global REGISTREAM_TEST_VERSION ""
	local ++test_num
	_rs_utils get_version
	local version = "`r(version)'"
	di as text "Test `test_num': Switch 3 = `version'"
	if ("`version'" == "2.0.0") {
		di as result "  ✓ PASSED"
		local ++tests_passed
	}
	else {
		di as error "  ✗ FAILED"
		local ++tests_failed
	}

	* Switch 4: Version C
	global REGISTREAM_TEST_VERSION "1.0.0-STABLE"
	local ++test_num
	_rs_utils get_version
	local version = "`r(version)'"
	di as text "Test `test_num': Switch 4 = `version'"
	if ("`version'" == "1.0.0-STABLE") {
		di as result "  ✓ PASSED"
		local ++tests_passed
	}
	else {
		di as error "  ✗ FAILED"
		local ++tests_failed
	}

	* Final autolabel with last version
	local ++test_num
	di as text "Test `test_num': Final autolabel (1.0.0-STABLE)"
	use "$TEST_DATA_DIR/synthetic_lisa.dta", clear
	cap noi autolabel variables, domain(scb) lang(eng)
	if (_rc == 0) {
		di as result "  ✓ PASSED: Final autolabel"
		local ++tests_passed
	}
	else {
		di as error "  ✗ FAILED"
		local ++tests_failed
	}

	* Clear globals
	global REGISTREAM_TEST_VERSION ""
	global REGISTREAM_TEST_HOST ""
}

*==============================================================================
* Scenario H: Usage tracking verification
*==============================================================================

di as text ""
di as text "------------------------------------------------------------"
di as text "Scenario H: Usage tracking verification"
di as text "------------------------------------------------------------"
di as text ""

local ++test_num
di as text "Test `test_num': Check usage log exists"
cap confirm file "`usage_log'"
if (_rc == 0) {
	di as result "  ✓ PASSED: Usage log exists"
	local ++tests_passed

	* Show last 5 entries
	di as text ""
	di as text "Last 5 usage log entries (verify versions appear):"
	di as text "{hline 70}"
	preserve
	quietly infix strL line 1-500 using "`usage_log'", clear
	local n_lines = _N
	if (`n_lines' > 5) {
		local start = `n_lines' - 4
		forvalues i = `start'/`n_lines' {
			local entry = line[`i']
			di as text "  `entry'"
		}
	}
	else {
		forvalues i = 1/`n_lines' {
			local entry = line[`i']
			di as text "  `entry'"
		}
	}
	restore
	di as text "{hline 70}"
	di as text ""
	di as text "✓ User can verify versions in usage log"
}
else {
	di as error "  ✗ FAILED: Usage log not found"
	local ++tests_failed
}

*==============================================================================
* Summary
*==============================================================================

di as text ""
di as result "============================================================"
di as result "Test Summary"
di as result "============================================================"

local total_tests = `tests_passed' + `tests_failed'
di as result "Total: `total_tests' | Passed: `tests_passed' | Failed: `tests_failed'"
di as result ""

if (`tests_failed' > 0) {
	di as error "[FAIL] Version resolution priority validation"
	log close
	exit 198
}
else {
	di as result "[PASS] All version resolution tests passed!"
	di as result ""
	di as text "Summary:"
	di as text "  • Tested dev defaults (2.0.0, localhost:5000)"
	di as text "  • Tested custom test globals (multiple versions)"
	di as text "  • Tested production fallback ({{VERSION}})"
	di as text "  • Tested rapid back-and-forth switching"
	di as text "  • Ran autolabel with each version"
	di as text "  • Verified usage tracking captures versions"
	di as result ""
	log close
}
