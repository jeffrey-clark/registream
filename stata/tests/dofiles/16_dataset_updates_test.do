*! Test 16: Dataset Update Checks (Native GET + Numeric Timestamps)
* Tests:
*   - Fresh dataset download with numeric timestamps
*   - Dataset update check using native Stata copy (GET request)
*   - 24h cache for dataset updates
*   - Verify timestamps in datasets.csv are numeric

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

* Enable auto-approve for test mode
global REGISTREAM_AUTO_APPROVE "yes"

* Enable dev mode to point to localhost:5000
global REGISTREAM_API_HOST "http://localhost:5000"

* Clear all cached programs and load fresh
discard
adopath ++ "$SRC_DIR"
do "$SRC_DIR/_rs_utils.ado"
cap do "$SRC_DIR/_rs_dev_utils.ado"

* Setup test environment
tempfile test_marker
local test_dir = reverse(substr(reverse("`test_marker'"), strpos(reverse("`test_marker'"), "/")+1, .))
local test_dataset_dir "`test_dir'/dataset_test"
cap mkdir "`test_dataset_dir'"
cd "`test_dataset_dir'"

* Override registream directory for isolated testing
global registream_dir "`test_dataset_dir'/.registream"
cap mkdir "$registream_dir"
cap mkdir "$registream_dir/autolabel_keys"

di as result ""
di as result "============================================================"
di as result "Test 16: Dataset Update Checks (Native GET)"
di as result "============================================================"
di as result ""
di as result "API Host: $REGISTREAM_API_HOST"
di as result "Test directory: `test_dataset_dir'"
di as result ""

* ============================================================================
* Test 1: Fresh download with numeric timestamps
* ============================================================================
di as result "============================================================"
di as result "TEST 1: Fresh Download (Numeric Timestamps)"
di as result "============================================================"
di as result "Timestamp: `c(current_date)' `c(current_time)'"
di as result ""

* Configure for internet access
registream config, internet_access(true) telemetry_enabled(false) auto_update_check(false)

di as text "Downloading fresh dataset: scb variables eng"
di as result ""

* Download a small dataset
autolabel variables, domain(scb) lang(eng)

di as result ""
di as result "Checking datasets.csv for numeric timestamps..."
di as result ""

* Read and display datasets.csv
local datasets_csv "$registream_dir/autolabel_keys/datasets.csv"
cap confirm file "`datasets_csv'"
if (_rc == 0) {
	preserve
	qui import delimited using "`datasets_csv'", clear delimiter(";") varnames(1) stringcols(_all)

	di as text "Columns: dataset_key, domain, type, lang, version, schema, downloaded, source, file_size, last_checked"
	di as text "{hline 80}"

	* Display first row
	local key = dataset_key[1]
	local domain = domain[1]
	local type = type[1]
	local lang = lang[1]
	local version = version[1]
	local downloaded = downloaded[1]
	local last_checked = last_checked[1]

	di as text "Dataset: `key'"
	di as text "  domain/type/lang: `domain'/`type'/`lang'"
	di as text "  version: `version'"
	di as text "  downloaded: `downloaded'"
	di as text "  last_checked: `last_checked'"

	* Check if timestamps are numeric
	cap confirm number `downloaded'
	if (_rc == 0) {
		di as result "  ✓ 'downloaded' is NUMERIC (clean!)"
	}
	else {
		di as error "  ✗ 'downloaded' is STRING (old format)"
	}

	cap confirm number `last_checked'
	if (_rc == 0) {
		di as result "  ✓ 'last_checked' is NUMERIC (clean!)"
	}
	else {
		di as error "  ✗ 'last_checked' is STRING (old format)"
	}

	restore
}
else {
	di as error "datasets.csv not found!"
}

di as result ""
di as result "[TEST 1 COMPLETE]"
di as result ""

* Wait a bit
sleep 2000

* ============================================================================
* Test 2: Check for updates (First check - cache miss)
* ============================================================================
di as result "============================================================"
di as result "TEST 2: Dataset Update Check (First Run - Cache Miss)"
di as result "============================================================"
di as result "Timestamp: `c(current_date)' `c(current_time)'"
di as result ""

di as text "Running: registream update"
di as text "Expected: 1 GET request to /api/v1/datasets/check_updates?datasets=..."
di as result ""

registream update

di as result ""
di as result "[TEST 2 COMPLETE] Check server: should show ONE GET request"
di as result ""

* Wait a bit
sleep 2000

* ============================================================================
* Test 3: Check for updates (Second check - cache hit)
* ============================================================================
di as result "============================================================"
di as result "TEST 3: Dataset Update Check (Second Run - Cache Hit)"
di as result "============================================================"
di as result "Timestamp: `c(current_date)' `c(current_time)'"
di as result ""

di as text "Running: registream update"
di as text "Expected: ZERO requests (cache valid <24h)"
di as result ""

registream update

di as result ""
di as result "[TEST 3 COMPLETE] Check server: should show ZERO new requests"
di as result ""

* ============================================================================
* Test 4: Verify cache in config
* ============================================================================
di as result "============================================================"
di as result "TEST 4: Verify Cache in Config"
di as result "============================================================"
di as result ""

_rs_config get "$registream_dir" "last_dataset_check"
local last_check = "`r(value)'"
di as text "last_dataset_check: `last_check'"

cap confirm number `last_check'
if (_rc == 0) {
	di as result "  ✓ Numeric timestamp (clean!)"

	* Calculate how long ago
	local current_clock = clock("`c(current_date)' `c(current_time)'", "DMY hms")
	local diff_ms = `current_clock' - `last_check'
	local diff_sec = round(`diff_ms' / 1000, 1)
	di as text "  Time since last check: `diff_sec' seconds"
}
else {
	di as error "  ✗ Not numeric!"
}

di as result ""

_rs_config get "$registream_dir" "datasets_updates_available"
local updates = "`r(value)'"
di as text "datasets_updates_available: `updates'"

di as result ""
di as result "[TEST 4 COMPLETE]"
di as result ""

* ============================================================================
* Test Summary
* ============================================================================
di as result ""
di as result "============================================================"
di as result "Dataset Update Tests Complete!"
di as result "============================================================"
di as result ""
di as result "Summary of Expected Server Requests:"
di as result "  Test 1 (Fresh download):      N requests (dataset download)"
di as result "  Test 2 (Update check, miss):  1 GET request"
di as result "  Test 3 (Update check, hit):   0 requests (cache)"
di as result ""
di as result "Key Behavior:"
di as result "  - Timestamps: Numeric (ms since 1960)"
di as result "  - Update checks: GET with native Stata copy"
di as result "  - Cache: 24 hours using numeric comparison"
di as result "  - No shell curl commands!"
di as result ""
di as result "Check your Flask server logs to verify counts match!"
di as result "============================================================"
di as result ""

* Cleanup
quietly {
	cap cd "$PROJECT_ROOT"
}
