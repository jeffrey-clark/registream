* =============================================================================
* RegiStream Utility Functions
* Shared helper functions used across all RegiStream modules
* Usage: _rs_utils subcommand [args]
* =============================================================================

cap program drop _rs_utils
program define _rs_utils, rclass
	version 16.0

	gettoken subcmd 0 : 0, parse(" ,")

	if ("`subcmd'" == "get_dir") {
		_utils_get_dir `0'
		return add
	}
	else if ("`subcmd'" == "confirmdir") {
		_utils_confirmdir `0'
		return add
	}
	else if ("`subcmd'" == "escape_ascii") {
		_utils_escape_ascii `0'
		return add
	}
	else if ("`subcmd'" == "del_folder_rec") {
		_utils_del_folder_rec `0'
	}
	else if ("`subcmd'" == "get_api_host") {
		_utils_get_api_host `0'
		return add
	}
	else if ("`subcmd'" == "prompt") {
		_utils_prompt `0'
		return add
	}
	else if ("`subcmd'" == "prompt_choice") {
		_utils_prompt_choice `0'
		return add
	}
	else if ("`subcmd'" == "get_version") {
		_utils_get_version `0'
		return add
	}
	else if ("`subcmd'" == "get_filesize") {
		_utils_get_filesize `0'
		return add
	}
	else {
		di as error "Invalid _rs_utils subcommand: `subcmd'"
		exit 198
	}
end

* -----------------------------------------------------------------------------
* get_dir: Get RegiStream directory path
* Returns r(dir) with the registream directory path
* -----------------------------------------------------------------------------
cap program drop _utils_get_dir
program define _utils_get_dir, rclass
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
		di as error "Cannot determine RegiStream directory for OS: `os', machine: `machine'"
		exit 1
	}

	return local dir "`registream_dir'"
end

* -----------------------------------------------------------------------------
* confirmdir: Check if a directory exists
* Returns r(exists) = 1 if directory exists, 0 otherwise
* -----------------------------------------------------------------------------
cap program drop _utils_confirmdir
program define _utils_confirmdir, rclass
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
cap program drop _utils_escape_ascii
program define _utils_escape_ascii, rclass
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
cap program drop _utils_del_folder_rec
program _utils_del_folder_rec
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
		_rs_utils del_folder_rec "`folder'/`subdir'"
	}

	* Delete the directory once all contents are removed
	rmdir "`folder'"
end

* -----------------------------------------------------------------------------
* get_api_host: Get API host (with development override support)
* Returns r(host) with the API host URL
* -----------------------------------------------------------------------------
* Priority (highest to lowest):
*   1. Dev mode: _rs_dev_utils get_host (defined in _rs_dev_utils.ado)
*   2. Production: https://registream.org (hardcoded)
* -----------------------------------------------------------------------------
cap program drop _utils_get_api_host
program define _utils_get_api_host, rclass
	* Try dev override (only exists if _rs_dev_utils.ado is in adopath)
	cap qui _rs_dev_utils get_host
	if (_rc == 0) {
		* Dev override exists - return its value
		return local host "`r(host)'"
	}
	else {
		* Production: HARDCODED value (ONE location)
		return local host "https://registream.org"
	}
end

