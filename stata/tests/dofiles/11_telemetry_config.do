*! Test 11: Telemetry and Config System
* Tests:
*   - 3-choice setup system (Offline, Standard, Full)
*   - Empty config file reinitialization
*   - Local logging vs online telemetry separation
*   - Config switching between modes
*   - CSV format validation (7 fields)
*   - Online telemetry sending to backend
*   - Different mode behaviors
*   - registream stats command
*   - (12 tests total)

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

* Save original globals
local orig_test_dir "$TEST_DIR"
local orig_registream_dir "$registream_dir"

* Setup test environment
tempfile test_marker
local test_dir = reverse(substr(reverse("`test_marker'"), strpos(reverse("`test_marker'"), "/")+1, .))
local test_telemetry_dir "`test_dir'/usage_test"
cap mkdir "`test_telemetry_dir'"
cd "`test_telemetry_dir'"

* Override registream directory for isolated testing
global registream_dir "`test_telemetry_dir'/.registream"
cap mkdir "$registream_dir"

di as result ""
di as result "============================================================"
di as result "Test 12: Usage Tracking and Config System"
di as result "============================================================"
di as result ""

* ============================================================================
* Test 1: Config initialization creates Full Mode (AUTO_APPROVE default)
* ============================================================================
di as text "Test 1: AUTO_APPROVE defaults to Full Mode..."

cap erase "$registream_dir/config.yaml"
cap erase "$registream_dir/usage_stata.csv"

* Trigger config init
registream version

* Check config exists
cap confirm file "$registream_dir/config.yaml"
if (_rc != 0) {
	di as error "[FAIL] Config file not created"
	exit 1
}

* Check Full Mode settings
_rs_config get "$registream_dir" "usage_logging"
assert "`r(value)'" == "true"

_rs_config get "$registream_dir" "telemetry_enabled"
assert "`r(value)'" == "true"

_rs_config get "$registream_dir" "internet_access"
assert "`r(value)'" == "true"

_rs_config get "$registream_dir" "auto_update_check"
assert "`r(value)'" == "true"

di as result "[PASS] Config initialized with Full Mode defaults"

* ============================================================================
* Test 2: Empty config file triggers reinitialization
* ============================================================================
di as text "Test 2: Empty config file triggers reinitialization..."

* Create empty config file
cap file close emptyfile
file open emptyfile using "$registream_dir/config.yaml", write replace
file close emptyfile

* Run command - should detect empty config and reinitialize
registream version

* Verify config was reinitialized with proper settings
_rs_config get "$registream_dir" "usage_logging"
assert "`r(value)'" == "true"

di as result "[PASS] Empty config file reinitialized correctly"

* ============================================================================
* Test 3: CSV format validation (7 fields)
* ============================================================================
di as text "Test 3: CSV has 7 fields with os and platform_version..."

* Check CSV exists
cap confirm file "$registream_dir/usage_stata.csv"
if (_rc != 0) {
	di as error "[FAIL] Usage CSV not created"
	exit 1
}

* Read header line
tempname fh
file open `fh' using "$registream_dir/usage_stata.csv", read
file read `fh' header_line
file close `fh'

* Verify header has 7 fields
local expected_header "timestamp;user_id;platform;version;command_string;os;platform_version"
if ("`header_line'" != "`expected_header'") {
	di as error "[FAIL] CSV header incorrect"
	di as error "Expected: `expected_header'"
	di as error "Got:      `header_line'"
	exit 1
}

di as result "[PASS] CSV format has 7 fields"

* ============================================================================
* Test 4: Config switching between modes
* ============================================================================
di as text "Test 4: Switching between Offline/Standard/Full modes..."

* Switch to Offline Mode
registream config, usage_logging(true) internet_access(false) telemetry_enabled(false) auto_update_check(false)

_rs_config get "$registream_dir" "usage_logging"
assert "`r(value)'" == "true"
_rs_config get "$registream_dir" "internet_access"
assert "`r(value)'" == "false"
_rs_config get "$registream_dir" "telemetry_enabled"
assert "`r(value)'" == "false"
_rs_config get "$registream_dir" "auto_update_check"
assert "`r(value)'" == "false"

