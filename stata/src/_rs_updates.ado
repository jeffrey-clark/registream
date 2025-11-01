* =============================================================================
* RegiStream Update Checker
* Check for package updates and dataset updates
* Usage: _rs_updates subcommand [args]
* =============================================================================

cap program drop _rs_updates
cap program drop _upd_check_package
cap program drop _upd_check_background
cap program drop _upd_show_notification
cap program drop _upd_send_heartbeat
cap program drop _upd_check_datasets
cap program drop _upd_update_datasets_interactive
cap program drop _upd_scan_datasets
cap program drop _upd_rebuild_yaml

program define _rs_updates, rclass
	version 16.0

	gettoken subcmd 0 : 0, parse(" ,")

	if ("`subcmd'" == "check_package") {
		_upd_check_package `0'
		return add
	}
	else if ("`subcmd'" == "check_background") {
		_upd_check_background `0'
		return add
	}
	else if ("`subcmd'" == "show_notification") {
		_upd_show_notification `0'
		return add
	}
	else if ("`subcmd'" == "send_heartbeat") {
		_upd_send_heartbeat `0'
		return add
	}
	else if ("`subcmd'" == "check_datasets") {
		_upd_check_datasets `0'
		return add
	}
	else if ("`subcmd'" == "update_datasets_interactive") {
		_upd_update_datasets_interactive `0'
		return add
	}
	else if ("`subcmd'" == "scan_datasets") {
		_upd_scan_datasets `0'
		return add
	}
	else if ("`subcmd'" == "rebuild_yaml") {
		_upd_rebuild_yaml `0'
		return add
	}
	else {
		di as error "Invalid _rs_updates subcommand: `subcmd'"
		exit 198
	}
end

