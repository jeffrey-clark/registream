cap program drop _rs_config
cap program drop _config_path
cap program drop _config_init
cap program drop _config_get
cap program drop _config_set

program define _rs_config, rclass
	version 16.0
	* YAML config file management for RegiStream

	gettoken subcmd 0 : 0

	if ("`subcmd'" == "init") {
		_config_init `0'
		return add
	}
	else if ("`subcmd'" == "get") {
		_config_get `0'
		return add
	}
	else if ("`subcmd'" == "set") {
		_config_set `0'
		return add
	}
	else if ("`subcmd'" == "path") {
		_config_path `0'
		return add
	}
	else {
		di as error "Invalid _rs_config subcommand: `subcmd'"
		exit 198
	}
end

* Get config file path
program define _config_path, rclass
	args dir

	local config_file "`dir'/config.yaml"
	return clear
	return local config_file "`config_file'"
end

* Initialize config.yaml if it doesn't exist
program define _config_init, rclass
	args dir

	local config_file "`dir'/config.yaml"

	* Check if config already exists and has valid content
	if (fileexists("`config_file'")) {
		* Verify config has required settings (check for usage_logging key)
		_rs_config get "`dir'" "usage_logging"
		local has_content = r(found)

		if (`has_content' == 1) {
			* Valid config exists
			return clear
			return scalar exists = 1
			return scalar writable = 1
			exit 0
		}
		else {
			* Empty or invalid config - delete and reinitialize
			cap erase "`config_file'"
		}
	}

	* Try to create config directory if it doesn't exist
	cap _rs_utils confirmdir "`dir'"
	if (r(exists) == 0) {
		cap mkdir "`dir'"
		if (_rc != 0) {
			* Can't create directory (read-only system)
			return clear
			return scalar exists = 0
			return scalar writable = 0
			exit 0
		}
	}

	* ═══════════════════════════════════════════════════════════════════════
	* FIRST-RUN SETUP: Get user consent for internet connections (SSC compliance)
	* ═══════════════════════════════════════════════════════════════════════

	* Default values for new config (Full Mode - for testing usage tracking)
	local usage_logging "true"
	local telemetry_enabled "true"
	local internet_access "true"
	local auto_update_check "true"

	* Check if auto-approve is enabled (for automated testing)
	if ("$REGISTREAM_AUTO_APPROVE" != "yes") {
		* Show first-run setup prompt
		di as result ""
		di as result "{hline 60}"
		di as result "RegiStream - First-Time Setup"
		di as result "{hline 60}"
		di as text ""
		di as text "Welcome to RegiStream! Before we begin, please choose your setup mode."
		di as text ""
		di as text "Configuration directory: {result:`dir'}"
		di as text ""
		di as text "To use a custom directory, set before running:"
		di as text "  . global registream_dir " _char(34) "/your/custom/path" _char(34)
		di as text ""
		di as result "Setup Options:"
		di as text ""
		di as text "  1) {bf:Offline Mode}"
		di as text "     • No internet connections"
		di as text "     • Manual metadata management"
		di as text "     • Local usage logging only (stays on your machine)"
		di as text ""
		di as text "  2) {bf:Standard Mode}"
		di as text "     • Automatic metadata downloads from registream.org"
		di as text "     • Automatic update checks (daily)"
		di as text "     • Local usage logging only (stays on your machine)"
		di as text "     • No online telemetry"
		di as text ""
		di as text "  3) {bf:Full Mode (Help Improve RegiStream)}"
		di as text "     • Everything in Standard Mode, plus:"
		di as text "     • Online telemetry: Sends anonymized usage data to help improve"
		di as text "       RegiStream (commands run, version, OS - including variable"
		di as text "       names from commands but no dataset content)"
		di as text ""
		di as text "Note: You can change these settings later using:"
		di as text "  . registream config"
		di as text ""
		di as result "{hline 60}"
		di as text ""

		* Get user choice (3 options)
		_rs_utils prompt_choice "Select setup mode:" "Offline Mode" "Standard Mode" "Full Mode"
		local choice = r(choice)

		if ("`choice'" == "1") {
			* Offline mode
			local usage_logging "true"
			local telemetry_enabled "false"
			local internet_access "false"
			local auto_update_check "false"

			di as text ""
			di as result "Offline Mode selected."
			di as text "All internet features disabled. Local usage logging enabled."
			di as text "You can enable internet features later with:"
			di as text "  . registream config, internet_access(true)"
			di as text ""
		}
		else if ("`choice'" == "2") {
			* Standard mode
			local usage_logging "true"
			local telemetry_enabled "false"
			local internet_access "true"
			local auto_update_check "true"

			di as text ""
			di as result "Standard Mode selected."
			di as text "Internet features enabled. Online telemetry disabled."
			di as text "You can enable online telemetry later with:"
			di as text "  . registream config, telemetry_enabled(true)"
			di as text ""
		}
		else {
			* Full mode (choice 3)
			local usage_logging "true"
			local telemetry_enabled "true"
			local internet_access "true"
			local auto_update_check "true"

			di as text ""
			di as result "Full Mode selected."
			di as text "All features enabled including online telemetry."
			di as text "Thank you for helping improve RegiStream!"
			di as text "You can disable online telemetry later with:"
			di as text "  . registream config, telemetry_enabled(false)"
			di as text ""
		}
	}
	* else: AUTO_APPROVE mode (testing) - uses Full Mode (option 3) defaults
	* (internet enabled, online telemetry enabled, for testing usage tracking endpoint)

	* ═══════════════════════════════════════════════════════════════════════
	* Create config.yaml with user's choices
	* ═══════════════════════════════════════════════════════════════════════

	* Try to write initial config.yaml
	cap file close configfile
	cap file open configfile using "`config_file'", write replace
	if (_rc != 0) {
		* Can't write config (read-only system)
		return clear
		return scalar exists = 0
		return scalar writable = 0
		exit 0
	}

	file write configfile "# RegiStream Configuration" _n
	file write configfile "" _n

	* Settings (based on user choice)
	file write configfile "# Settings" _n
	file write configfile "usage_logging: `usage_logging'" _n
	file write configfile "telemetry_enabled: `telemetry_enabled'" _n
	file write configfile "internet_access: `internet_access'" _n
	file write configfile "auto_update_check: `auto_update_check'" _n
	file write configfile "" _n

	* Update tracking
	file write configfile "# Update tracking" _n
	file write configfile `"last_update_check: """' _n
	file write configfile "update_available: false" _n
	file write configfile `"latest_version: """' _n

	cap file close configfile

	return clear
	return scalar exists = 0
	return scalar writable = 1
