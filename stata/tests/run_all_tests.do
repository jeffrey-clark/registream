/*==============================================================================
  RegiStream - Master Test Suite

  Purpose: Run all verification tests and ensure clean state at end
  Author: Jeffrey Clark
  Date: October 2025

  Test Files:
  1. dofiles/01_config_initialization.do - Config auto-creation
  2. dofiles/02_basic_workflow.do - Basic autolabel functionality
  3. dofiles/03_verification_scenarios.do - File/metadata verification
  4. dofiles/04_caching.do - 24-hour cache mechanism
  5. dofiles/05_offline_mode.do - Online vs offline behavior
  6. dofiles/06_comprehensive_update_system.do - Version & update system
  7. dofiles/07_update_default_behavior.do - Default update behavior
  8. dofiles/08_version_and_cite_commands.do - Version/cite commands & aliases
  9. dofiles/09_auto_update_check.do - Auto-update check feature
  10. dofiles/10_update_notification.do - Update notification when newer version available
  11. dofiles/11_telemetry_config.do - Telemetry and config system
  12. dofiles/12_bug_fixes_validation.do - Bug fixes validation tests
  13. dofiles/13_version_resolution_priority.do - Version resolution (2-level: dev/production, 22 sub-tests)
  14. dofiles/14_network_requests_timing.do - Network request timing and counting (5 sub-tests)
  15. dofiles/15_timestamp_cache_test.do - Timestamp cache logic (numeric clock values)
  16. dofiles/16_dataset_updates_test.do - Dataset update checks (native GET + numeric timestamps)
  17. dofiles/99_cleanup.do - Clean state restoration

  Usage:
    From repo root: do stata/tests/run_all_tests.do

  Requirements:
    - API server running at localhost:5000
    - .project_root file in repo root
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

global PROJECT_ROOT "`project_root'"
global TEST_DIR "$PROJECT_ROOT/stata/tests"
global TEST_LOGS_DIR "$TEST_DIR/logs"

* Create logs directory
cap mkdir "$TEST_LOGS_DIR"

*==============================================================================
* Display test suite info
*==============================================================================

di as result ""
di as result "============================================================"
di as result "RegiStream Master Test Suite"
di as result "============================================================"
di as result ""
di as text "Project root: $PROJECT_ROOT"
di as text "Test directory: $TEST_DIR"
di as text ""

*==============================================================================
* Generate synthetic data if needed
*==============================================================================

global TEST_DATA_DIR "$TEST_DIR/data"

* Check if synthetic data exists
cap confirm file "$TEST_DATA_DIR/synthetic_lisa.dta"
if (_rc != 0) {
	di as text ""
	di as text "============================================================"
	di as text "Synthetic data not found - generating..."
	di as text "============================================================"
	di as text ""

	* Change to test directory and run generator
	quietly cd "$TEST_DIR"
	do "$TEST_DIR/utils/generate_synthetic_data.do"

	di as text ""
	di as result "[SUCCESS] Synthetic data generated"
	di as text ""
}
else {
	di as text "[INFO] Synthetic data already exists"
	di as text ""
}

*==============================================================================
* Track test results
*==============================================================================

local tests_total = 0
local tests_passed = 0
local tests_failed = 0

*==============================================================================
* Run each test sequentially
*==============================================================================

* Test 1: Config Initialization
di as result "============================================================"
di as result "Test 1/17: Config Auto-Initialization"
di as result "============================================================"
local ++tests_total
cap noi do "$TEST_DIR/dofiles/01_config_initialization.do"
if (_rc == 0) {
	local ++tests_passed
	di as result "[PASS] Test 1"
}
else {
	local ++tests_failed
	di as error "[FAIL] Test 1 (rc=`=_rc')"
}

* Test 2: Basic Workflow
di as result "============================================================"
di as result "Test 2/17: Basic Autolabel Workflow"
di as result "============================================================"
local ++tests_total
cap noi do "$TEST_DIR/dofiles/02_basic_workflow.do"
if (_rc == 0) {
	local ++tests_passed
	di as result "[PASS] Test 2"
}
else {
	local ++tests_failed
	di as error "[FAIL] Test 2 (rc=`=_rc')"
}

* Test 3: Verification Scenarios
di as result "============================================================"
di as result "Test 3/17: File/Metadata Verification"
di as result "============================================================"
local ++tests_total
cap noi do "$TEST_DIR/dofiles/03_verification_scenarios.do"
if (_rc == 0) {
	local ++tests_passed
	di as result "[PASS] Test 3"
}
else {
	local ++tests_failed
	di as error "[FAIL] Test 3 (rc=`=_rc')"
}

* Test 4: Caching
di as result "============================================================"
di as result "Test 4/17: Last Checked Caching (24-hour)"
di as result "============================================================"
local ++tests_total
cap noi do "$TEST_DIR/dofiles/04_caching.do"
if (_rc == 0) {
	local ++tests_passed
	di as result "[PASS] Test 4"
}
else {
	local ++tests_failed
	di as error "[FAIL] Test 4 (rc=`=_rc')"
}

* Test 5: Offline Mode
di as result "============================================================"
di as result "Test 5/17: Online vs Offline Validation"
di as result "============================================================"
local ++tests_total
cap noi do "$TEST_DIR/dofiles/05_offline_mode.do"
if (_rc == 0) {
	local ++tests_passed
	di as result "[PASS] Test 5"
}
else {
	local ++tests_failed
	di as error "[FAIL] Test 5 (rc=`=_rc')"
}

* Test 6: Comprehensive Update System
di as result "============================================================"
di as result "Test 6/17: Version & Update System"
di as result "============================================================"
local ++tests_total
cap noi do "$TEST_DIR/dofiles/06_comprehensive_update_system.do"
if (_rc == 0) {
	local ++tests_passed
	di as result "[PASS] Test 6"
}
else {
	local ++tests_failed
	di as error "[FAIL] Test 6 (rc=`=_rc')"
}

* Test 7: Update Default Behavior
di as result "============================================================"
di as result "Test 7/17: Update Default Behavior"
di as result "============================================================"
local ++tests_total
cap noi do "$TEST_DIR/dofiles/07_update_default_behavior.do"
if (_rc == 0) {
	local ++tests_passed
	di as result "[PASS] Test 7"
}
else {
	local ++tests_failed
	di as error "[FAIL] Test 7 (rc=`=_rc')"
}

* Test 8: Version and Citation Commands
di as result "============================================================"
di as result "Test 8/17: Version & Citation Commands"
di as result "============================================================"
local ++tests_total
cap noi do "$TEST_DIR/dofiles/08_version_and_cite_commands.do"
if (_rc == 0) {
	local ++tests_passed
	di as result "[PASS] Test 8"
}
else {
	local ++tests_failed
	di as error "[FAIL] Test 8 (rc=`=_rc')"
}

* Test 9: Auto Update Check
di as result "============================================================"
di as result "Test 9/17: Auto Update Check"
di as result "============================================================"
local ++tests_total
cap noi do "$TEST_DIR/dofiles/09_auto_update_check.do"
if (_rc == 0) {
	local ++tests_passed
	di as result "[PASS] Test 9"
}
else {
	local ++tests_failed
	di as error "[FAIL] Test 9 (rc=`=_rc')"
}

* Test 10: Update Notification
di as result "============================================================"
di as result "Test 10/17: Update Notification (Update Available)"
di as result "============================================================"
local ++tests_total
cap noi do "$TEST_DIR/dofiles/10_update_notification.do"
if (_rc == 0) {
	local ++tests_passed
	di as result "[PASS] Test 10"
}
else {
	local ++tests_failed
	di as error "[FAIL] Test 10 (rc=`=_rc')"
}

* Test 11: Telemetry and Config System
di as result "============================================================"
di as result "Test 11/17: Telemetry and Config System"
di as result "============================================================"
local ++tests_total
cap noi do "$TEST_DIR/dofiles/11_telemetry_config.do"
if (_rc == 0) {
	local ++tests_passed
	di as result "[PASS] Test 11"
}
else {
	local ++tests_failed
	di as error "[FAIL] Test 11 (rc=`=_rc')"
}

* Test 12: Bug Fixes Validation
di as result "============================================================"
di as result "Test 12/17: Bug Fixes Validation"
di as result "============================================================"
local ++tests_total
cap noi do "$TEST_DIR/dofiles/12_bug_fixes_validation.do"
if (_rc == 0) {
	local ++tests_passed
	di as result "[PASS] Test 12"
}
else {
	local ++tests_failed
	di as error "[FAIL] Test 12 (rc=`=_rc')"
}

* Test 13: Version Resolution Priority System
di as result "============================================================"
di as result "Test 13/17: Version Resolution Priority System"
di as result "============================================================"
local ++tests_total
cap noi do "$TEST_DIR/dofiles/13_version_resolution_priority.do"
if (_rc == 0) {
	local ++tests_passed
	di as result "[PASS] Test 13"
}
else {
	local ++tests_failed
	di as error "[FAIL] Test 13 (rc=`=_rc')"
}

* Test 14: Network Requests Timing
di as result "============================================================"
di as result "Test 14/17: Network Request Timing and Counting"
di as result "============================================================"
local ++tests_total
cap noi do "$TEST_DIR/dofiles/14_network_requests_timing.do"
if (_rc == 0) {
	local ++tests_passed
	di as result "[PASS] Test 14"
}
else {
	local ++tests_failed
	di as error "[FAIL] Test 14 (rc=`=_rc')"
}

* Test 15: Timestamp Cache Logic
di as result "============================================================"
di as result "Test 15/17: Timestamp Cache Logic (Numeric Clock)"
di as result "============================================================"
local ++tests_total
cap noi do "$TEST_DIR/dofiles/15_timestamp_cache_test.do"
if (_rc == 0) {
	local ++tests_passed
	di as result "[PASS] Test 15"
}
else {
	local ++tests_failed
	di as error "[FAIL] Test 15 (rc=`=_rc')"
}

* Test 16: Dataset Update Checks
di as result "============================================================"
di as result "Test 16/17: Dataset Update Checks (Native GET)"
di as result "============================================================"
local ++tests_total
cap noi do "$TEST_DIR/dofiles/16_dataset_updates_test.do"
if (_rc == 0) {
	local ++tests_passed
	di as result "[PASS] Test 16"
}
else {
	local ++tests_failed
	di as error "[FAIL] Test 16 (rc=`=_rc')"
}

* Test 17: Cleanup
di as result "============================================================"
di as result "Test 17/17: Clean State Restoration"
di as result "============================================================"
local ++tests_total
cap noi do "$TEST_DIR/dofiles/99_cleanup.do"
if (_rc == 0) {
	local ++tests_passed
	di as result "[PASS] Test 17"
}
else {
	local ++tests_failed
	di as error "[FAIL] Test 17 (rc=`=_rc')"
}

*==============================================================================
* Final Summary
*==============================================================================

di as result ""
di as result "============================================================"
di as result "Test Suite Summary"
di as result "============================================================"
di as result ""

local pass_rate = round((`tests_passed' / `tests_total') * 100)

di as result "Total Tests:  `tests_total'"
di as result "Passed:       {result:`tests_passed'}"
if (`tests_failed' > 0) {
	di as error "Failed:       {error:`tests_failed'}"
}
else {
	di as result "Failed:       `tests_failed'"
}
di as result "Pass Rate:    `pass_rate'%"
di as result ""

if (`tests_failed' == 0) {
	di as result "============================================================"
	di as result "[SUCCESS] ALL TESTS PASSED!"
	di as result "============================================================"
	di as result ""
}
else {
	di as error "============================================================"
	di as error "[FAILURE] SOME TESTS FAILED"
	di as error "============================================================"
	di as error ""
	di as text "Check individual test logs in:"
	di as text "  $TEST_LOGS_DIR"
	di as text ""
}

* Exit with error if any tests failed
if (`tests_failed' > 0) {
	exit 1
}
