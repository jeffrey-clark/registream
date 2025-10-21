* =============================================================================
* RegiStream Autolabel Utility Functions
* Utilities specific to the autolabel module
* Usage: _rs_autolabel_utils subcommand [args]
* =============================================================================

cap program drop _rs_autolabel_utils
cap program drop _al_download
cap program drop _al_append
cap program drop _al_summarize
cap program drop _al_fetch
cap program drop _al_store_meta
cap program drop _al_get_ver
cap program drop _al_check_ver
cap program drop _al_check_updates
cap program drop _al_update_checked
cap program drop _al_verify_integrity
cap program drop _al_get_latest_version

program define _rs_autolabel_utils, rclass
	version 16.0

	gettoken subcmd 0 : 0, parse(" ,")

	if ("`subcmd'" == "download_extract") {
		_al_download `0'
		return add
	}
	else if ("`subcmd'" == "append_csv") {
		_al_append `0'
	}
	else if ("`subcmd'" == "summarize_dataset") {
		_al_summarize `0'
		return add
	}
	else if ("`subcmd'" == "fetch_with_errors") {
		_al_fetch `0'
		return add
	}
	else if ("`subcmd'" == "store_dataset_metadata") {
		_al_store_meta `0'
	}
	else if ("`subcmd'" == "check_dataset_version") {
		_al_check_ver `0'
		return add
	}
	else if ("`subcmd'" == "get_dataset_version") {
		_al_get_ver `0'
		return add
	}
	else if ("`subcmd'" == "check_for_updates") {
		_al_check_updates `0'
		return add
	}
	else if ("`subcmd'" == "prompt_user") {
		_rs_utils prompt `0'
		return add
	}
	else if ("`subcmd'" == "update_last_checked") {
		_al_update_checked `0'
	}
	else if ("`subcmd'" == "verify_file_integrity") {
		_al_verify_integrity `0'
		return add
	}
	else if ("`subcmd'" == "get_latest_version_from_api") {
		_al_get_latest_version `0'
		return add
	}
	else if ("`subcmd'" == "validate_domain_language_offline") {
		_al_validate_local `0'
		return add
	}
	else {
		di as error "Invalid _rs_autolabel_utils subcommand: `subcmd'"
		exit 198
	}
end