end

* Get a value from config
program define _config_get, rclass
	args dir key

	local config_file "`dir'/config.yaml"

	* Check if config exists
	if (!fileexists("`config_file'")) {
		return clear
		return local value ""
		return scalar found = 0
		exit 0
	}

	* Read config file line by line
	tempname fh
	file open `fh' using "`config_file'", read

	local found 0
	local value ""

	file read `fh' line
	local eof_status = r(eof)
	while `eof_status' == 0 {
		* Check if line contains our key
		if (strpos("`line'", "`key':") > 0) {
			* Extract everything after "key:" using subinstr
			local rawvalue : subinstr local line "`key':" "", all
			* Remove ALL spaces (not just one)
			local rawvalue : subinstr local rawvalue " " "", all
			* Remove all quotes
			local rawvalue : subinstr local rawvalue `"""' "", all
			local value "`rawvalue'"
			local found 1
		}

		file read `fh' line
		local eof_status = r(eof)
	}

	file close `fh'

	return clear
	return local value "`value'"
	return scalar found = `found'
end

* Set a value in config (simple key-value, not nested)
* Non-fatal if config is read-only
program define _config_set, rclass
	args dir key value

	local config_file "`dir'/config.yaml"

	* Check if config exists
	if (!fileexists("`config_file'")) {
		* Try to init first
		_rs_config init "`dir'"
		if (r(writable) == 0) {
			* Can't write, return gracefully
			return clear
			return scalar found = 0
			return scalar writable = 0
			exit 0
		}
	}

	* Read entire file into memory
	tempname fh
	cap file open `fh' using "`config_file'", read
	if (_rc != 0) {
		* Can't read config
		return clear
		return scalar found = 0
		return scalar writable = 0
		exit 0
	}

	local lines = 0
	local found = 0

	file read `fh' line
	local eof_status = r(eof)
	while `eof_status' == 0 {
		local ++lines
		local content`lines' `"`line'"'

		* Check if this line contains our key
		local trimmed = trim(`"`line'"')
		if (regexm("`trimmed'", "^`key':")) {
			* Replace the value (no indentation - same level as original)
			local content`lines' `"`key': `value'"'
			local found = 1
		}

		file read `fh' line
		local eof_status = r(eof)
	}

	file close `fh'

	* Try to write back to file
	cap file open `fh' using "`config_file'", write replace
	if (_rc != 0) {
		* Can't write (read-only system)
		return clear
		return scalar found = `found'
		return scalar writable = 0
		exit 0
	}

	forval i = 1/`lines' {
		file write `fh' `"`content`i''"' _n
	}

	cap file close `fh'

	return scalar found = `found'
	return scalar writable = 1
end