* -----------------------------------------------------------------------------
* prompt: Display interactive user prompt
* Returns r(response) = "yes" or "no" (or choice number for multi-choice)
*
* Auto-loads developer config (_rs_dev_config.ado) which can override this
* function for batch mode testing/development workflows.
*
* Usage:
*   _rs_utils prompt "Download dataset from API?"
*   local response = r(response)
* -----------------------------------------------------------------------------
cap program drop _utils_prompt
program define _utils_prompt, rclass
	args prompt_message

	* Auto-load dev config if it exists (only once per session)
	if ("$_RS_DEV_CONFIG_LOADED" != "yes") {
		local dev_file "stata/src/_rs_dev_config.ado"
		cap confirm file "`dev_file'"
		if (_rc == 0) {
			qui do "`dev_file'"
			global _RS_DEV_CONFIG_LOADED "yes"
		}
	}

	* Check if auto-approve is enabled (dev mode or test mode)
	if ("$REGISTREAM_AUTO_APPROVE" == "yes") {
		di as text "`prompt_message' [AUTO-APPROVED]"
		return local response "yes"
		exit 0
	}

	* Display prompt and wait for user input
	di as text ""
	di as result "`prompt_message'"
	di as text "Type 'yes' or 'no': " _request(user_response)

	* Normalize response (trim whitespace and convert to lowercase)
	local response = lower(trim("$user_response"))

	* Check for exit/quit commands (undocumented escape hatch)
	if ("`response'" == "exit" | "`response'" == "quit" | "`response'" == "q") {
		di as error ""
		di as error "Program terminated by user."
		di as error ""
		exit 1
	}

	* Validate response
	if ("`response'" != "yes" & "`response'" != "no") {
		di as error "Invalid response. Please type 'yes' or 'no'."
		di as text ""

		* Retry prompt
		_rs_utils prompt "`prompt_message'"
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
*
* Auto-loads developer config which can override for batch mode (returns "1")
* Automatically appends "Abort" as the last option (exits with error if selected)
*
* Usage:
*   _rs_utils prompt_choice "What to do?" "Continue" "Re-download"
*   local choice = r(choice)
*
* Will display:
*   [1] Continue
*   [2] Re-download
*   [3] Abort
* -----------------------------------------------------------------------------
cap program drop _utils_prompt_choice
program define _utils_prompt_choice, rclass
	* First argument is the message, rest are choices
	gettoken message 0 : 0

	* Auto-load dev config if it exists (only once per session)
	if ("$_RS_DEV_CONFIG_LOADED" != "yes") {
		local dev_file "stata/src/_rs_dev_config.ado"
		cap confirm file "`dev_file'"
		if (_rc == 0) {
			qui do "`dev_file'"
			global _RS_DEV_CONFIG_LOADED "yes"
		}
	}

	* Check if auto-approve is enabled (dev mode or test mode)
	if ("$REGISTREAM_AUTO_APPROVE" == "yes") {
		di as text "`message' [AUTO-APPROVED: choice 1 selected]"
		return local choice "1"
		exit 0
	}

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

	* Check for exit/quit commands (undocumented escape hatch)
	if ("`choice'" == "exit" | "`choice'" == "quit" | "`choice'" == "q") {
		di as error ""
		di as error "Program terminated by user."
		di as error ""
		exit 1
	}

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
		_rs_utils prompt_choice `args'
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
		_rs_utils prompt_choice `args'
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
* get_version: Get RegiStream version
* Returns r(version) with the current version
* -----------------------------------------------------------------------------
* This helper function returns the current version of RegiStream.
*
* Priority (highest to lowest):
*   1. Dev mode: _rs_dev_utils get_version (defined in _rs_dev_utils.ado)
*   2. Production: {{VERSION}} (hardcoded, replaced during package export)
* -----------------------------------------------------------------------------
cap program drop _utils_get_version
program define _utils_get_version, rclass
	* Try dev override (only exists if _rs_dev_utils.ado is in adopath)
	cap qui _rs_dev_utils get_version
	if (_rc == 0) {
		* Dev override exists - return its value
		return local version "`r(version)'"
	}
	else {
		* Production: HARDCODED value (ONE location)
		return local version "{{VERSION}}"
	}
end

* -----------------------------------------------------------------------------
* get_filesize: Get file size in bytes (cross-platform)
* Returns r(size) with the file size in bytes, or 0 if file doesn't exist
* -----------------------------------------------------------------------------
* Uses Mata file I/O (fopen, fseek, ftell) which works on:
*   - Windows Server / Windows PC
*   - macOS
*   - Linux
*
* Usage:
*   _rs_utils get_filesize "/path/to/file.csv"
*   local size = r(size)
* -----------------------------------------------------------------------------
cap program drop _utils_get_filesize
program define _utils_get_filesize, rclass
	args filepath

	quietly {
		mata: st_local("size_result", strofreal(_rs_get_filesize_mata(st_local("filepath"))))
	}

	return scalar size = `size_result'
end

* Define Mata function for file size
mata:
real scalar _rs_get_filesize_mata(string scalar filepath)
{
	real scalar fh, size, ch
	string scalar line

	fh = _fopen(filepath, "r")
	if (fh < 0) {
		return(0)
	}

	// Count bytes by reading file
	size = 0
	while ((line = fget(fh)) != J(0,0,"")) {
		size = size + strlen(line) + 1  // +1 for newline
	}

	fclose(fh)

	return(size)
}
end
