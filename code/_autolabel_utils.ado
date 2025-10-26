* =============================================================================
* Autolabel Utility Functions
* Consolidated helper functions for the autolabel command
* =============================================================================

cap program drop _autolabel_utils
cap program drop _al_get_dir
cap program drop _al_confirmdir
cap program drop _al_escape_ascii
cap program drop _al_del_folder_rec
cap program drop _al_prompt
cap program drop _al_prompt_choice
cap program drop _al_download_extract
cap program drop _al_append_csv
cap program drop _al_summarize
cap program drop _al_fetch

program define _autolabel_utils, rclass
	version 16.0

	gettoken subcmd 0 : 0, parse(" ,")

	if ("`subcmd'" == "get_dir") {
		_al_get_dir `0'
		return add
	}
	else if ("`subcmd'" == "confirmdir") {
		_al_confirmdir `0'
		return add
	}
	else if ("`subcmd'" == "escape_ascii") {
		_al_escape_ascii `0'
		return add
	}
	else if ("`subcmd'" == "del_folder_rec") {
		_al_del_folder_rec `0'
	}
	else if ("`subcmd'" == "prompt") {
		_al_prompt `0'
		return add
	}
	else if ("`subcmd'" == "prompt_choice") {
		_al_prompt_choice `0'
		return add
	}
	else if ("`subcmd'" == "download_extract") {
		_al_download_extract `0'
		return add
	}
	else if ("`subcmd'" == "append_csv") {
		_al_append_csv `0'
	}
	else if ("`subcmd'" == "summarize_dataset") {
		_al_summarize `0'
		return add
	}
	else if ("`subcmd'" == "fetch") {
		_al_fetch `0'
		return add
	}
	else {
		di as error "Invalid _autolabel_utils subcommand: `subcmd'"
		exit 198
	}
end

* -----------------------------------------------------------------------------
* get_dir: Get autolabel directory path
* Returns r(dir) with the registream directory path (keeping .registream name)
* -----------------------------------------------------------------------------
program define _al_get_dir, rclass
	* Check if we have $registream_dir override
	if "$registream_dir" != "" {
		return local dir "$registream_dir"
		exit 0
	}

	* Detect the operating system and set the path
	local os = c(os)
	local machine = c(machine_type)
	local username = c(username)

	* Check for Mac first (handles both interactive "MacOSX" and batch mode "Unix" with Macintosh machine)
	if strpos("`machine'", "Macintosh") > 0 | "`os'" == "MacOSX" {
		local homedir "/Users/`username'"
		local registream_dir "`homedir'/.registream"
	}
	else if "`os'" == "Windows" {
		local homedir "C:/Users/`username'"
		local registream_dir "`homedir'/AppData/Local/registream"
	}
	else if "`os'" == "Unix" {
		* Linux (Unix but not Macintosh)
		local homedir "/home/`username'"
		local registream_dir "`homedir'/.registream"
	}
	else {
		di as error "Cannot determine directory for OS: `os', machine: `machine'"
		exit 1
	}

	return local dir "`registream_dir'"
end

* -----------------------------------------------------------------------------
* confirmdir: Check if a directory exists
* Returns r(exists) = 1 if directory exists, 0 otherwise
* -----------------------------------------------------------------------------
program define _al_confirmdir, rclass
	syntax anything(name=arguments)

	* Extract the first word from namelist (should be the directory path)
	local check_path : word 1 of `arguments'
	local syntax_check : subinstr local arguments "`check_path'" "", all

	* Check if more than one argument was passed
	if "`syntax_check'" != "" {
		di as error "Invalid syntax: pass just one argument, i.e., the filepath."
		exit 198
	}

	local original_dir "`c(pwd)'"

	* Try to change the directory to see if the path exists
	cap cd "`check_path'"

	* Set return value based on the success of changing the directory
	if (_rc == 0) {
		* Directory exists
		qui cd "`original_dir'"
		return scalar exists = 1
	}
	else {
		* Directory does not exist
		return scalar exists = 0
	}
end

* -----------------------------------------------------------------------------
* escape_ascii: Escape special characters in strings
* Returns r(escaped_string) with escaped string
* -----------------------------------------------------------------------------
program define _al_escape_ascii, rclass
	args input_string

	* Escape special characters by replacing them with q followed by ASCII code
	local escaped = "`input_string'"
	local escaped = subinstr("`escaped'", ".", "q46", .)
	local escaped = subinstr("`escaped'", "*", "q42", .)
	local escaped = subinstr("`escaped'", "/", "q47", .)
	local escaped = subinstr("`escaped'", "&", "q38", .)
	local escaped = subinstr("`escaped'", "-", "q45", .)
	local escaped = subinstr("`escaped'", "_", "q95", .)
	local escaped = subinstr("`escaped'", "[", "q91", .)
	local escaped = subinstr("`escaped'", "]", "q93", .)
	local escaped = subinstr("`escaped'", "{", "q123", .)
	local escaped = subinstr("`escaped'", "}", "q125", .)
	local escaped = subinstr("`escaped'", " ", "q32", .)

	* Return the escaped string
	return local escaped_string "`escaped'"
