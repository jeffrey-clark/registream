*! Test 14: Network Request Timing and Counting
* Tests:
*   - Offline Mode: ZERO requests expected
*   - Standard Mode: Update check only (with proper 24h timestamp cache)
*   - Full Mode: Telemetry on EVERY command + update check (24h cache)
*   - Log timestamps for server-side verification
*   - (5 sub-tests total: 1, 2a, 2b, 3a, 3b)

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

* Enable dev mode to point to localhost:5000
global REGISTREAM_API_HOST "http://localhost:5000"

* Clear all cached programs and load fresh
discard
adopath ++ "$SRC_DIR"
do "$SRC_DIR/_rs_utils.ado"
cap do "$SRC_DIR/_rs_dev_utils.ado"

* Save original globals
local orig_test_dir "$TEST_DIR"
local orig_registream_dir "$registream_dir"

* Setup test environment
tempfile test_marker
local test_dir = reverse(substr(reverse("`test_marker'"), strpos(reverse("`test_marker'"), "/")+1, .))
local test_network_dir "`test_dir'/network_test"
cap mkdir "`test_network_dir'"
cd "`test_network_dir'"

* Override registream directory for isolated testing
global registream_dir "`test_network_dir'/.registream"
cap mkdir "$registream_dir"

di as result ""
di as result "============================================================"
di as result "Test 14: Network Request Timing and Counting"
di as result "============================================================"
di as result ""
di as result "API Host: $REGISTREAM_API_HOST"
di as result "Check server logs to count actual requests received"
di as result ""

* ============================================================================
* Test 1: OFFLINE MODE - ZERO requests expected
* ============================================================================
di as result "============================================================"
di as result "TEST 1: OFFLINE MODE"
di as result "============================================================"
di as result "Timestamp: `c(current_date)' `c(current_time)'"
di as result ""

* Configure Offline Mode
registream config, usage_logging(true) internet_access(false) telemetry_enabled(false) auto_update_check(false)

* Verify settings
_rs_config get "$registream_dir" "internet_access"
assert "`r(value)'" == "false"
_rs_config get "$registream_dir" "telemetry_enabled"
assert "`r(value)'" == "false"

di as text "Running: registream version"
di as text "Expected requests to localhost:5000: ZERO"
di as result ""

* Run the command
registream version

di as result ""
di as result "[TEST 1 COMPLETE] Check server: should show ZERO requests"
di as result ""

* ============================================================================
* Test 2: STANDARD MODE - Update check only (24h cache)
* ============================================================================
di as result "============================================================"
di as result "TEST 2: STANDARD MODE (First Run - Cache Miss)"
di as result "============================================================"
di as result "Timestamp: `c(current_date)' `c(current_time)'"
di as result ""

* Configure Standard Mode
registream config, usage_logging(true) internet_access(true) telemetry_enabled(false) auto_update_check(true)

* Clear cache to force update check
cap _rs_config set "$registream_dir" "last_update_check" ""

* Verify settings
_rs_config get "$registream_dir" "internet_access"
assert "`r(value)'" == "true"
_rs_config get "$registream_dir" "telemetry_enabled"
assert "`r(value)'" == "false"
_rs_config get "$registream_dir" "auto_update_check"
assert "`r(value)'" == "true"

di as text "Running: registream version"
di as text "Expected requests to localhost:5000: ONE (heartbeat GET)"
di as result ""

* Run the command
registream version

di as result ""
di as result "[TEST 2a COMPLETE] Check server: should show ONE request to /api/v1/stata/heartbeat"
di as result ""

* Pause 3 seconds
di as text "Waiting 3 seconds before second run..."
sleep 3000

di as result "============================================================"
di as result "TEST 2b: STANDARD MODE (Second Run - Cache Hit)"
di as result "============================================================"
di as result "Timestamp: `c(current_date)' `c(current_time)'"
di as result ""

di as text "Running: registream version"
di as text "Expected requests to localhost:5000: ZERO (cache within 24h)"
di as result ""

* Run the command again (should hit cache)
registream version

di as result ""
di as result "[TEST 2b COMPLETE] Check server: should show ZERO new requests"
di as result ""

* ============================================================================
* Test 3: FULL MODE - Telemetry sent on EVERY command (not cached)
* ============================================================================
di as result "============================================================"
di as result "TEST 3a: FULL MODE (First Run - Telemetry + Update Check)"
di as result "============================================================"
di as result "Timestamp: `c(current_date)' `c(current_time)'"
di as result ""

* Configure Full Mode
registream config, usage_logging(true) internet_access(true) telemetry_enabled(true) auto_update_check(true)

* Clear cache to force update check
cap _rs_config set "$registream_dir" "last_update_check" ""

* Verify settings
_rs_config get "$registream_dir" "internet_access"
assert "`r(value)'" == "true"
_rs_config get "$registream_dir" "telemetry_enabled"
assert "`r(value)'" == "true"
_rs_config get "$registream_dir" "auto_update_check"
assert "`r(value)'" == "true"

di as text "Running: registream version"
di as text "Expected requests to localhost:5000: ONE (heartbeat GET with telemetry + version)"
di as result ""

* Run the command
registream version

di as result ""
di as result "[TEST 3a COMPLETE] Check server: should show ONE request with both telemetry and version params"
di as result ""

* Pause 3 seconds
di as text "Waiting 3 seconds before second run..."
sleep 3000

di as result "============================================================"
di as result "TEST 3b: FULL MODE (Second Run - Telemetry Only, Update Cached)"
di as result "============================================================"
di as result "Timestamp: `c(current_date)' `c(current_time)'"
di as result ""

di as text "Running: registream version"
di as text "Expected requests to localhost:5000: ONE (heartbeat GET with telemetry, NO version param)"
di as result ""

* Run the command again (telemetry sent, update check cached)
registream version

di as result ""
di as result "[TEST 3b COMPLETE] Check server: should show ONE request with telemetry but NO version param"
di as result ""

* ============================================================================
* Test Summary
* ============================================================================
di as result ""
di as result "============================================================"
di as result "Network Request Timing Tests Complete!"
di as result "============================================================"
di as result ""
di as result "Summary of Expected Server Requests:"
di as result "  Test 1  (Offline):                    0 requests"
di as result "  Test 2a (Standard, miss):             1 request  (version only)"
di as result "  Test 2b (Standard, hit):              0 requests (24h cache)"
di as result "  Test 3a (Full, telemetry+update):     1 request  (telemetry + version)"
di as result "  Test 3b (Full, telemetry only):       1 request  (telemetry only, update cached)"
di as result ""
di as result "Total expected: 3 requests to /api/v1/stata/heartbeat"
di as result ""
di as result "Key Behavior:"
di as result "  - Telemetry: Sent on EVERY command (not cached)"
di as result "  - Updates: Checked once per 24 hours (proper timestamp diff, not just date)"
di as result ""
di as result "Check your Flask server logs to verify counts match!"
di as result "============================================================"
di as result ""

* Cleanup and restore working directory
quietly {
	* Go back to project root
	cap cd "$PROJECT_ROOT"
	if (_rc != 0) {
		* If PROJECT_ROOT not set, find it
		forval i = 0/5 {
			cap confirm file "`i'/.project_root"
			if (_rc == 0) {
				cd "`i'"
				continue, break
			}
			local next = "`i'/.."
		}
	}
}

* Restore original globals
global TEST_DIR "`orig_test_dir'"
global registream_dir "`orig_registream_dir'"