di as result "[PASS] Switched to Offline Mode"

* Switch to Standard Mode
registream config, usage_logging(true) internet_access(true) telemetry_enabled(false) auto_update_check(true)

_rs_config get "$registream_dir" "usage_logging"
assert "`r(value)'" == "true"
_rs_config get "$registream_dir" "internet_access"
assert "`r(value)'" == "true"
_rs_config get "$registream_dir" "telemetry_enabled"
assert "`r(value)'" == "false"
_rs_config get "$registream_dir" "auto_update_check"
assert "`r(value)'" == "true"

di as result "[PASS] Switched to Standard Mode"

* Switch to Full Mode
registream config, usage_logging(true) internet_access(true) telemetry_enabled(true) auto_update_check(true)

_rs_config get "$registream_dir" "usage_logging"
assert "`r(value)'" == "true"
_rs_config get "$registream_dir" "internet_access"
assert "`r(value)'" == "true"
_rs_config get "$registream_dir" "telemetry_enabled"
assert "`r(value)'" == "true"
_rs_config get "$registream_dir" "auto_update_check"
assert "`r(value)'" == "true"

di as result "[PASS] Switched to Full Mode"

* ============================================================================
* Test 5: Local logging works independently
* ============================================================================
di as text "Test 5: Local logging works when online telemetry disabled..."

* Disable online telemetry but keep usage logging
registream config, usage_logging(true) telemetry_enabled(false)

* Count existing entries
preserve
qui import delimited using "$registream_dir/usage_stata.csv", clear delimiter(";") varnames(1)
local initial_count = _N
restore

* Run a command
registream version

* Count entries after command
preserve
qui import delimited using "$registream_dir/usage_stata.csv", clear delimiter(";") varnames(1)
local final_count = _N
restore

* Should have one more entry
assert `final_count' == `initial_count' + 1

di as result "[PASS] Local logging works independently of online telemetry"

* ============================================================================
* Test 6: Disabling usage_logging stops local logging
* ============================================================================
di as text "Test 6: Disabling usage_logging stops local logging..."

* Disable usage logging
registream config, usage_logging(false)

* Count entries
preserve
qui import delimited using "$registream_dir/usage_stata.csv", clear delimiter(";") varnames(1)
local before_count = _N
restore

* Run a command
registream version

* Count entries after - should be same
preserve
qui import delimited using "$registream_dir/usage_stata.csv", clear delimiter(";") varnames(1)
local after_count = _N
restore

assert `after_count' == `before_count'

di as result "[PASS] Usage logging can be disabled"

* ============================================================================
* Test 7: CSV data format validation
* ============================================================================
di as text "Test 7: CSV data contains os and platform_version..."

* Re-enable logging and run command
registream config, usage_logging(true)
registream version

* Read last line of CSV
preserve
qui import delimited using "$registream_dir/usage_stata.csv", clear delimiter(";") varnames(1) stringcols(_all)