end

* -----------------------------------------------------------------------------
* del_folder_rec: Recursively delete a folder and its contents
* -----------------------------------------------------------------------------
program _al_del_folder_rec
	args folder

	* List all files in the current directory
	local files : dir "`folder'" files "*"

	* Delete all files in the directory
	foreach file in `files' {
		erase "`folder'/`file'"
	}

	* List all subdirectories
	local subdirs : dir "`folder'" dirs "*"

	* Recursively call the program to delete files and subdirectories
	foreach subdir in `subdirs' {
		_autolabel_utils del_folder_rec "`folder'/`subdir'"
	}

	* Delete the directory once all contents are removed
	rmdir "`folder'"
end

* -----------------------------------------------------------------------------
* prompt: Display interactive user prompt
* Returns r(response) = "yes" or "no"
* -----------------------------------------------------------------------------
program define _al_prompt, rclass
	args prompt_message

	* Display prompt and wait for user input
	di as text ""
	di as result "`prompt_message'"
	di as text "Type 'yes' or 'no': " _request(user_response)

	* Normalize response (trim whitespace and convert to lowercase)
	local response = lower(trim("$user_response"))

	* Validate response
	if ("`response'" != "yes" & "`response'" != "no") {
		di as error "Invalid response. Please type 'yes' or 'no'."
		di as text ""

		* Retry prompt
		_autolabel_utils prompt "`prompt_message'"
		return add
		exit 0
	}

	* User declined - exit with error
	if ("`response'" == "no") {
		di as error ""
		di as error "Operation cancelled by user."
		di as error ""
		exit 1
	}

	* User approved - return successfully
	return local response "yes"
end

* -----------------------------------------------------------------------------
* prompt_choice: Display numbered choice prompt
* Returns r(choice) = choice number (1, 2, 3, etc.)
* Automatically appends "Abort" as the last option (exits with error if selected)
* -----------------------------------------------------------------------------
program define _al_prompt_choice, rclass
	* First argument is the message, rest are choices
	gettoken message 0 : 0

	* Parse choices
	local num_choices 0
	while (`"`0'"' != "") {
		gettoken choice 0 : 0
		local ++num_choices
		local choice_`num_choices' `"`choice'"'
	}

	* Always add "Abort" as the last option
	local ++num_choices
	local choice_`num_choices' "Abort"
	local abort_option = `num_choices'

	* Display prompt
	di as text ""
	di as result "`message'"
	di as text ""
	forvalues i = 1/`num_choices' {
		di as text "  [`i'] `choice_`i''"
	}
	di as text ""
	di as text "Enter choice (1-`num_choices'): " _request(user_choice)

	* Validate choice
	local choice = lower(trim("$user_choice"))

	* Check if numeric
	cap confirm number `choice'
	if (_rc != 0) {
		di as error "Invalid choice. Please enter a number between 1 and `num_choices'."
		di as text ""

		* Rebuild argument list and retry (exclude abort option)
		local args `"`message'"'
		local original_choices = `num_choices' - 1
		forvalues i = 1/`original_choices' {
			local args `"`args' "`choice_`i''""'
		}
		_autolabel_utils prompt_choice `args'
		return add
		exit 0
	}

	* Check if in range
	if (`choice' < 1 | `choice' > `num_choices') {
		di as error "Invalid choice. Please enter a number between 1 and `num_choices'."
		di as text ""

		* Rebuild argument list and retry (exclude abort option)
		local args `"`message'"'
		local original_choices = `num_choices' - 1
		forvalues i = 1/`original_choices' {
			local args `"`args' "`choice_`i''""'
		}
		_autolabel_utils prompt_choice `args'
		return add
		exit 0
	}

	* Check if user selected Abort option
	if (`choice' == `abort_option') {
		di as error ""
		di as error "Operation aborted by user."
		di as error ""
		exit 1
	}

	return local choice "`choice'"
end

