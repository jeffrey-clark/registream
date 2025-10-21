* =============================================================================
* RegiStream Update Checker
* Check for package updates and dataset updates
* Usage: _rs_updates subcommand [args]
* =============================================================================

cap program drop _rs_updates
cap program drop _upd_check_package
cap program drop _upd_check_background
cap program drop _upd_show_notification
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

	* Fetch latest version from API
	tempfile version_json
	cap qui shell curl -s -m 5 "`version_url'" > "`version_json'"
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

	* Check last_update_check timestamp
	_rs_config get "`registream_dir'" "last_update_check"
	local last_check "`r(value)'"

	* If last_check is empty or > 24 hours ago, check for updates
	local should_check = 0

	if ("`last_check'" == "" | "`last_check'" == ".") {
		* Never checked before
		local should_check = 1
	}
	else {
		* Parse timestamp and check if > 24 hours old
		* Format: "20 Oct 2025T13:45:30Z" or similar
		* Simple heuristic: extract date and time, compare with current

		* Get current date/time
		local current_date "`c(current_date)'"
		local current_time "`c(current_time)'"

		* Extract date from last_check (before 'T')
		if (strpos("`last_check'", "T") > 0) {
			local check_date = substr("`last_check'", 1, strpos("`last_check'", "T") - 1)

			* Simple check: if dates don't match, it's been at least a day
			* This is a simplified approach - for production might want Clock calculations
			if ("`check_date'" != "`current_date'") {
				local should_check = 1
			}
		}
		else {
			* Malformed timestamp, check anyway
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
			if ("`reason'" == "success") {
				local check_date "`c(current_date)'"
				local check_time "`c(current_time)'"
				cap _rs_config set "`registream_dir'" "last_update_check" "`check_date'T`check_time'Z"
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

	* Build CSV request from datasets.csv
	tempfile request_body response_body

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

		* Keep only needed columns and export
		* (domain, type, lang already exist in datasets.csv)
		keep version schema domain type lang
		export delimited using "`request_body'", replace delimiter(";")
	}

	* Get API host
	_rs_utils get_api_host
	local api_host "`r(host)'"

	* Construct bulk update check endpoint with CSV format
	local updates_url "`api_host'/api/v1/datasets/check_updates?format=csv"

	* Send POST request with CSV
	cap qui shell curl -s -m 10 -X POST -H "Content-Type: text/csv" --data-binary @"`request_body'" "`updates_url'" > "`response_body'"

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

		return scalar updates_available = `updates_count'
		return scalar redownload_suggested = `redownload_count'
		return local reason "success"
	}
	else {
		return scalar updates_available = 0
		return local reason "parse_error"
	}
end

* -----------------------------------------------------------------------------
* update_datasets_interactive: Interactive workflow for updating datasets
* Checks for updates, displays list, prompts for selection, downloads
* Args: registream_dir, domain(optional), lang(optional)
* -----------------------------------------------------------------------------
program define _upd_update_datasets_interactive, rclass
	syntax anything [, DOMAIN(string) LANG(string)]
	local registream_dir "`anything'"

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
	local meta_csv "`registream_dir'/autolabel_keys/datasets.csv"
	local autolabel_dir "`registream_dir'/autolabel_keys"

	* Check if datasets.csv exists
	cap confirm file "`meta_csv'"
	if (_rc != 0) {
		di as text "No datasets found to check for updates"
		di as text "Download datasets first: autolabel variables, domain(scb) lang(eng)"
		return scalar updates_downloaded = 0
		return local reason "no_datasets"
		exit 0
	}

	* Build CSV request from datasets.csv
	tempfile request_body response_body

	preserve
	quietly {
		* Load datasets.csv
		cap import delimited using "`meta_csv'", clear varnames(1) stringcols(_all) delimiter(";")
		if (_rc != 0) {
			restore
			di as error "Error reading datasets.csv"
			return scalar updates_downloaded = 0
			return local reason "csv_read_error"
			exit 0
		}

		local dataset_count = _N

		if (`dataset_count' == 0) {
			restore
			di as text "No datasets found to check for updates"
			return scalar updates_downloaded = 0
			return local reason "no_datasets"
			exit 0
		}

		* Apply filters if specified
		if ("`domain'" != "") {
			keep if domain == "`domain'"
		}
		if ("`lang'" != "") {
			keep if lang == "`lang'"
		}

		if (_N == 0) {
			restore
			di as text "No datasets match the specified filters"
			return scalar updates_downloaded = 0
			return local reason "no_matching_datasets"
			exit 0
		}

		* Keep only needed columns and export
		keep version schema domain type lang
		export delimited using "`request_body'", replace delimiter(";")
	}
	restore

	* Get API host
	_rs_utils get_api_host
	local api_host "`r(host)'"

	* Construct bulk update check endpoint with CSV format
	local updates_url "`api_host'/api/v1/datasets/check_updates?format=csv"

	* Send POST request with CSV
	cap qui shell curl -s -m 10 -X POST -H "Content-Type: text/csv" --data-binary @"`request_body'" "`updates_url'" > "`response_body'"

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

	* Filter to only show updates
	keep if update_available == "1"

	local updates_count = _N

	if (`updates_count' == 0) {
		restore
		di as result "All datasets are up to date!"
		return scalar updates_downloaded = 0
		return local reason "no_updates"
		exit 0
	}

	* Display numbered list of updates
	di as text ""
	di as text "Available Updates:"
	di as text "{hline 70}"
	forval i = 1/`updates_count' {
		local ds_domain = domain[`i']
		local ds_type = type[`i']
		local ds_lang = lang[`i']
		local ds_current = current_version[`i']
		local ds_latest = latest_version[`i']

		local ds_key "`ds_domain'_`ds_type'_`ds_lang'"
		di as text %3.0f `i' ".  {result:`ds_key'}"
		di as text "     Current: `ds_current' → Latest: `ds_latest'"
	}
	di as text "{hline 70}"
	di as text ""

	* Prompt for selection
	di as text "Enter dataset numbers to update (comma-separated) or 'all':"
	di as input "> " _request(user_input)
	local user_input = trim(`"`r(user_input)'"')

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

		* Split by comma and validate
		local remaining "`user_input'"
		while ("`remaining'" != "") {
			gettoken num remaining : remaining, parse(",")
			local num = trim("`num'")

			* Skip commas
			if ("`num'" == ",") continue

			* Validate number
			cap confirm integer number `num'
			if (_rc == 0 & `num' >= 1 & `num' <= `updates_count') {
				local ++selection_count
				local sel_`selection_count' = `num'
			}
		}

		if (`selection_count' == 0) {
			restore
			di as error "No valid selections provided"
			return scalar updates_downloaded = 0
			return local reason "invalid_selection"
			exit 0
		}
	}

	* Save update information to locals before restoring
	forval i = 1/`selection_count' {
		local idx = `sel_`i''
		local upd_`i'_domain = domain[`idx']
		local upd_`i'_type = type[`idx']
		local upd_`i'_lang = lang[`idx']
		local upd_`i'_latest = latest_version[`idx']
	}
	restore

	* Download selected datasets
	di as text ""
	di as result "{hline 70}"
	di as result "Downloading Updates..."
	di as result "{hline 70}"

	local downloaded_count = 0

	forval i = 1/`selection_count' {
		local ds_domain = "`upd_`i'_domain'"
		local ds_type = "`upd_`i'_type'"
		local ds_lang = "`upd_`i'_lang'"
		local ds_latest = "`upd_`i'_latest'"

		* Convert type for filename
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

		* Download using autolabel utils
		cap noi _rs_autolabel_utils download_extract, ///
			zip("`zip_file'") zipfold("`zip_folder'") ///
			csv("`csv_file'") dta("`dta_file'") ///
			file("`filename'") ///
			registream_dir("`registream_dir'") ///
			autolabel_dir("`autolabel_dir'") ///
			clean("`ds_type'")

		if (_rc == 0) {
			di as result "  ✓ Downloaded successfully"
			local ++downloaded_count
		}
		else {
			di as error "  ✗ Download failed"
		}
	}

	di as text ""
	di as result "{hline 70}"
	di as result "Update Complete: `downloaded_count'/`selection_count' dataset(s) updated"
	di as result "{hline 70}"
	di as text ""

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