* -----------------------------------------------------------------------------
* download_extract: Download and extract metadata files
* -----------------------------------------------------------------------------
program define _al_download, rclass
	syntax , zip(string) zipfold(string) csv(string) dta(string) file(string) registream_dir(string) autolabel_dir(string) clean(string) [version(string)]

	* Default to latest if no version specified
	if ("`version'" == "") {
		local version "latest"
	}

	* Parse filename to get domain, type, lang for version checking
	if strpos("`file'", "_value_labels_") > 0 {
		local check_domain = substr("`file'", 1, strpos("`file'", "_value_labels_") - 1)
		local check_lang = substr("`file'", strpos("`file'", "_value_labels_") + 14, .)
		local check_type "values"
	}
	else if strpos("`file'", "_variables_") > 0 {
		local check_domain = substr("`file'", 1, strpos("`file'", "_variables_") - 1)
		local check_lang = substr("`file'", strpos("`file'", "_variables_") + 11, .)
		local check_type "variables"
	}

	* Verify file integrity first (checks existence, metadata, size)
	* This will prompt user if issues are detected
	_rs_autolabel_utils verify_file_integrity "`autolabel_dir'" "`check_domain'" "`check_type'" "`check_lang'" "`csv'" "`dta'"
	local should_download = r(should_download)
	local user_already_approved = r(user_approved)
	local integrity_version "`r(download_version)'"

	* If integrity check returned a specific version, use it
	if ("`integrity_version'" != "") {
		local version "`integrity_version'"
	}

	* If integrity check says to download, force download by deleting existing files
	if (`should_download' == 1) {
		cap erase "`csv'"
		cap erase "`dta'"
	}

	* Check for updates / version tracking (only if internet enabled)
	* This informs users about API availability and version updates
	_rs_autolabel_utils check_for_updates "`autolabel_dir'" "`check_domain'" "`check_type'" "`check_lang'" "`dta'"

	* Ensure that the CSV file exists
	if (fileexists("`csv'") == 0) {

		* MONA CHECK: if no csv, but constituent folder, proceed to build
		_rs_utils confirmdir "`zipfold'"
		if (r(exists) == 1) {
			// discovered the constituent csv files, skip download, proceed to build
		}
		else {
			* Check if internet access is enabled before attempting download
			_rs_config get "`registream_dir'" "internet_access"
			local has_internet = r(value)
			local config_found = r(found)

			* Default to enabled if config doesn't exist or value not found
			if (`config_found' == 0 | "`has_internet'" == "") {
				local has_internet "true"
			}

			if ("`has_internet'" != "true" & "`has_internet'" != "1") {
				* Internet access is disabled - cannot download from API
				* Use local validation to provide helpful error message
				_rs_autolabel_utils validate_domain_language_offline "`autolabel_dir'" "`check_domain'" "`check_lang'"
				local domain_valid = r(domain_valid)
				local lang_valid = r(lang_valid)
				local available_domains = r(available_domains)
				local available_languages = r(available_languages)

				di as error ""
				di as error "{hline 60}"
				di as error "Dataset Not Available (Offline Mode)"
				di as error "{hline 60}"
				di as text "Dataset: {result:`file'}"
				di as text ""

				* Check if we have any local datasets
				local has_local_data = ("`available_domains'" != "" & "`available_domains'" != ".")

				if (!`has_local_data') {
					* No local datasets at all - fresh install or deleted datasets.csv
					di as text "No datasets available locally."
					di as text ""
					di as text "Internet access is disabled."
					di as text ""
					di as text "To add datasets manually:"
					di as text "  https://registream.org/docs/manual-datasets"
					di as text ""
					di as text "For system configuration, contact your administrator."
				}
				else {
					* We have some datasets locally - show what's available
					if (`domain_valid' == 0) {
						di as error "Unknown domain: {result:`check_domain'}"
						di as text "Available domains: `available_domains'"
					}
					else if (`lang_valid' == 0) {
						di as error "Unknown language: {result:`check_lang'}"
						di as text "Available languages for {result:`check_domain'}: `available_languages'"
					}
					else {
						di as text "This dataset is not available locally."
						di as text "Available domains: `available_domains'"
					}
					di as text ""
					di as text "To add datasets: https://registream.org/docs/manual-datasets"
				}

				di as text ""
				di as text "Config location: Run {result:autolabel info}"
				di as error "{hline 60}"
				di as error ""
				exit 1
			}

			* Prompt user for download permission (unless already approved in verify_integrity)
			if (`user_already_approved' == 0) {
				di as text ""
				di as text "Dataset file does not exist: {result:`file'.csv}"
				di as text ""

				_rs_utils prompt "Download dataset from RegiStream API?"
				* If we reach here, user approved (prompt exits on "no")
			}

			* Get API host (production or dev override)
			_rs_utils get_api_host
			local api_host "`r(host)'"

			* Parse filename to extract domain, type, and language for API v1
			* Two patterns supported:
			*   {domain}_variables_{lang} -> /api/v1/datasets/{domain}/variables/{lang}/latest
			*   {domain}_value_labels_{lang} -> /api/v1/datasets/{domain}/values/{lang}/latest

			if strpos("`file'", "_value_labels_") > 0 {
				* Pattern: scb_value_labels_eng
				local domain = substr("`file'", 1, strpos("`file'", "_value_labels_") - 1)
				local lang = substr("`file'", strpos("`file'", "_value_labels_") + 14, .)
				local type "values"
			}
			else if strpos("`file'", "_variables_") > 0 {
				* Pattern: scb_variables_eng
				local domain = substr("`file'", 1, strpos("`file'", "_variables_") - 1)
				local lang = substr("`file'", strpos("`file'", "_variables_") + 11, .)
				local type "variables"
			}
			else {
				di as error "Unknown file pattern: `file'"
				di as error "Expected: {domain}_variables_{lang} or {domain}_value_labels_{lang}"
				exit 198
			}

			* Construct API v1 endpoint: /api/v1/datasets/{domain}/{type}/{lang}/{version}
			local api_url "`api_host'/api/v1/datasets/`domain'/`type'/`lang'/`version'"

			di as text ""
			di as text "{hline 60}"
			di as text "RegiStream Download"
			di as text "{hline 60}"
			di as text "  Domain:  {result:`domain'}"
			di as text "  Type:    {result:`type'}"
			di as text "  Language: {result:`lang'}"
			di as text "  Version:  {result:`version'}"
			di as text "  URL:     {result:`api_url'}"
			di as text "{hline 60}"

			* Use helper function to download with detailed error handling
			_rs_autolabel_utils fetch_with_errors "`api_url'" "`zip'" "`domain'" "`type'" "`lang'" "`version'"

			* Check if download succeeded
			local fetch_status = r(status)
			local downloaded_version = r(version)
			local downloaded_schema = r(schema)

			if (`fetch_status' != 0) {
				* Error already displayed by fetch_with_errors
				exit 1
			}

			* Display success message with version info
			di as text ""
			di as result "Download successful!"
			if ("`downloaded_version'" != "") {
				di as text "  Dataset Version: {result:`downloaded_version'}"
			}
			if ("`downloaded_schema'" != "") {
				di as text "  Schema Version:  {result:`downloaded_schema'}"
			}
			di as text "{hline 60}"
			di as text ""

			* Unzip the zip file (quietly)
			local original_dir `"`c(pwd)'"'
			quietly cd "`autolabel_dir'"
			quietly cap unzipfile "`file'.zip", replace
			if (_rc != 0) {
				quietly cd "`original_dir'"
				di as error "ERROR: Failed to unzip `file'.zip"
				di as error "  ZIP file: `autolabel_dir'/`file'.zip"
				di as error "  Expected folder: `zipfold'"
				di as error "  Stata's unzipfile command failed (RC: " _rc ")"
				exit 1
			}
			quietly cd "`original_dir'"

			* Verify the folder was created
			_rs_utils confirmdir "`zipfold'"
			if (r(exists) == 0) {
				di as error "ERROR: Unzip succeeded but folder not found: `zipfold'"
				exit 1
			}
		}

		* Append the constituent csv files (only if folder exists from download)
		_rs_utils confirmdir "`zipfold'"
		if (r(exists) == 1) {
			preserve
			_rs_autolabel_utils append_csv "`zipfold'" "`csv'"
			restore
		}


		if (fileexists(trim("`csv'")) == 0) {
			di as error "Oops something went wrong. Contact developers."
			if ("$REGISTREAM_DEBUG" == "1") {
				di as error "DEBUG: Expected CSV file: `csv'"
				di as error "DEBUG: After trim: " trim("`csv'")
				di as error "DEBUG: Zipfold: `zipfold'"
			}
			exit 1
		}

		* Store dataset metadata in datasets.csv (pass CSV path to get file size)
		_rs_autolabel_utils store_dataset_metadata "`autolabel_dir'" "`domain'" "`type'" "`lang'" "`downloaded_version'" "`downloaded_schema'" "`csv'"

		* Update last_checked timestamp since we just downloaded
		_rs_autolabel_utils update_last_checked "`autolabel_dir'" "`domain'" "`type'" "`lang'"
	}

	* Since the CSV file exists, remove the constituent folder and zipfile
	if (fileexists("`csv'") == 1) {
		cap _rs_utils del_folder_rec "`zipfold'"
		cap erase "`zip'"
	}

	* Convert the CSV file to DTA if not already done
	if (fileexists("`dta'") == 0) {
		quietly {
			preserve
			import delimited using "`csv'", clear ///
				encoding("utf-8") bindquote(strict) maxquotedrows(unlimited) varnames(1)
			replace variable_name = lower(variable_name)
			order variable_name, first
			sort variable_name
			bysort variable_name : keep if _n == 1

			* Custom cleaning logic based on the type
			if ("`clean'" == "values") {
				* Drop rows with empty value_labels_json if column exists
				cap confirm variable value_labels_json
				if (_rc == 0) {
					drop if value_labels_json == "{}"
				}
				* Drop value_labels_json only (we use value_labels_stata instead)
				cap drop value_labels_json
			}

			* Add schema version characteristic
			char _dta[schema_version] "1.0"

			* Validate schema before saving
			_rs_validate_schema, type(`clean')

			save "`dta'", replace
			restore
		}
	}
	else {
		* DTA exists, validate it
		quietly {
			preserve
			use "`dta'", clear
			_rs_validate_schema, type(`clean')
			restore
		}
	}
end

* -----------------------------------------------------------------------------
* append_csv: Append multiple CSV files into one
* -----------------------------------------------------------------------------
program define _al_append
	args folder output_file

	// List all CSV files in the directory
	local csv_files : dir "`folder'" files "*.csv"

	// For zero-padded files like _0000.csv, _0001.csv, etc.
	// Lexicographic sorting works correctly, so just sort the file list
	local sorted_files : list sort csv_files

	// Initialize a list to store tempfiles for each CSV file
	local tempfiles_list

	// Loop through each file, import it, and save it as a tempfile
	local num_files : word count `sorted_files'
	forval i = 1/`num_files' {
		// Create a new tempfile for each CSV file
		tempfile temp`i'
		local tempfiles_list "`tempfiles_list' `temp`i''"

		local this_file : word `i' of `sorted_files'

		quietly {
			// Import the CSV file (try semicolon delimiter first, then comma)
			cap import delimited using "`folder'/`this_file'", clear encoding("utf-8") bindquote(strict) maxquotedrows(unlimited) delimiter(";")
			if _rc != 0 {
				import delimited using "`folder'/`this_file'", clear encoding("utf-8") bindquote(strict) maxquotedrows(unlimited)
			}

			// Save the imported data to the tempfile
			save `temp`i'', replace
		}

	}

	// Clear memory before starting the append process
	quietly {
		clear

		// Use the first tempfile
		local first_tempfile : word 1 of `tempfiles_list'
		use `first_tempfile', clear

		// Loop through the remaining tempfiles and append them
		forval i = 2/`num_files' {
			local next_tempfile : word `i' of `tempfiles_list'
			append using `next_tempfile'
		}

		// Save the final appended result to the specified output file
		export delimited using "`output_file'", replace
	}
end

* -----------------------------------------------------------------------------
* summarize_dataset: Create summary statistics of dataset variables
* -----------------------------------------------------------------------------
program define _al_summarize, rclass
	syntax [, Savefile(string)]

	* Check if a file path is provided for using
	if ("`using'" == "") {
		// display "No dataset provided. Using dataset in memory."
	}
	else {
		* Load the dataset if a file path is provided
		use `"`using'"', clear
	}

	* Create a temporary file to store results
	tempname memhold
	tempfile results
	cap postutil clear
	postfile `memhold' str32 variable str10 type str80 categories min max mean byte is_integer using `results'

	* Loop through all variables
	quietly ds
	foreach var in `r(varlist)' {
		* Determine if the variable is numeric or categorical
		local type "`:type `var''"

		if inlist("`type'", "long", "int", "float", "double", "byte") {
			* Numeric operations
			quietly summarize `var'
			local min = r(min)
			local max = r(max)
			local mean = r(mean)

			* Check if the variable is an integer
			gen double temp_var = round(`var')
			gen is_int = (`var' == temp_var)
			egen is_integer_temp = min(is_int)
			local is_integer = is_integer_temp[1]
			drop temp_var is_int is_integer_temp

			post `memhold' ("`var'") ("`type'") ("") (`min') (`max') (`mean') (`is_integer')

		}
		else if strpos("`type'", "str") {
			* String operations
			quietly levelsof `var', local(levels)
			local values = ""
			local count = 1
			foreach level of local levels {
				local values = "`values' `level'"
				local ++count
				if `count' > 10 {
					break
				}
			}

			post `memhold' ("`var'") ("`type'") ("`values'") (.) (.) (.) (.)

		}
		else {
			error
		}
	}

	* Close post file, which creates the dataset results
	postclose `memhold'

	* Load the results into memory
	use `results', clear

	* Export results to Excel
	if "`savefile'" != "" {
		export excel using "`savefile'", replace firstrow(var)
	}
	else {
		// display "No save file provided. Results are in memory."
	}

end

* -----------------------------------------------------------------------------
* fetch_with_errors: Download file with detailed API error handling
* Returns r(status) = 0 on success, 1 on error
* Returns r(version) and r(schema) if available in response headers
* -----------------------------------------------------------------------------
program define _al_fetch, rclass
	args api_url zip_dest domain type lang version

	* If requesting "latest", get actual version info from API first
	local actual_version = "`version'"
	local schema_version = "1.0"

	if ("`version'" == "latest") {
		* Construct info endpoint URL
		local info_url = subinstr("`api_url'", "/latest", "/latest/info", 1)

		* Get version and schema from API info endpoint (Windows-compatible)
		tempfile json_out
		cap qui shell curl -s "`info_url'" > "`json_out'"

		if (_rc == 0) {
			tempname fh
			cap file open `fh' using "`json_out'", read text
			if (_rc == 0) {
				file read `fh' json_line
				file close `fh'

				* Extract version with Stata's regexm (no grep/cut needed)
				if regexm(`"`json_line'"', `""version"[ ]*:[ ]*"([^"]+)""') {
					local actual_version = regexs(1)
				}

				* Extract schema with Stata's regexm (no grep/cut needed)
				if regexm(`"`json_line'"', `""schema"[ ]*:[ ]*"([^"]+)""') {
					local schema_version = regexs(1)
				}
			}
		}
	}

	* Download the dataset
	cap copy "`api_url'" "`zip_dest'", replace
	local download_rc = _rc

	* Check if download succeeded
	if (`download_rc' == 0 & fileexists("`zip_dest'")) {
		* Success
		return scalar status = 0
		return local version "`actual_version'"
		return local schema "`schema_version'"
		exit 0
	}

	* Download failed - try to get smart error message from API
	di as error ""
	di as error "{hline 60}"
	di as error "Download Failed"
	di as error "{hline 60}"

	* Try to fetch JSON error message from API
	tempfile error_json
	cap qui shell curl -s "`api_url'" > "`error_json'"
	local curl_rc = _rc

	local api_message ""
	local suggestion ""
	local available_options ""

	if (`curl_rc' == 0) {
		* Try to parse JSON error response using file read (more reliable than infix)
		tempname fh
		local json_content ""
		cap file open `fh' using "`error_json'", read
		if (_rc == 0) {
			cap file read `fh' json_content
			file close `fh'

			* Extract "message" field from JSON (simple parsing)
			* Pattern: "message": "Some error message"
			if (regexm(`"`json_content'"', `""message"[[:space:]]*:[[:space:]]*"([^"]+)""')) {
				local api_message = regexs(1)
			}

			* Extract "suggestion" field if present
			if (regexm(`"`json_content'"', `""suggestion"[[:space:]]*:[[:space:]]*"([^"]+)""')) {
				local suggestion = regexs(1)
			}

			* Extract "available_languages" or "available_domains" array if present
			* Pattern: "available_languages": ["eng", "swe"] or "available_domains": ["scb"]
			if (regexm(`"`json_content'"', `""available_languages"[[:space:]]*:[[:space:]]*\[([^\]]+)\]"')) {
				local available_options = regexs(1)
				* Strip quotes from array elements: "eng", "swe" -> eng, swe
				local available_options : subinstr local available_options `"""' "", all
			}
			else if (regexm(`"`json_content'"', `""available_domains"[[:space:]]*:[[:space:]]*\[([^\]]+)\]"')) {
				local available_options = regexs(1)
				* Strip quotes from array elements
				local available_options : subinstr local available_options `"""' "", all
			}
		}
	}

	* Display API smart message if available
	if ("`api_message'" != "") {
		di as error "API Error Message:"
		di as text "  `api_message'"

		if ("`suggestion'" != "") {
			di as error ""
			di as result "Suggestion: Try using '{result:`suggestion'}'"
		}

		if ("`available_options'" != "") {
			di as error ""
			di as text "Available options: `available_options'"
		}
	}
	else {
		* Fallback to generic error messages
		di as error "Request details:"
		di as error "  Domain:   {result:`domain'}"
		di as error "  Type:     {result:`type'}"
		di as error "  Language: {result:`lang'}"
		di as error "  Version:  {result:`version'}"
		di as error ""

		* Check common error scenarios
		if (`download_rc' == 601 | `download_rc' == 630 | `download_rc' == 631) {
			* HTTP error codes
			if ("`version'" != "latest" & !regexm("`version'", "^v[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]$")) {
				di as error "Invalid Version: {result:`version'}"
				di as error ""
				di as error "Version format should be:"
				di as error "  • latest (for most recent version)"
				di as error "  • v20251014 (specific version, format: vYYYYMMDD)"
			}
			else {
				di as error "Dataset not found. Possible reasons:"
				di as error "  1. Invalid domain, type, or language combination"
				di as error "  2. Version {result:`version'} does not exist"
				di as error "  3. API server is down or unreachable"
				di as error ""
				di as error "Note: The API should return available options above."
			}
		}
		else if (`download_rc' == 677 | `download_rc' == 2) {
			* Connection/network error
			di as error "Network Error"
			di as error ""
			di as error "Unable to connect to API server:"
			di as error "  {result:`api_url'}"
			di as error ""
			di as error "Possible reasons:"
			di as error "  1. No internet connection"
			di as error "  2. API server is down"
			di as error "  3. Firewall blocking access"
			di as error "  4. Wrong API host (check dev mode settings)"
		}
		else {
			* Other error
			di as error "Unexpected error (code: `download_rc')"
			di as error "URL: {result:`api_url'}"
		}
	}

	di as error "{hline 60}"
	di as error ""

	return scalar status = 1
	return local version ""
	return local schema ""
end

* -----------------------------------------------------------------------------
* store_dataset_metadata: Store dataset version info in datasets.csv
* Simple CSV append approach - just add/update rows
* -----------------------------------------------------------------------------
program define _al_store_meta
	args autolabel_dir domain type lang ds_version ds_schema csv_file

	* Create dataset key using the filename pattern (value_labels vs values)
	local file_type = cond("`type'" == "values", "value_labels", "`type'")
	local dataset_key "`domain'_`file_type'_`lang'"

	* Get current timestamp (ISO 8601 format)
	local timestamp "`c(current_date)'T`c(current_time)'Z"

	* Get file size using Mata (cross-platform: Windows, Mac, Linux)
	local file_size = 0
	cap confirm file "`csv_file'"
	if (_rc == 0) {
		_rs_utils get_filesize "`csv_file'"
		local file_size = r(size)
	}
	if ("`file_size'" == "" | "`file_size'" == ".") local file_size = 0

	* CSV file location
	local meta_csv "`autolabel_dir'/datasets.csv"

	* Check if CSV exists
	cap confirm file "`meta_csv'"
	if (_rc != 0) {
		* Create new CSV with header (includes explicit domain, type, lang columns)
		* Using semicolon delimiter for consistency with usage_stata.csv
		cap file close metafile
		file open metafile using "`meta_csv'", write replace
		file write metafile "dataset_key;domain;type;lang;version;schema;downloaded;source;file_size;last_checked" _n
		file write metafile "`dataset_key';`domain';`type';`lang';`ds_version';`ds_schema';`timestamp';api;`file_size';" _n
		file close metafile
	}
	else {
		* CSV exists - check if dataset_key already exists
		quietly {
			preserve
			import delimited using "`meta_csv'", clear varnames(1) stringcols(_all) delimiter(";")
			count if dataset_key == "`dataset_key'"
			local key_exists = r(N)

			if (`key_exists' > 0) {
				* Update existing entry
				replace domain = "`domain'" if dataset_key == "`dataset_key'"
				replace type = "`type'" if dataset_key == "`dataset_key'"
				replace lang = "`lang'" if dataset_key == "`dataset_key'"
				replace version = "`ds_version'" if dataset_key == "`dataset_key'"
				replace schema = "`ds_schema'" if dataset_key == "`dataset_key'"
				replace downloaded = "`timestamp'" if dataset_key == "`dataset_key'"
				replace source = "api" if dataset_key == "`dataset_key'"
				replace file_size = "`file_size'" if dataset_key == "`dataset_key'"
				* Don't reset last_checked when re-downloading
				export delimited using "`meta_csv'", replace delimiter(";")
			}
			else {
				* Append new row (includes explicit domain, type, lang columns)
				* Using semicolon delimiter
				restore
				cap file close metafile
				file open metafile using "`meta_csv'", write append
				file write metafile "`dataset_key';`domain';`type';`lang';`ds_version';`ds_schema';`timestamp';api;`file_size';" _n
				file close metafile
				exit 0
			}
			restore
		}
	}
end

* -----------------------------------------------------------------------------
* get_dataset_version: Retrieve stored version info for a dataset from CSV
* Returns r(has_version)=1 if found, r(version), r(schema), r(downloaded), r(file_size), r(last_checked)
* -----------------------------------------------------------------------------
program define _al_get_ver, rclass
	args autolabel_dir domain type lang

	* Create dataset key using the filename pattern (value_labels vs values)
	* Type can be "values" (API format) or "variables"
	* We need to convert "values" → "value_labels" for the key
	local file_type = cond("`type'" == "values", "value_labels", "`type'")
	local dataset_key "`domain'_`file_type'_`lang'"
	* CSV file location (inside autolabel_keys with the datasets)
	local meta_csv "`autolabel_dir'/datasets.csv"

	* Check if CSV file exists
	cap confirm file "`meta_csv'"
	if (_rc != 0) {
		return scalar has_version = 0
		return local version ""
		return local schema ""
		return local downloaded ""
		return local file_size ""
		return local last_checked ""
		exit 0
	}

	* Read CSV with Stata (preserve/restore to avoid corrupting user's dataset)
	quietly {
		preserve
		cap import delimited using "`meta_csv'", clear varnames(1) stringcols(_all) delimiter(";")
		if (_rc == 0) {
			cap keep if dataset_key == "`dataset_key'"
			if (_rc == 0 & _N > 0) {
				* Store values in locals first using proper syntax
				local ver `=version[1]'
				local sch `=schema[1]'
				local dl `=downloaded[1]'
				local src `=source[1]'
				local fs `=file_size[1]'
				* last_checked might not exist in old metadata files
				cap local lc `=last_checked[1]'
				if (_rc != 0) local lc ""

				* Return values
				return scalar has_version = 1
				return local version "`ver'"
				return local schema "`sch'"
				return local downloaded "`dl'"
				return local source "`src'"
				return local file_size "`fs'"
				return local last_checked "`lc'"
				restore
				exit 0
			}
			else {
				restore
				return scalar has_version = 0
				return local version ""
				return local schema ""
				return local downloaded ""
				return local file_size ""
				return local last_checked ""
				exit 0
			}
		}
		else {
			restore
			return scalar has_version = 0
			return local version ""
			return local schema ""
			return local downloaded ""
			return local file_size ""
			return local last_checked ""
			exit 0
		}
	}
end

* -----------------------------------------------------------------------------
* check_dataset_version: Check if dataset exists and has version info
* If no version info found, prompt user to re-download
* Returns r(should_download)=1 if should download, 0 if can proceed
* -----------------------------------------------------------------------------
program define _al_check_ver, rclass
	args registream_dir domain type lang dta_file

	* Check if DTA file exists
	cap confirm file "`dta_file'"
	if (_rc != 0) {
		* File doesn't exist, need to download
		return scalar should_download = 1
		return local reason "file_not_found"
		exit 0
	}

	* File exists, check if we have version info
	_rs_autolabel_utils get_dataset_version "`registream_dir'" "`domain'" "`type'" "`lang'"
	local has_version = r(has_version)

	if (`has_version' == 0) {
		* No version info - could be user-created or legacy v1.0.1 dataset
		* Give WARNING but allow user to continue

		di as text ""
		di as text "{hline 60}"
		di as error "Dataset has no version tracking metadata"
		di as text "{hline 60}"
		di as text "Dataset: {result:`domain'_`type'_`lang'}"
		di as text ""
		di as text "This dataset exists but has no entry in datasets.csv."
		di as text "This could mean:"
		di as text "  • User-created custom metadata file"
		di as text "  • Downloaded with RegiStream v1.0.1 or earlier"
		di as text "  • Manually copied from another location"
		di as text ""
		di as text "Recommendations:"
		di as text "  • For user-defined metadata: Add an entry to datasets.csv"
		di as text "    Location: `registream_dir'/datasets.csv"
		di as text "  • For RegiStream datasets: Re-download to enable version tracking"
		di as text ""
		di as text "Note: The dataset will be validated for Schema 1.0 compatibility."
		di as text "If validation fails, you may need to re-download."
		di as text "{hline 60}"
		di as text ""

		* Don't force re-download, just proceed without version info
		* Schema validation will catch incompatible files later
		return scalar should_download = 0
		return local reason "no_version_info"
		return local version ""
		return local schema ""
		return local downloaded ""
	}
	else {
		* Has version info, all good
		return scalar should_download = 0
		return local reason "version_exists"
		return local version "`r(version)'"
		return local schema "`r(schema)'"
		return local downloaded "`r(downloaded)'"
	}
end

* -----------------------------------------------------------------------------
* check_for_updates: Check API for dataset updates (internet required)
* If dataset not in datasets.csv but exists locally → prompt to re-download
* If dataset in datasets.csv → check for newer version and inform user
* Implements 24-hour caching using last_checked timestamp
* -----------------------------------------------------------------------------
program define _al_check_updates, rclass
	args autolabel_dir domain type lang dta_file

	* Get registream_dir from autolabel_dir (remove /autolabel_keys suffix)
	local registream_dir = substr("`autolabel_dir'", 1, length("`autolabel_dir'") - 15)

	* Check if we have internet access (via config)
	_rs_config get "`registream_dir'" "internet_access"
	local has_internet = r(value)
	local config_found = r(found)

	* Default to enabled if config doesn't exist or value not found
	if (`config_found' == 0 | "`has_internet'" == "") {
		local has_internet "true"
	}

	if ("`has_internet'" != "true" & "`has_internet'" != "1") {
		* No internet, skip check
		return scalar checked = 0
		return local status "no_internet"
		exit 0
	}

	* Check if we should skip API check based on last_checked (24-hour cache)
	_rs_autolabel_utils get_dataset_version "`autolabel_dir'" "`domain'" "`type'" "`lang'"
	local has_version = r(has_version)
	local last_checked = r(last_checked)

	if (`has_version' == 1 & "`last_checked'" != "") {
		* Parse last_checked timestamp (format: YYYY-MM-DDTHH:MM:SSZ)
		local check_date = substr("`last_checked'", 1, 10)
		local check_year = substr("`check_date'", 1, 4)
		local check_month = substr("`check_date'", 6, 2)
		local check_day = substr("`check_date'", 9, 2)

		* Get current date
		local curr_date = "`c(current_date)'"
		local curr_year = substr("`curr_date'", 1, 4)
		local curr_month = substr("`curr_date'", 6, 2)
		local curr_day = substr("`curr_date'", 9, 2)

		* Simple 24-hour check: if same date, skip API check
		* (More sophisticated date math would require complex Julian date calculations)
		if ("`check_year'" == "`curr_year'" & "`check_month'" == "`curr_month'" & "`check_day'" == "`curr_day'") {
			* Checked today already, skip API ping
			return scalar checked = 0
			return local status "cached"
			exit 0
		}
	}

	* Check if DTA file exists locally
	cap confirm file "`dta_file'"
	if (_rc != 0) {
		* File doesn't exist locally, no need to check
		return scalar checked = 0
		return local status "file_not_found"
		exit 0
	}

	* Get local version info from datasets.csv
	_rs_autolabel_utils get_dataset_version "`autolabel_dir'" "`domain'" "`type'" "`lang'"
	local has_version = r(has_version)
	local local_version = r(version)

	* Get API host
	_rs_utils get_api_host
	local api_host "`r(host)'"

	* Construct info endpoint to get latest version
	local info_url "`api_host'/api/v1/datasets/`domain'/`type'/`lang'/latest/info"

	* Try to get version from API (Windows-compatible)
	tempfile json_out
	cap qui shell curl -s -f -m 5 "`info_url'" > "`json_out'"
	local curl_rc = _rc

	* Check if API call succeeded
	if (`curl_rc' != 0) {
		* API unreachable or dataset not on API
		return scalar checked = 1
		return local status "api_error"
		exit 0
	}

	* Read and parse API version
	local api_version = ""
	tempname fh
	cap file open `fh' using "`json_out'", read text
	if (_rc == 0) {
		file read `fh' json_line
		file close `fh'

		* Extract version with Stata's regexm (no grep/cut needed)
		if regexm(`"`json_line'"', `""version"[ ]*:[ ]*"([^"]+)""') {
			local api_version = regexs(1)
		}
	}

	* Case 1: Dataset NOT in datasets.csv but exists locally
	if (`has_version' == 0) {
		if ("`api_version'" != "") {
			* Dataset exists on API - create metadata entry automatically
			di as text ""
			di as result "{hline 60}"
			di as text "Dataset Available on RegiStream"
			di as result "{hline 60}"
			di as text "Dataset: {result:`domain'_`type'_`lang'}"
			di as text "Local:   No version tracking"
			di as text "API:     Version {result:`api_version'} available"
			di as text ""
			di as text "Creating datasets.csv entry with API version info..."
			di as result "{hline 60}"
			di as text ""

			* Get CSV file path to compute file size
			local file_type = cond("`type'" == "values", "value_labels", "`type'")
			local csv_file "`autolabel_dir'/`domain'_`file_type'_`lang'.csv"

			* Store metadata with API version
			_rs_autolabel_utils store_dataset_metadata "`autolabel_dir'" "`domain'" "`type'" "`lang'" "`api_version'" "1.0" "`csv_file'"

			* Update last_checked since we just checked
			_rs_autolabel_utils update_last_checked "`autolabel_dir'" "`domain'" "`type'" "`lang'"

			return scalar checked = 1
			return local status "not_tracked_api_available"
			return local api_version "`api_version'"
		}
		else {
			* Not on API either - create entry with unknown version (user-created)
			local file_type = cond("`type'" == "values", "value_labels", "`type'")
			local csv_file "`autolabel_dir'/`domain'_`file_type'_`lang'.csv"
			_rs_autolabel_utils store_dataset_metadata "`autolabel_dir'" "`domain'" "`type'" "`lang'" "unknown" "1.0" "`csv_file'"

			return scalar checked = 1
			return local status "not_tracked_not_on_api"
		}
		exit 0
	}

	* Update last_checked timestamp since we checked the API
	_rs_autolabel_utils update_last_checked "`autolabel_dir'" "`domain'" "`type'" "`lang'"

	* Case 2: Dataset IS in datasets.csv - check for updates
	if ("`api_version'" != "" & "`api_version'" != "`local_version'") {
		* Newer version available
		di as text ""
		di as result "Update Available"
		di as text "Dataset: {result:`domain'_`type'_`lang'}"
		di as text "Current: {result:`local_version'}"
		di as text "Latest:  {result:`api_version'}"
		di as text "To update: Use 'autolabel update' command or delete local files and re-run"
		di as text ""

		return scalar checked = 1
		return local status "update_available"
		return local local_version "`local_version'"
		return local api_version "`api_version'"
	}
	else {
		* Up to date or same version
		return scalar checked = 1
		return local status "up_to_date"
		return local local_version "`local_version'"
	}
end

* -----------------------------------------------------------------------------
* update_last_checked: Update last_checked timestamp in datasets.csv
* -----------------------------------------------------------------------------
program define _al_update_checked
	args autolabel_dir domain type lang

	* Create dataset key
	local file_type = cond("`type'" == "values", "value_labels", "`type'")
	local dataset_key "`domain'_`file_type'_`lang'"

	* Get current timestamp
	local timestamp "`c(current_date)'T`c(current_time)'Z"

	* CSV file location
	local meta_csv "`autolabel_dir'/datasets.csv"

	* Check if CSV exists
	cap confirm file "`meta_csv'"
	if (_rc != 0) {
		* No metadata file, nothing to update
		exit 0
	}

	* Update last_checked field
	quietly {
		preserve
		cap import delimited using "`meta_csv'", clear varnames(1) stringcols(_all) delimiter(";")
		if (_rc == 0) {
			* Ensure last_checked column exists (for backwards compatibility)
			cap confirm variable last_checked
			if (_rc != 0) {
				gen last_checked = ""
			}

			* Update timestamp for this dataset
			replace last_checked = "`timestamp'" if dataset_key == "`dataset_key'"
			export delimited using "`meta_csv'", replace delimiter(";")
		}
		restore
	}
end

* -----------------------------------------------------------------------------
* verify_file_integrity: Check file existence, metadata, and size
* Returns r(status) = "ok", "missing_file", "missing_metadata", "size_mismatch"
* Returns r(should_download) = 1 if should download, 0 if ok to proceed
* Returns r(download_version) = specific version to download (if user chose one)
* Returns r(user_approved) = 1 if user was prompted and approved download, 0 otherwise
* -----------------------------------------------------------------------------
program define _al_verify_integrity, rclass
	args autolabel_dir domain type lang csv_file dta_file

	* Initialize return values
	return clear
	return local status "ok"
	return scalar should_download = 0
	return scalar user_approved = 0

	* Create dataset key
	local file_type = cond("`type'" == "values", "value_labels", "`type'")
	local dataset_key "`domain'_`file_type'_`lang'"

	* Check if we have internet access (for API version checking)
	local registream_dir = substr("`autolabel_dir'", 1, length("`autolabel_dir'") - 15)
	_rs_config get "`registream_dir'" "internet_access"
	local has_internet = r(value)
	local config_found = r(found)

	* Default to enabled if config doesn't exist or value not found
	if (`config_found' == 0 | "`has_internet'" == "") {
		local has_internet "true"
	}

	local can_ping_api = ("`has_internet'" == "true" | "`has_internet'" == "1")

	* Check if CSV file exists
	cap confirm file "`csv_file'"
	local csv_exists = (_rc == 0)

	* Check if DTA file exists
	cap confirm file "`dta_file'"
	local dta_exists = (_rc == 0)

	* Get metadata info
	_rs_autolabel_utils get_dataset_version "`autolabel_dir'" "`domain'" "`type'" "`lang'"
	local has_metadata = r(has_version)
	local stored_size = r(file_size)
	local stored_version = r(version)
	local stored_source = r(source)

	* Case 1: Files missing but have metadata
	if (!`csv_exists' | !`dta_exists') {
		if (`has_metadata' == 1) {
			* Files were downloaded before but now missing
			* Try to get latest version from API (only if we have internet access)
			if (`can_ping_api') {
				_rs_autolabel_utils get_latest_version_from_api "`domain'" "`type'" "`lang'"
				local api_available = r(available)
				local api_version = r(version)
			}
			else {
				* Offline mode - skip API check
				local api_available = 0
				local api_version = ""
			}

			di as text ""
			di as error "{hline 60}"
			di as error "Dataset Files Missing"
			di as error "{hline 60}"
			di as text "Dataset: {result:`dataset_key'}"
			di as text ""
			di as text "Metadata indicates this dataset was previously downloaded,"
			di as text "but the files are missing. This may indicate:"
			di as text "  • Files were manually deleted"
			di as text "  • Disk cleanup or migration"
			di as text "  • Corruption or permission issues"
			di as text ""
			di as text "Your previous version: {result:`stored_version'}"

			if (`api_available' == 1) {
				di as text "Latest API version:    {result:`api_version'}"
				di as text ""

				* Offer choice between latest and previous version
				if ("`api_version'" != "`stored_version'") {
					di as text "A newer version is available!"
					di as text ""

					_rs_utils prompt_choice "Which version do you want to download?" "Latest version (`api_version')" "Your previous version (`stored_version')"
					local choice = r(choice)

					if ("`choice'" == "1") {
						local download_version "`api_version'"
						di as text ""
						di as text "Will download latest version: {result:`api_version'}"
					}
					else {
						local download_version "`stored_version'"
						di as text ""
						di as text "Will download your previous version: {result:`stored_version'}"
					}
				}
				else {
					* Same version - just confirm download
					_rs_utils prompt "Re-download dataset (version `stored_version')?"
					local download_version "`stored_version'"
				}
			}
			else {
				* Offline - can only offer to re-download their previous version
				di as text "Latest API version:    {error:unavailable (offline or no connection)}"
				di as text ""
				di as text "You can re-download your previous version (`stored_version')"
				di as text ""

				_rs_utils prompt "Re-download your previous version (`stored_version')?"
				local download_version "`stored_version'"
			}

			* User approved - proceed with download
			di as text "{hline 60}"
			di as text ""
			return local status "missing_file"
			return scalar should_download = 1
			return scalar user_approved = 1
			return local download_version "`download_version'"
			exit 0
		}
		else {
			* No metadata either - normal download flow (no prompt needed)
			return local status "missing_file"
			return scalar should_download = 1
			return scalar user_approved = 0
			exit 0
		}
	}

	* Case 2: Files exist but no metadata
	if (`csv_exists' & `dta_exists' & `has_metadata' == 0) {
		* Try to get latest version from API (only if we have internet access)
		if (`can_ping_api') {
			_rs_autolabel_utils get_latest_version_from_api "`domain'" "`type'" "`lang'"
			local api_available = r(available)
			local api_version = r(version)
		}
		else {
			* Offline mode - skip API check
			local api_available = 0
			local api_version = ""
		}

		di as text ""
		di as result "{hline 60}"
		di as text "Dataset Exists Without Metadata"
		di as result "{hline 60}"
		di as text "Dataset: {result:`dataset_key'}"
		di as text ""
		di as text "Files exist locally but have no entry in datasets.csv."
		di as text "This could indicate:"
		di as text "  • Downloaded with RegiStream v1.0.1 or earlier (simple upgrade needed)"
		di as text "  • User-created custom metadata (requires manual configuration)"
		di as text "  • Manually copied from another location"
		di as text ""

		if (`api_available' == 1) {
			di as text "Latest API version: {result:`api_version'}"
			di as text ""
			di as text "To enable version tracking and integrity checks, re-download from API."
			di as text ""
			di as text "If this is custom metadata, configure datasets.csv with source='user'"
			di as text "before running this command. See: https://registream.org/docs/custom-datasets"
		}
		else {
			di as text "Latest API version: {error:unavailable (offline or no connection)}"
			di as text ""
			di as text "To enable version tracking and integrity checks, re-download from API when online."
			di as text ""
			di as text "If this is custom metadata, configure datasets.csv with source='user'"
			di as text "before running this command. See: https://registream.org/docs/custom-datasets"
		}

		di as text ""

		_rs_autolabel_utils prompt_user "Re-download dataset from API to enable version tracking?"
		* User approved (exits on "no")

		di as text "{hline 60}"
		di as text ""
		return local status "missing_metadata"
		return scalar should_download = 1
		return scalar user_approved = 1
		exit 0
	}

	* Case 3: Check file size if we have metadata AND source is "api"
	* Skip size check for user-created datasets (source != "api")
	if (`csv_exists' & `has_metadata' == 1 & "`stored_size'" != "" & "`stored_size'" != "0") {

		* Only check size if source is "api" - suppress warnings for user datasets
		if ("`stored_source'" == "api" | "`stored_source'" == "") {
			* Get actual file size using Mata (cross-platform)
			_rs_utils get_filesize "`csv_file'"
			local actual_size = r(size)
			if ("`actual_size'" == "" | "`actual_size'" == ".") local actual_size = 0

				* Compare sizes (allow small differences due to line endings)
				if ("`actual_size'" != "" & "`actual_size'" != ".") {
					local size_diff = abs(`actual_size' - `stored_size')
					local size_pct = (`size_diff' / `stored_size') * 100

					* If size difference > 5%, warn user
					if (`size_pct' > 5) {
						di as text ""
						di as error "{hline 60}"
						di as error "File Size Mismatch Detected"
						di as error "{hline 60}"
						di as text "Dataset: {result:`dataset_key'}"
						di as text "Expected size: {result:`stored_size'} bytes"
						di as text "Actual size:   {result:`actual_size'} bytes"
						di as text "Difference:    {result:" %4.1f `size_pct' "%}"
						di as text ""
						di as text "This may indicate:"
						di as text "  • File corruption"
						di as text "  • Manual modification"
						di as text "  • Incomplete download"
						di as text ""
						di as text "Re-download to ensure file integrity."
						di as text "(Saying 'no' will abort the command)"
						di as text ""
						di as text "Tip: To suppress this warning for custom datasets,"
						di as text "     set source='user' in datasets.csv"
						di as text "     Location: {result:`autolabel_dir'/datasets.csv}"
						di as text ""

						_rs_autolabel_utils prompt_user "Re-download dataset to ensure file integrity?"
						* User approved (exits on "no")

						di as text "{hline 60}"
						di as text ""
						return local status "size_mismatch"
						return scalar should_download = 1
						return scalar user_approved = 1
						exit 0
					}
				}
			}
		* else: source is "user" or other non-api value - skip size check entirely
	}

	* All checks passed
	return local status "ok"
	return scalar should_download = 0
end

* -----------------------------------------------------------------------------
* get_latest_version_from_api: Get latest version from API without downloading
* Uses /api/v1/datasets/{domain}/{type}/{lang}/latest/info endpoint
* Returns r(version), r(schema), r(available) = 1 if API reachable, 0 otherwise
*
* Windows-compatible: Uses file read + regexm() instead of shell pipes
* Batch-mode reliable: Checks file existence rather than trusting _rc
* -----------------------------------------------------------------------------
program define _al_get_latest_version, rclass
	args domain type lang

	* Use production API host directly
	* (Avoids dev override check which causes batch mode issues)
	local api_host "https://registream.org"

	* Construct info endpoint
	local info_url "`api_host'/api/v1/datasets/`domain'/`type'/`lang'/latest/info"

	* Try to get version info from API (use curl, parse with Stata - Windows compatible)
	tempfile json_out
	cap qui shell curl -s -f -m 5 "`info_url'" > "`json_out'"
	local curl_rc = _rc

	if (`curl_rc' == 0) {
		* Read and parse JSON response (Windows-compatible, no grep/cut needed)
		local api_version = ""
		local api_schema = ""

		* Use file read to get JSON content
		tempname fh
		cap file open `fh' using "`json_out'", read text
		if (_rc == 0) {
			file read `fh' json_line
			local read_rc = _rc
			file close `fh'

			if (`read_rc' == 0) {
				* Extract version: look for "version":"..." or "version": "..."
				if regexm(`"`json_line'"', `""version"[ ]*:[ ]*"([^"]+)""') {
					local api_version = regexs(1)
				}

				* Extract schema: look for "schema":"..." or "schema": "..."
				if regexm(`"`json_line'"', `""schema"[ ]*:[ ]*"([^"]+)""') {
					local api_schema = regexs(1)
				}
			}
		}

		if ("`api_version'" != "") {
			return scalar available = 1
			return local version "`api_version'"
			return local schema "`api_schema'"
			exit 0
		}
	}

	* API not reachable or dataset not found
	return scalar available = 0
	return local version ""
	return local schema ""
end

* -----------------------------------------------------------------------------
* validate_domain_language: Validate domain and language locally (offline mode)
* Scans datasets.csv to discover available domains and languages dynamically
* Returns r(domain_valid) = 1 if domain is valid, 0 otherwise
* Returns r(lang_valid) = 1 if language is valid, 0 otherwise
* Returns r(available_domains) = list of known domains
* Returns r(available_languages) = list of known languages for the domain
* -----------------------------------------------------------------------------
program define _al_validate_local, rclass
	args autolabel_dir domain lang

	local meta_csv "`autolabel_dir'/datasets.csv"

	* Check if datasets.csv exists
	cap confirm file "`meta_csv'"
	if (_rc != 0) {
		* No datasets.csv - can't validate from local data
		return scalar domain_valid = 0
		return scalar lang_valid = 0
		return local available_domains ""
		return local available_languages ""
		exit 0
	}

	* Scan datasets.csv to discover domains and languages
	quietly {
		preserve
		cap import delimited using "`meta_csv'", clear varnames(1) stringcols(_all) delimiter(";")

		if (_rc == 0) {
			* Get unique domains
			cap levelsof domain, local(all_domains) clean
			if (_rc != 0) local all_domains ""

			* Check if requested domain exists
			cap count if domain == "`domain'"
			local domain_valid = (r(N) > 0)

			* Get languages for this domain
			cap levelsof lang if domain == "`domain'", local(domain_langs) clean
			if (_rc != 0) local domain_langs ""

			* Check if requested language exists for this domain
			cap count if domain == "`domain'" & lang == "`lang'"
			local lang_valid = (r(N) > 0)
		}
		else {
			* Failed to read CSV
			local all_domains ""
			local domain_langs ""
			local domain_valid = 0
			local lang_valid = 0
		}

		restore
	}

	return scalar domain_valid = `domain_valid'
	return scalar lang_valid = `lang_valid'
	return local available_domains "`all_domains'"
	return local available_languages "`domain_langs'"
end