* -----------------------------------------------------------------------------
* download_extract: Download and extract metadata files (SIMPLIFIED)
* No version tracking, no datasets.csv, no integrity checking
* Just: file missing? → download → extract → done
* -----------------------------------------------------------------------------
program define _al_download_extract, rclass
	syntax , zip(string) zipfold(string) csv(string) dta(string) file(string) autolabel_dir(string) clean(string)

	* Ensure that the CSV file exists
	if (fileexists("`csv'") == 0) {

		* MONA CHECK: if no csv, but constituent folder exists, proceed to build
		_autolabel_utils confirmdir "`zipfold'"
		if (r(exists) == 1) {
			* Folder exists - skip download, proceed to build from constituent CSVs
		}
		else {
			* Need to download - prompt user
			di as text ""
			di as text "Dataset file does not exist: {result:`file'.csv}"
			di as text ""

			_autolabel_utils prompt "Download dataset from https://registream.org?"
			* If we reach here, user approved (prompt exits on "no")

			* Hardcoded API host for production
			local api_host "https://registream.org"

			* Parse filename to extract domain, type, and language
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

			* Construct API v1 endpoint: /api/v1/datasets/{domain}/{type}/{lang}/latest
			local api_url "`api_host'/api/v1/datasets/`domain'/`type'/`lang'/latest"

			di as text ""
			di as text "{hline 60}"
			di as text "Downloading from registream.org"
			di as text "{hline 60}"
			di as text "  Domain:   {result:`domain'}"
			di as text "  Type:     {result:`type'}"
			di as text "  Language: {result:`lang'}"
			di as text "  URL:      {result:`api_url'}"
			di as text "{hline 60}"

			* Download with error handling
			_autolabel_utils fetch "`api_url'" "`zip'" "`domain'" "`type'" "`lang'"

			* Check if download succeeded
			local fetch_status = r(status)

			if (`fetch_status' != 0) {
				* Error already displayed by fetch
				exit 1
			}

			* Display success message
			di as text ""
			di as result "Download successful!"
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
			_autolabel_utils confirmdir "`zipfold'"
			if (r(exists) == 0) {
				di as error "ERROR: Unzip succeeded but folder not found: `zipfold'"
				exit 1
			}
		}

		* Append the constituent csv files (only if folder exists from download)
		_autolabel_utils confirmdir "`zipfold'"
		if (r(exists) == 1) {
			preserve
			_autolabel_utils append_csv "`zipfold'" "`csv'"
			restore
		}

		if (fileexists(trim("`csv'")) == 0) {
			di as error "Error: CSV file not created. Contact developers."
			exit 1
		}
	}

	* Since the CSV file exists, remove the constituent folder and zipfile
	if (fileexists("`csv'") == 1) {
		cap _autolabel_utils del_folder_rec "`zipfold'"
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

	return scalar status = 0
end

* -----------------------------------------------------------------------------
* append_csv: Append multiple CSV files into one
* -----------------------------------------------------------------------------
program define _al_append_csv
	args folder output_file

	* List all CSV files in the directory
	local csv_files : dir "`folder'" files "*.csv"

	* For zero-padded files like _0000.csv, _0001.csv, etc.
	* Lexicographic sorting works correctly, so just sort the file list
	local sorted_files : list sort csv_files

	* Initialize a list to store tempfiles for each CSV file
	local tempfiles_list

	* Loop through each file, import it, and save it as a tempfile
	local num_files : word count `sorted_files'
	forval i = 1/`num_files' {
		* Create a new tempfile for each CSV file
		tempfile temp`i'
		local tempfiles_list "`tempfiles_list' `temp`i''"

		local this_file : word `i' of `sorted_files'

		quietly {
			* Import the CSV file (try semicolon delimiter first, then comma)
			cap import delimited using "`folder'/`this_file'", clear encoding("utf-8") bindquote(strict) maxquotedrows(unlimited) delimiter(";")
			if _rc != 0 {
				import delimited using "`folder'/`this_file'", clear encoding("utf-8") bindquote(strict) maxquotedrows(unlimited)
			}

			* Save the imported data to the tempfile
			save `temp`i'', replace
		}
	}

	* Clear memory before starting the append process
	quietly {
		clear

		* Use the first tempfile
		local first_tempfile : word 1 of `tempfiles_list'
		use `first_tempfile', clear

		* Loop through the remaining tempfiles and append them
		forval i = 2/`num_files' {
			local next_tempfile : word `i' of `tempfiles_list'
			append using `next_tempfile'
		}

		* Save the final appended result to the specified output file
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
		* No dataset provided - use dataset in memory
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

end

* -----------------------------------------------------------------------------
* fetch: Download file with detailed API error handling
* Returns r(status) = 0 on success, 1 on error
* -----------------------------------------------------------------------------
program define _al_fetch, rclass
	args api_url zip_dest domain type lang

	* Download the dataset
	cap copy "`api_url'" "`zip_dest'", replace
	local download_rc = _rc

	* Check if download succeeded
	if (`download_rc' == 0 & fileexists("`zip_dest'")) {
		* Success
		return scalar status = 0
		exit 0
	}

	* Download failed - show error
	di as error ""
	di as error "{hline 60}"
	di as error "Download Failed"
	di as error "{hline 60}"
	di as error "Request details:"
	di as error "  Domain:   {result:`domain'}"
	di as error "  Type:     {result:`type'}"
	di as error "  Language: {result:`lang'}"
	di as error ""

	* Check common error scenarios
	if (`download_rc' == 601 | `download_rc' == 630 | `download_rc' == 631) {
		* HTTP error codes
		di as error "Dataset not found. Possible reasons:"
		di as error "  1. Invalid domain, type, or language combination"
		di as error "  2. API server is down or unreachable"
		di as error ""
		di as error "For assistance, visit: https://registream.org"
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
	}
	else {
		* Other error
		di as error "Unexpected error (code: `download_rc')"
		di as error "URL: {result:`api_url'}"
	}

	di as error "{hline 60}"
	di as error ""

	return scalar status = 1
end