* Check last entry has os and platform_version
local last_row = _N
local os_val = os[`last_row']
local platform_version_val = platform_version[`last_row']

* OS should be one of: MacOSX, Windows, Unix
local valid_os = 0
if ("`os_val'" == "MacOSX" | "`os_val'" == "Windows" | "`os_val'" == "Unix") {
	local valid_os = 1
}

if (`valid_os' == 0) {
	di as error "[FAIL] Invalid OS value: `os_val'"
	exit 1
}

* Platform version should be numeric (Stata version)
if ("`platform_version_val'" == "") {
	di as error "[FAIL] Platform version is empty"
	exit 1
}

restore

di as result "[PASS] CSV contains valid os and platform_version"

* ============================================================================
* Test 8: registream info shows all settings
* ============================================================================
di as text "Test 8: registream info shows all config settings..."

* Capture output of registream info
cap noi registream info

* Just verify it doesn't error - actual output checked manually
if (_rc != 0) {
	di as error "[FAIL] registream info failed"
	exit 1
}

di as result "[PASS] registream info displays correctly"

* ============================================================================
* Test 9: Online telemetry sends to backend (Full Mode)
* ============================================================================
di as text "Test 9: Online telemetry actually sends to backend..."

* Set Full Mode (online telemetry enabled + internet enabled)
registream config, usage_logging(true) telemetry_enabled(true) internet_access(true)

* Verify settings
_rs_config get "$registream_dir" "telemetry_enabled"
assert "`r(value)'" == "true"
_rs_config get "$registream_dir" "internet_access"
assert "`r(value)'" == "true"

* Send usage data by running a command
* Note: We can't directly verify backend reception in Stata, but we test
* that the curl call succeeds (doesn't error)
registream version

* The online telemetry transmission is silent, but we can test it manually with curl
* to verify the payload format is correct
local test_payload `"{"timestamp": "20 Oct 2025T19:30:00Z", "user_id": "2440820207", "platform": "stata", "version": "2.0.0", "command_string": "test", "os": "Unix", "platform_version": "16"}"'

* Write test payload to temp file
tempfile test_json
cap file close testjson
file open testjson using "`test_json'", write replace
file write testjson `"`test_payload'"'
file close testjson

* Test that backend accepts our payload format
if ("$REGISTREAM_API_HOST" != "") {
	local endpoint "$REGISTREAM_API_HOST/api/v1/telemetry"
}
else {
	local endpoint "https://registream.org/api/v1/telemetry"
}

cap shell curl -s -f --max-time 5 -X POST -H "Content-Type: application/json" -d @"`test_json'" "`endpoint'" > /dev/null 2>&1
local curl_rc = _rc

if (`curl_rc' == 0) {
	di as result "[PASS] Online telemetry endpoint accepts payload"
}
else {
	di as error "[FAIL] Backend telemetry endpoint not responding (rc=`curl_rc')"
	di as text "Note: This test requires API server running at `endpoint'"
	exit 1
}

* ============================================================================
* Test 10: Offline Mode prevents online telemetry
* ============================================================================
di as text "Test 10: Offline Mode does NOT send online telemetry..."

* Switch to Offline Mode
registream config, usage_logging(true) telemetry_enabled(false) internet_access(false)

_rs_config get "$registream_dir" "telemetry_enabled"
assert "`r(value)'" == "false"

* Run command - should log locally but NOT send online
registream version

* Verify local logging still works
preserve
qui import delimited using "$registream_dir/usage_stata.csv", clear delimiter(";") varnames(1)
local csv_count = _N
restore

if (`csv_count' > 0) {
	di as result "[PASS] Offline Mode: local logging works, online disabled"
}
else {
	di as error "[FAIL] Local logging not working in Offline Mode"
	exit 1
}

* ============================================================================
* Test 11: Standard Mode (no online telemetry, but internet enabled)
* ============================================================================
di as text "Test 11: Standard Mode has internet but no online telemetry..."

* Switch to Standard Mode
registream config, usage_logging(true) telemetry_enabled(false) internet_access(true)

_rs_config get "$registream_dir" "telemetry_enabled"
assert "`r(value)'" == "false"
_rs_config get "$registream_dir" "internet_access"
assert "`r(value)'" == "true"

di as result "[PASS] Standard Mode: internet enabled, online telemetry disabled"

* ============================================================================
* Test 12: registream stats command
* ============================================================================
di as text "Test 12: registream stats displays usage statistics..."

* Ensure usage logging is enabled
registream config, usage_logging(true)

* Run stats command
cap noi registream stats

if (_rc != 0) {
	di as error "[FAIL] registream stats command failed"
	exit 1
}

di as result "[PASS] registream stats command works"

* ============================================================================
* Test Summary
* ============================================================================
di as result ""
di as result "============================================================"
di as result "All Usage Tracking and Config Tests Passed (12 tests)!"
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