* -----------------------------------------------------------------------------
* check_package: Check if there's a newer version of RegiStream available
* Args: registream_dir, current_version (passed from entry point)
* Returns: r(update_available) = 1 if update available, 0 otherwise
*          r(current_version) = current version (e.g., "2.0.0")
*          r(latest_version) = latest version from API
* -----------------------------------------------------------------------------
program define _upd_check_package, rclass
	args registream_dir current_version

	* If current_version not provided, use global override (for testing/dev)
	* In production, version should always be passed as parameter from entry point
	if ("`current_version'" == "") {
		if ("$REGISTREAM_VERSION" != "") {
			local current_version "$REGISTREAM_VERSION"
		}
		else {
			di as error "_rs_updates: version not provided and \$REGISTREAM_VERSION not set"
			exit 198
		}
	}

	* Check internet access setting
	_rs_config get "`registream_dir'" "internet_access"
	if (r(found) == 1 & "`r(value)'" == "false") {
		* Internet access disabled
		return scalar update_available = 0
		return local current_version "`current_version'"
		return local latest_version ""
		return local reason "internet_disabled"
		exit 0
	}

	* Get API host
	_rs_utils get_api_host
	local api_host "`r(host)'"

	* Construct version check endpoint
	local version_url "`api_host'/api/v1/stata/version"

	* Fetch latest version from API using native Stata copy (no shell commands)
	tempfile version_json
	cap copy "`version_url'" "`version_json'", replace
	if (_rc != 0) {
		* Network error or timeout
		return scalar update_available = 0
		return local current_version "`current_version'"
		return local latest_version ""
		return local reason "network_error"
		exit 0
	}

	* Parse JSON response to get latest version (preserve/restore to avoid corrupting user's dataset)
	local latest_version ""
	preserve
	cap qui infix strL json_line 1-5000 using "`version_json'", clear
	if (_rc == 0 & _N > 0) {
		* Extract version number using simple pattern that matches semantic version format
		* This avoids issues with quote escaping in Stata regex
		* Pattern: X.Y.Z where X, Y, Z are numbers (e.g., "1.0.1", "1.2.10")
		qui gen matched = regexm(json_line, "([0-9]+\.[0-9]+\.[0-9]+)")
		if (matched[1] == 1) {
			* IMPORTANT: Extract to local BEFORE restore, as regexs() is dataset-dependent
			local latest_version = regexs(1)
		}
	}
	restore

	* Check if version was successfully extracted (after restore)
	if ("`latest_version'" == "") {
		return scalar update_available = 0
		return local current_version "`current_version'"
		return local latest_version ""
		return local reason "parse_error"
		exit 0
	}

	* Compare versions semantically (X.Y.Z format)
	* Update is available only if latest > current, not just different
	local update_available = 0

	if ("`latest_version'" != "" & "`latest_version'" != "`current_version'") {
		* Parse current version (X.Y.Z)
		if (regexm("`current_version'", "^([0-9]+)\.([0-9]+)\.([0-9]+)")) {
			local cur_major = regexs(1)
			local cur_minor = regexs(2)
			local cur_patch = regexs(3)
		}
		else {
			* Invalid current version format, assume update needed
			local update_available = 1
		}

		* Parse latest version (X.Y.Z)
		if (regexm("`latest_version'", "^([0-9]+)\.([0-9]+)\.([0-9]+)")) {
			local lat_major = regexs(1)
			local lat_minor = regexs(2)
			local lat_patch = regexs(3)
		}
		else {
			* Invalid latest version format, can't compare
			local update_available = 0
		}

		* Semantic comparison: latest > current
		if ("`cur_major'" != "" & "`lat_major'" != "") {
			if (`lat_major' > `cur_major') {
				local update_available = 1
			}
			else if (`lat_major' == `cur_major') {
				if (`lat_minor' > `cur_minor') {
					local update_available = 1
				}
				else if (`lat_minor' == `cur_minor') {
					if (`lat_patch' > `cur_patch') {
						local update_available = 1
					}
				}
			}
		}
	}

	* Return results (timestamp updated by caller only on success)
	return scalar update_available = `update_available'
	return local current_version "`current_version'"
	return local latest_version "`latest_version'"
	return local reason "success"
end

* -----------------------------------------------------------------------------
* check_background: Silently check for updates in background (24h cache)
* Called automatically before autolabel commands execute
* Sets globals: $REGISTREAM_UPDATE_AVAILABLE, $REGISTREAM_LATEST_VERSION
* Returns: Nothing (silent operation)
* -----------------------------------------------------------------------------
program define _upd_check_background
	args registream_dir current_version

	* Clear any previous update notifications
	global REGISTREAM_UPDATE_AVAILABLE = 0
	global REGISTREAM_LATEST_VERSION ""

	* Check if auto_update_check is enabled (default: true)
	_rs_config get "`registream_dir'" "auto_update_check"
	if (r(found) == 1 & "`r(value)'" == "false") {
		* Auto-update check disabled
		exit 0
	}

	* Check last_update_check timestamp (stored as numeric clock value)
	_rs_config get "`registream_dir'" "last_update_check"
	local last_check "`r(value)'"

	* Get current time as Stata clock (ms since 1960-01-01)
	local current_clock = clock("`c(current_date)' `c(current_time)'", "DMY hms")

	* If last_check is empty or > 24 hours ago, check for updates
	local should_check = 0

	if ("`last_check'" == "" | "`last_check'" == ".") {
		* Never checked before
		local should_check = 1
	}
	else {
		* Calculate time difference in milliseconds
		local time_diff_ms = `current_clock' - `last_check'

		* 24 hours = 86,400,000 milliseconds
		if (`time_diff_ms' >= 86400000) {
			local should_check = 1
		}
	}

	* If we should check, do it silently
	if (`should_check' == 1) {
		* Call check_package silently (capture all output)
		cap qui _rs_updates check_package "`registream_dir'" "`current_version'"

		* Save return values to locals IMMEDIATELY (before any other commands that might clear r())
		local rc_value = _rc
		local upd_avail = r(update_available)
		local latest_ver "`r(latest_version)'"
		local reason "`r(reason)'"

		if (`rc_value' == 0) {
			* Store results in globals AND config (persistent across sessions)
			global REGISTREAM_UPDATE_AVAILABLE = `upd_avail'

			* Persist to config for cross-session "harassment"
			if (`upd_avail' == 1) {
				global REGISTREAM_LATEST_VERSION "`latest_ver'"
				cap _rs_config set "`registream_dir'" "update_available" "true"
				cap _rs_config set "`registream_dir'" "latest_version" "`latest_ver'"
			}
			else {
				global REGISTREAM_LATEST_VERSION ""
				cap _rs_config set "`registream_dir'" "update_available" "false"
				cap _rs_config set "`registream_dir'" "latest_version" ""
			}

			* Only update last_update_check if API call succeeded
			* Store as numeric clock value (ms since 1960) for easy comparison
			if ("`reason'" == "success") {
				cap _rs_config set "`registream_dir'" "last_update_check" "`current_clock'"
			}
		}
	}
	* Always read from config to catch persistent notifications
	_rs_config get "`registream_dir'" "update_available"
	if (r(found) == 1 & "`r(value)'" == "true") {
		global REGISTREAM_UPDATE_AVAILABLE = 1
		_rs_config get "`registream_dir'" "latest_version"
		global REGISTREAM_LATEST_VERSION "`r(value)'"
	}
end

* -----------------------------------------------------------------------------
* show_notification: Display update notification if update is available
* Reads from globals set by check_background
* Call this at the end of commands to show non-intrusive update message
* -----------------------------------------------------------------------------
program define _upd_show_notification
	args current_version

	* Check if update is available (from background check)
	if ("$REGISTREAM_UPDATE_AVAILABLE" == "1") {
		di as text ""
		di as result "{hline 60}"
		di as result "A new version of RegiStream is available!"
		di as text "  Current version:  `current_version'"
		di as text "  Latest version:   $REGISTREAM_LATEST_VERSION"
		di as text ""
		di as text "To update, run: {stata registream update:registream update}"
		di as result "{hline 60}"
		di as text ""
	}
end

* -----------------------------------------------------------------------------
* send_heartbeat: Consolidated telemetry + update check via native Stata copy
* TELEMETRY: Sent on EVERY command (if enabled) to track usage
* UPDATES: Checked once per 24 hours (proper timestamp comparison, not just date)
* Uses GET request with query params - ZERO shell commands, ZERO flashes
* Args: registream_dir, current_version, command_string
* Returns: Updates globals if update available
* -----------------------------------------------------------------------------
program define _upd_send_heartbeat
	args registream_dir current_version command_string

	* Get settings
	_rs_config get "`registream_dir'" "telemetry_enabled"
	local telemetry_enabled "`r(value)'"

	_rs_config get "`registream_dir'" "auto_update_check"
	local update_enabled "`r(value)'"
	if ("`update_enabled'" == "") local update_enabled "true"

	* Determine if we should send telemetry (every command if enabled)
	local send_telemetry = 0
	if ("`telemetry_enabled'" == "true" | "`telemetry_enabled'" == "1") {
		local send_telemetry = 1
	}

	* Get current time as Stata clock (ms since 1960-01-01)
	local current_clock = clock("`c(current_date)' `c(current_time)'", "DMY hms")

	* Determine if we should check for updates (once per 24 hours if enabled)
	local check_updates = 0
	if ("`update_enabled'" == "true" | "`update_enabled'" == "1") {
		_rs_config get "`registream_dir'" "last_update_check"
		local last_check "`r(value)'"

		if ("`last_check'" == "" | "`last_check'" == ".") {
			* Never checked before
			local check_updates = 1
		}
		else {
			* Calculate time difference in milliseconds
			local time_diff_ms = `current_clock' - `last_check'

			* 24 hours = 86,400,000 milliseconds
			if (`time_diff_ms' >= 86400000) {
				local check_updates = 1
			}
		}
	}

	* If neither telemetry nor updates needed, exit early
	if (`send_telemetry' == 0 & `check_updates' == 0) {
		exit 0
	}

	* If only checking updates and cache is still valid, read from cache
	if (`send_telemetry' == 0 & `check_updates' == 0) {
		* Read cached update info from config
		_rs_config get "`registream_dir'" "update_available"
		if (r(found) == 1 & "`r(value)'" == "true") {
			global REGISTREAM_UPDATE_AVAILABLE = 1
			_rs_config get "`registream_dir'" "latest_version"
			global REGISTREAM_LATEST_VERSION "`r(value)'"
		}
		else {
			global REGISTREAM_UPDATE_AVAILABLE = 0
			global REGISTREAM_LATEST_VERSION ""
		}
		exit 0
	}

	* Get API host
	_rs_utils get_api_host
	local api_host "`r(host)'"

	* Get timestamp (always needed)
	local timestamp "`c(current_date)'T`c(current_time)'Z"

	* Build heartbeat URL based on what we're sending
	if (`send_telemetry' == 1) {
		* Get telemetry data
		_rs_usage compute_user_id "`registream_dir'"
		local user_id "`r(user_id)'"

		* Get OS info
		local platform "stata"
		local os "`c(os)'"
		if ("`os'" == "Windows") {
			local os "Windows"
		}
		else if ("`os'" == "Unix") {
			* Distinguish MacOS from Linux
			if ("`c(machine_type)'" == "Macintosh (Intel 64-bit)" | "`c(machine_type)'" == "Macintosh (ARM 64-bit)") {
				local os "MacOSX"
			}
			else {
				local os "Linux"
			}
		}
		local platform_version "`c(stata_version)'"

		* URL encode timestamp (spaces -> %20)
		local timestamp_encoded : subinstr local timestamp " " "%20", all

		* URL encode command string
		local command_encoded : subinstr local command_string " " "%20", all
		local command_encoded : subinstr local command_encoded "," "%2C", all
		local command_encoded : subinstr local command_encoded "(" "%28", all
		local command_encoded : subinstr local command_encoded ")" "%29", all

		* Build URL with telemetry data (always include version for proper tracking)
		local heartbeat_url "`api_host'/api/v1/stata/heartbeat?user_id=`user_id'&command=`command_encoded'&platform=`platform'&os=`os'&platform_version=`platform_version'&timestamp=`timestamp_encoded'&version=`current_version'"
	}
	else {
		* Only checking updates, no telemetry data
		local heartbeat_url "`api_host'/api/v1/stata/heartbeat?version=`current_version'"
	}

	* Use native Stata copy - NO SHELL, NO FLASH!
	tempfile response
	cap copy "`heartbeat_url'" "`response'", replace

	if (_rc == 0) {
		* Parse response (simple JSON parsing for update_available)
		tempname fh
		cap file open `fh' using "`response'", read text
		if (_rc == 0) {
			file read `fh' json_line
			file close `fh'

			* Extract update_available (look for "update_available": true/false)
			if (regexm(`"`json_line'"', `""update_available"[[:space:]]*:[[:space:]]*true"')) {
				global REGISTREAM_UPDATE_AVAILABLE = 1

				* Extract latest_version
				if (regexm(`"`json_line'"', `""latest_version"[[:space:]]*:[[:space:]]*"([^"]+)""')) {
					global REGISTREAM_LATEST_VERSION = regexs(1)

					* Persist to config for cross-session notifications
					cap _rs_config set "`registream_dir'" "update_available" "true"
					cap _rs_config set "`registream_dir'" "latest_version" "`=regexs(1)'"
				}
			}
			else {
				global REGISTREAM_UPDATE_AVAILABLE = 0
				global REGISTREAM_LATEST_VERSION ""
				cap _rs_config set "`registream_dir'" "update_available" "false"
				cap _rs_config set "`registream_dir'" "latest_version" ""
			}

			* Update last check timestamp ONLY if we checked for updates
			* Store as numeric clock value (ms since 1960) for easy comparison
			if (`check_updates' == 1) {
				cap _rs_config set "`registream_dir'" "last_update_check" "`current_clock'"
			}
		}
	}

	* Silent on all outcomes - heartbeat should never interrupt user workflow
end

* -----------------------------------------------------------------------------
* scan_datasets: Scan autolabel_keys directory for DTA files
* Used to rebuild datasets.csv when it's deleted or corrupted
* Returns: r(datasets_found) = number of datasets found
* -----------------------------------------------------------------------------
program define _upd_scan_datasets, rclass
	args registream_dir

	local autolabel_dir "`registream_dir'/autolabel_keys"

	* Get list of all .csv files in autolabel_keys (these are the actual downloaded datasets)
	local csv_files : dir "`autolabel_dir'" files "*.csv"

	local datasets_found = 0
	local dataset_list ""

	* Parse each CSV filename to extract domain_type_lang
	foreach csv_file of local csv_files {
		* Remove .csv extension
		local dataset_key = subinstr("`csv_file'", ".csv", "", 1)

		* Check if this matches our pattern: {domain}_{variables|value_labels}_{lang}
		if (regexm("`dataset_key'", "^(.+)_(variables|value_labels)_([a-z]+)$")) {
			local domain = regexs(1)
			local type_raw = regexs(2)
			local lang = regexs(3)

			* Convert type
			local type = cond("`type_raw'" == "value_labels", "values", "variables")

			* Add to list
			local dataset_list "`dataset_list' `dataset_key'"
			local ++datasets_found

			* Try to get schema version from corresponding DTA file
			local dta_file "`autolabel_dir'/`dataset_key'.dta"
			local schema_ver ""
			cap confirm file "`dta_file'"
			if (_rc == 0) {
				quietly {
					preserve
					cap use "`dta_file'", clear
					cap local schema_ver : char _dta[schema_version]
					restore
				}
			}
			* Default to 1.0 if not found
			if ("`schema_ver'" == "") local schema_ver "1.0"

			* Store information
			local dataset_`datasets_found'_key "`dataset_key'"
			local dataset_`datasets_found'_domain "`domain'"
			local dataset_`datasets_found'_type "`type'"
			local dataset_`datasets_found'_lang "`lang'"
			local dataset_`datasets_found'_schema "`schema_ver'"
		}
	}

	* Return results
	return scalar datasets_found = `datasets_found'
	return local dataset_list "`dataset_list'"

	* Return individual dataset info
	forval i = 1/`datasets_found' {
		return local dataset_`i'_key "`dataset_`i'_key'"
		return local dataset_`i'_domain "`dataset_`i'_domain'"
		return local dataset_`i'_type "`dataset_`i'_type'"
		return local dataset_`i'_lang "`dataset_`i'_lang'"
		return local dataset_`i'_schema "`dataset_`i'_schema'"
	}
end

* -----------------------------------------------------------------------------
* check_datasets: Check for updates to all downloaded datasets
* Sends bulk request to API with all current dataset versions
* Returns: r(updates_available) = number of datasets with updates
* -----------------------------------------------------------------------------
program define _upd_check_datasets, rclass
	args registream_dir

	* Check internet access setting
	_rs_config get "`registream_dir'" "internet_access"
	if (r(found) == 1 & "`r(value)'" == "false") {
		* Internet access disabled
		return scalar updates_available = 0
		return local reason "internet_disabled"
		exit 0
	}

	* Get current time for caching
	local current_clock = clock("`c(current_date)' `c(current_time)'", "DMY hms")

	* Check 24h cache first
	_rs_config get "`registream_dir'" "last_dataset_check"
	local last_check "`r(value)'"

	if ("`last_check'" != "" & "`last_check'" != ".") {
		* Calculate time difference
		local time_diff_ms = `current_clock' - `last_check'

		* If less than 24 hours, return cached result
		if (`time_diff_ms' < 86400000) {
			_rs_config get "`registream_dir'" "datasets_updates_available"
			local cached_count = "`r(value)'"
			if ("`cached_count'" == "" | "`cached_count'" == ".") local cached_count = 0

			return scalar updates_available = `cached_count'
			return local reason "cached"
			exit 0
		}
	}

	* Read datasets.csv to get current versions
	local meta_csv "`registream_dir'/autolabel_keys/datasets.csv"

	* If datasets.csv doesn't exist, try to scan and rebuild
	cap confirm file "`meta_csv'"
	if (_rc != 0) {
		di as text ""
		di as text "{hline 60}"
		di as result "datasets.csv not found - Scanning directory..."
		di as text "{hline 60}"

		_rs_updates scan_datasets "`registream_dir'"
		local scan_count = r(datasets_found)

		if (`scan_count' == 0) {
			* No datasets found
			di as text "No datasets found."
			di as text "{hline 60}"
			return scalar updates_available = 0
			return local reason "no_datasets"
			exit 0
		}

		* Rebuild CSV from scanned datasets
		_rs_updates rebuild_yaml "`registream_dir'"

		di as text "{hline 60}"
		di as text ""

		* Now check if any of the scanned datasets are available for re-download
		* by sending them with version: "unknown"
		local should_check_redownload = 1
	}
	else {
		local should_check_redownload = 0
	}

	* Build GET URL from datasets.csv
	tempfile response_body

	quietly {
		* Load datasets.csv
		cap import delimited using "`meta_csv'", clear varnames(1) stringcols(_all) delimiter(";")
		if (_rc != 0) {
			return scalar updates_available = 0
			return local reason "csv_read_error"
			exit 0
		}

		local dataset_count = _N

		if (`dataset_count' == 0) {
			return scalar updates_available = 0
			return local reason "no_datasets"
			exit 0
		}

		* Keep only needed columns
		keep version domain type lang dataset_key

		* Build pipe-delimited URL parameter
		local url_params = ""
		forval i = 1/`=_N' {
			local domain_val = domain[`i']
			local type_val = type[`i']
			local lang_val = lang[`i']
			local version_val = version[`i']

			if (`i' > 1) local url_params = "`url_params'|"
			local url_params = "`url_params'`domain_val';`type_val';`lang_val';`version_val'"
		}

		* URL encode special characters
		local url_params : subinstr local url_params "|" "%7C", all
		local url_params : subinstr local url_params ";" "%3B", all
	}

	* Check URL length safety (fallback to POST if too long)
	local url_length = length("`url_params'")
	if (`url_length' > 1500) {
		di as error "Too many datasets (`dataset_count') for GET request"
		di as error "Please contact support - this is a rare edge case"
		return scalar updates_available = 0
		return local reason "too_many_datasets"
		exit 0
	}

	* Get API host
	_rs_utils get_api_host
	local api_host "`r(host)'"

	* Construct GET URL with datasets parameter
	local updates_url "`api_host'/api/v1/datasets/check_updates?datasets=`url_params'"

	* Use native Stata copy - NO SHELL, NO FLASH!
	cap copy "`updates_url'" "`response_body'", replace

	if (_rc != 0) {
		* Network error
		return scalar updates_available = 0
		return local reason "network_error"
		exit 0
	}

	* Parse CSV response
	cap qui import delimited using "`response_body'", clear varnames(1)
	if (_rc == 0 & _N > 0) {
		* Count updates and re-downloads
		local updates_count = 0
		local redownload_count = 0

		forval i = 1/`=_N' {
			* Check if update available
			if (update_available[`i'] == 1) {
				local ++updates_count
			}

			* Check if this is a re-download suggestion (unknown version)
			if (current_version[`i'] == "unknown" & available_for_download[`i'] == 1) {
				local ++redownload_count
				local redownload_`redownload_count'_domain = domain[`i']
				local redownload_`redownload_count'_type = type[`i']
				local redownload_`redownload_count'_lang = lang[`i']
				local redownload_`redownload_count'_latest = latest_version[`i']
			}
		}

		* If we scanned and rebuilt, show re-download suggestions
		if (`should_check_redownload' == 1 & `redownload_count' > 0) {
			di as text ""
			di as text "{hline 60}"
			di as result "Datasets Available for Re-download"
			di as text "{hline 60}"
			di as text "The following datasets were found but have unknown versions."
			di as text "They are available for re-download with proper metadata:"
			di as text ""

			forval i = 1/`redownload_count' {
				local ds_key "`redownload_`i'_domain'_`redownload_`i'_type'_`redownload_`i'_lang'"
				di as text "  • {result:`ds_key'} (latest: `redownload_`i'_latest')"
			}

			di as text ""
			di as text "To re-download with metadata tracking:"
			di as text "  autolabel `redownload_1_type', domain(`redownload_1_domain') lang(`redownload_1_lang') force"
			di as text "{hline 60}"
			di as text ""
		}

		* Save to cache
		cap _rs_config set "`registream_dir'" "last_dataset_check" "`current_clock'"
		cap _rs_config set "`registream_dir'" "datasets_updates_available" "`updates_count'"

		return scalar updates_available = `updates_count'
		return scalar redownload_suggested = `redownload_count'
		return local reason "success"
	}
	else {
		* Save empty cache
		cap _rs_config set "`registream_dir'" "last_dataset_check" "`current_clock'"
		cap _rs_config set "`registream_dir'" "datasets_updates_available" "0"

		return scalar updates_available = 0
		return local reason "parse_error"
	}
end

* -----------------------------------------------------------------------------
* update_datasets_interactive: Interactive workflow for updating datasets
* Checks for updates, displays list, prompts for selection, downloads
* Args: registream_dir, domain(optional), lang(optional), version(optional)
* -----------------------------------------------------------------------------
program define _upd_update_datasets_interactive, rclass
	syntax anything [, DOMAIN(string) LANG(string) VERSION(string)]
	local registream_dir `anything'

	local autolabel_dir "`registream_dir'/autolabel_keys"

	* Check internet access setting
	_rs_config get "`registream_dir'" "internet_access"
	if (r(found) == 1 & "`r(value)'" == "false") {
		di as text "Update check disabled (offline mode)"
		di as text "To enable: registream config, internet_access(true)"
		return scalar updates_downloaded = 0
		return local reason "internet_disabled"
		exit 0
	}

	* Read datasets.csv to get current versions
	local meta_csv "`autolabel_dir'/datasets.csv"

	tempfile response_body

	* Load datasets.csv
	preserve
	cap qui import delimited using "`meta_csv'", clear varnames(1) stringcols(_all) delimiter(";")

	if (_rc != 0) {
		restore
		di as text "No datasets found to check for updates"
		di as text "Download datasets first: autolabel variables, domain(scb) lang(eng)"
		return scalar updates_downloaded = 0
		return local reason "no_datasets"
		exit 0
	}

	if (_N == 0) {
		restore
		di as text "No datasets found"
		return scalar updates_downloaded = 0
		return local reason "no_datasets"
		exit 0
	}

	* Apply filters if specified
	if ("`domain'" != "") {
		qui keep if domain == "`domain'"
	}
	if ("`lang'" != "") {
		qui keep if lang == "`lang'"
	}

	if (_N == 0) {
		restore
		di as text "No datasets match the specified filters"
		return scalar updates_downloaded = 0
		return local reason "no_matching_datasets"
		exit 0
	}

	* Build pipe-delimited URL parameter
	local url_params = ""
	forval i = 1/`=_N' {
		local domain_val = domain[`i']
		local type_val = type[`i']
		local lang_val = lang[`i']
		local version_val = version[`i']

		if (`i' > 1) local url_params = "`url_params'|"
		local url_params = "`url_params'`domain_val';`type_val';`lang_val';`version_val'"
	}

	* URL encode special characters
	local url_params : subinstr local url_params "|" "%7C", all
	local url_params : subinstr local url_params ";" "%3B", all

	restore

	* Check URL length safety
	local url_length = length("`url_params'")
	if (`url_length' > 1500) {
		di as error "Too many datasets for GET request"
		di as error "Please contact support - this is a rare edge case"
		return scalar updates_downloaded = 0
		return local reason "too_many_datasets"
		exit 0
	}

	* Get API host
	_rs_utils get_api_host
	local api_host "`r(host)'"

	* Construct GET URL with datasets parameter
	local updates_url "`api_host'/api/v1/datasets/check_updates?datasets=`url_params'"

	* Use native Stata copy - NO SHELL, NO FLASH!
	cap copy "`updates_url'" "`response_body'", replace

	if (_rc != 0) {
		di as text "Could not check for updates (network error)"
		return scalar updates_downloaded = 0
		return local reason "network_error"
		exit 0
	}

	* Parse CSV response
	preserve
	cap qui import delimited using "`response_body'", clear varnames(1) stringcols(_all)
	if (_rc != 0 | _N == 0) {
		restore
		di as error "Error parsing API response"
		return scalar updates_downloaded = 0
		return local reason "parse_error"
		exit 0
	}

	* If user specified a version, override latest_version BEFORE filtering
	if ("`version'" != "") {
		* Normalize version format (remove 'v' prefix if present)
		local target_version = "`version'"
		if (regexm("`target_version'", "^v(.+)$")) {
			local target_version = regexs(1)
		}

		* Override all latest versions with the user-specified version
		qui replace latest_version = "`target_version'"
	}

	* Filter to only show updates/changes
	if ("`version'" == "") {
		* Normal mode: only show datasets with updates available
		qui keep if update_available == "1"
	}
	else {
		* Version specified: keep datasets where current != target
		* (Skip datasets already at target version - no point re-downloading)
		qui keep if current_version != latest_version
	}

	local updates_count = _N

	if (`updates_count' == 0) {
		restore
		if ("`version'" != "") {
			di as result "All datasets are already at version `target_version'!"
		}
		else {
			di as result "All datasets are up to date!"
		}
		return scalar updates_downloaded = 0
		return local reason "no_updates"
		exit 0
	}

	* Save update information to locals BEFORE restoring
	forval i = 1/`updates_count' {
		local upd_`i'_domain = domain[`i']
		local upd_`i'_type = type[`i']
		local upd_`i'_lang = lang[`i']
		local upd_`i'_current = current_version[`i']
		local upd_`i'_latest = latest_version[`i']
	}

	restore

	* Set display note if version was specified
	if ("`version'" != "") {
		* target_version was already set earlier
		local version_note " (target version: `target_version')"
	}
	else {
		local version_note ""
	}

	* Display numbered list of updates
	di as text ""
	if ("`version'" != "") {
		di as text "Available Datasets`version_note':"
	}
	else {
		di as text "Available Updates:"
	}
	di as text "{hline 60}"
	forval i = 1/`updates_count' {
		local ds_key "`upd_`i'_domain'_`upd_`i'_type'_`upd_`i'_lang'"
		di as text %3.0f `i' ".  {result:`ds_key'}"
		di as text "     Current: `upd_`i'_current' → Target: `upd_`i'_latest'"
	}
	di as text "{hline 60}"
	di as text ""

	* Prompt for selection (NOW outside preserve/restore)
	di as text "Enter dataset numbers to update (comma-separated), 'all', or 'cancel':"
	di as input "> " _request(rsinput)

	* _request MUST use global (Stata limitation), copy to local and clear
	local user_input = trim(lower("$rsinput"))
	global rsinput ""

	* Check for cancel/quit
	if ("`user_input'" == "cancel" | "`user_input'" == "q" | "`user_input'" == "quit" | "`user_input'" == "") {
		di as text ""
		di as text "Update cancelled"
		return scalar updates_downloaded = 0
		return local reason "cancelled"
		exit 0
	}

	* Handle 'all' selection
	if ("`user_input'" == "all") {
		local selection_count = `updates_count'
		forval i = 1/`selection_count' {
			local sel_`i' = `i'
		}
	}
	* Handle comma-separated numbers
	else {
		local selection_count = 0

		* Remove all spaces to make parsing easier
		local user_input : subinstr local user_input " " "", all

		* Split by comma and validate
		local remaining "`user_input'"
		while ("`remaining'" != "") {
			gettoken num remaining : remaining, parse(",")

			* Skip commas and empty strings
			if ("`num'" == "," | "`num'" == "") continue

			* Validate number
			cap confirm integer number `num'
			if (_rc == 0 & `num' >= 1 & `num' <= `updates_count') {
				local ++selection_count
				local sel_`selection_count' = `num'
			}
		}

		if (`selection_count' == 0) {
			di as error "No valid selections provided"
			di as text "Hint: Enter 'all', specific numbers like '1,2', or 'cancel'"
			return scalar updates_downloaded = 0
			return local reason "invalid_selection"
			exit 0
		}
	}

	* Map selections to the saved update info
	* (Data was already saved to upd_* locals and restored earlier)

	* Download selected datasets
	di as text ""
	di as result "{hline 60}"
	di as result "Downloading Updates..."
	di as result "{hline 60}"

	local downloaded_count = 0

	forval i = 1/`selection_count' {
		* Map selection to update index
		local idx = `sel_`i''
		local ds_domain = "`upd_`idx'_domain'"
		local ds_type_raw = "`upd_`idx'_type'"
		local ds_lang = "`upd_`idx'_lang'"
		local ds_latest = "`upd_`idx'_latest'"

		* Normalize type: API returns "value_labels" or "values", schema expects "values" or "variables"
		local ds_type = cond("`ds_type_raw'" == "value_labels", "values", "`ds_type_raw'")

		* Convert type for filename: schema type to filename type
		local file_type = cond("`ds_type'" == "values", "value_labels", "variables")
		local filename "`ds_domain'_`file_type'_`ds_lang'"

		di as text ""
		di as result "`i'/`selection_count': `filename'"
		di as text "  Downloading version `ds_latest'..."

		* Construct file paths
		local csv_file "`autolabel_dir'/`filename'.csv"
		local dta_file "`autolabel_dir'/`filename'.dta"
		local zip_file "`autolabel_dir'/`filename'.zip"
		local zip_folder "`autolabel_dir'/`filename'"

		* Delete existing files to force re-download
		cap erase "`csv_file'"
		cap erase "`dta_file'"
		cap erase "`zip_file'"
		cap _rs_utils del_folder_rec "`zip_folder'"

		* Download using autolabel utils (quietly to suppress verbose output)
		cap qui _rs_autolabel_utils download_extract, ///
			zip("`zip_file'") zipfold("`zip_folder'") ///
			csv("`csv_file'") dta("`dta_file'") ///
			file("`filename'") ///
			registream_dir("`registream_dir'") ///
			autolabel_dir("`autolabel_dir'") ///
			clean("`ds_type'") ///
			version("`ds_latest'")

		if (_rc == 0) {
			di as result "  ✓ Downloaded successfully"
			local ++downloaded_count
		}
		else {
			di as error "  ✗ Download failed"
		}
	}

	di as text ""
	di as result "{hline 60}"
	di as result "Update Complete: `downloaded_count'/`selection_count' dataset(s) updated"
	di as result "{hline 60}"

	return scalar updates_downloaded = `downloaded_count'
	return local reason "success"
end

* -----------------------------------------------------------------------------
* rebuild_yaml: Rebuild datasets.csv from scanned DTA files
* This preserves existing custom entries and adds API-downloaded datasets
* -----------------------------------------------------------------------------
program define _upd_rebuild_yaml, rclass
	args registream_dir

	* Scan for datasets
	_rs_updates scan_datasets "`registream_dir'"
	local datasets_found = r(datasets_found)

	if (`datasets_found' == 0) {
		di as text "No datasets found to rebuild datasets.csv"
		exit 0
	}

	* CSV file location
	local meta_csv "`registream_dir'/autolabel_keys/datasets.csv"

	* Backup existing CSV if it exists
	cap confirm file "`meta_csv'"
	if (_rc == 0) {
		di as text "Note: Existing datasets.csv will be backed up"
		cap copy "`meta_csv'" "`meta_csv'.backup", replace
	}

	* Create new CSV file
	tempname fh
	file open `fh' using "`meta_csv'", write replace

	* Write header (with explicit domain, type, lang columns)
	* Using semicolon delimiter for consistency
	file write `fh' "dataset_key;domain;type;lang;version;schema;downloaded;source;file_size;last_checked" _n

	* Add scanned datasets
	forval i = 1/`datasets_found' {
		local key = "`r(dataset_`i'_key)'"
		local domain = "`r(dataset_`i'_domain)'"
		local type = "`r(dataset_`i'_type)'"
		local lang = "`r(dataset_`i'_lang)'"
		local schema = "`r(dataset_`i'_schema)'"

		* Get file size using Mata (cross-platform: Windows, Mac, Linux)
		local csv_file "`registream_dir'/autolabel_keys/`key'.csv"
		local file_size = 0
		cap confirm file "`csv_file'"
		if (_rc == 0) {
			_rs_utils get_filesize "`csv_file'"
			local file_size = r(size)
		}
		if ("`file_size'" == "" | "`file_size'" == ".") local file_size = 0

		* Write CSV row (with explicit domain, type, lang columns)
		* Using semicolon delimiter
		file write `fh' "`key';`domain';`type';`lang';unknown;`schema';unknown;scanned;`file_size';" _n
	}

	file close `fh'

	di as result "✓ Rebuilt datasets.csv with `datasets_found' dataset(s)"
	return scalar datasets_rebuilt = `datasets_found'
end
