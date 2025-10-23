*! version 2.0.0  20oct2025
* RegiStream: Main command entry point
* Author: Jeffrey Clark
*
* Syntax:
*   registream update [package|dataset|datasets] [, domain() lang()]  (default: package)
*   registream info
*   registream config
*   registream version
*   registream cite

cap program drop registream
cap program drop _registream_wrapper_start
cap program drop _registream_wrapper_end
cap program drop _registream_update
cap program drop _registream_info
cap program drop _registream_config
cap program drop _registream_version
cap program drop _registream_cite
cap program drop _registream_stats

program define registream
	version 16.0

	* Load dev config if it exists (only during development, not in production package)
	* This file is in .gitignore and won't be in the distributed package
	* Dev config can override _rs_utils get_version to return a dev version
	cap qui _rs_dev_config

	* Get version from helper function (can be overridden by dev/test mode)
	_rs_utils get_version
	local REGISTREAM_VERSION "`r(version)'"

	* ==========================================================================
	* MASTER WRAPPER (START): Usage tracking + Background update check
	* Runs for ALL registream commands
	* ==========================================================================
	_registream_wrapper_start "`REGISTREAM_VERSION'" "`0'"
	local registream_dir "`r(registream_dir)'"

	* Parse first argument (subcommand)
	gettoken subcmd rest : 0, parse(" ,")

	if ("`subcmd'" == "update") {
		_registream_update `rest'
		_registream_wrapper_end "`REGISTREAM_VERSION'" "`registream_dir'" "`0'"
		exit 0
	}
	else if ("`subcmd'" == "info") {
		_registream_info `rest'
		_registream_wrapper_end "`REGISTREAM_VERSION'" "`registream_dir'" "`0'"
		exit 0
	}
	else if ("`subcmd'" == "config") {
		_registream_config `rest'
		_registream_wrapper_end "`REGISTREAM_VERSION'" "`registream_dir'" "`0'"
		exit 0
	}
	else if ("`subcmd'" == "version") {
		_registream_version `rest'
		_registream_wrapper_end "`REGISTREAM_VERSION'" "`registream_dir'" "`0'"
		exit 0
	}
	else if ("`subcmd'" == "cite") {
		_registream_cite `rest'
		_registream_wrapper_end "`REGISTREAM_VERSION'" "`registream_dir'" "`0'"
		exit 0
	}
	else if ("`subcmd'" == "stats") {
		_registream_stats `rest'
		_registream_wrapper_end "`REGISTREAM_VERSION'" "`registream_dir'" "`0'"
		exit 0
	}
	else if ("`subcmd'" == "") {
		di as error "RegiStream: Please specify a subcommand"
		di as text ""
		di as text "Available subcommands:"
		di as text "  {cmd:registream update} [package|dataset|datasets] - Check for updates (default: package)"
		di as text "  {cmd:registream info}                              - Show configuration"
		di as text "  {cmd:registream config}                            - View/edit config"
		di as text "  {cmd:registream version}                           - Show package version"
		di as text "  {cmd:registream cite}                              - Show citation"
		di as text "  {cmd:registream stats} [all]                       - Show usage statistics"
		di as text ""
		di as text "See {help registream:help registream} for details"
		_registream_wrapper_end "`REGISTREAM_VERSION'" "`registream_dir'" "`0'"
		exit 198
	}
	else {
		di as error "Unknown subcommand: `subcmd'"
		di as text "Available: update, info, config, version, cite, stats"
		di as text "See {help registream:help registream} for details"
		_registream_wrapper_end "`REGISTREAM_VERSION'" "`registream_dir'" "`0'"
		exit 198
	}
end

* =============================================================================
* Subcommand: registream update
* =============================================================================
program define _registream_update
	version 16.0

	* Get version from helper function
	_rs_utils get_version
	local REGISTREAM_VERSION "`r(version)'"

	* Parse arguments: [package|dataset|datasets] [, domain() lang()]
	syntax [anything] [, DOMAIN(string) LANG(string)]
	local what "`anything'"

	* Normalize domain and lang to lowercase immediately (case-insensitive)
	if ("`domain'" != "") local domain = lower("`domain'")
	if ("`lang'" != "") local lang = lower("`lang'")

	* Get registream directory
	_rs_utils get_dir
	local registream_dir "`r(dir)'"

	* Initialize config (ensures it exists)
	_rs_config init "`registream_dir'"

	* If no argument or "package", check package updates
	if ("`what'" == "" | "`what'" == "package") {
		di as result ""
		di as result "{hline 60}"
		di as result "RegiStream Package Update Check"
		di as result "{hline 60}"
		di as result ""

		* Check for package updates (pass hardcoded version)
		_rs_updates check_package "`registream_dir'" "`REGISTREAM_VERSION'"
		local update_available = r(update_available)
		local current_version = r(current_version)
		local latest_version = r(latest_version)
		local reason = r(reason)

		if ("`reason'" == "internet_disabled") {
			di as text "Update check disabled (offline mode)"
			di as text "To enable: registream config, internet_access(true)"
		}
		else if ("`reason'" == "network_error") {
			di as text "Could not check for updates (network error)"
		}
		else if ("`reason'" == "success") {
			di as text "Current version: {result:`current_version'}"
			di as text "Latest version:  {result:`latest_version'}"
			di as text ""

			if (`update_available' == 1) {
				di as result "A new version is available!"
				di as text ""
				di as text "Would you like to update now? (y/n)"
				di as input "> " _request(user_response)
				local user_response = trim(lower(`"`r(user_response)'"'))

				if ("`user_response'" == "y" | "`user_response'" == "yes") {
					di as text ""
					di as result "Updating RegiStream..."
					di as text "{hline 60}"

					* Run net install to update package
					cap noi net install registream, from(https://registream.org/stata) replace

					if (_rc == 0) {
						di as text "{hline 60}"
						di as result "✓ Update successful!"
						di as text ""
						di as text "RegiStream has been updated to version `latest_version'"
						di as text "Please restart Stata or reload the package to use the new version"
					}
					else {
						di as text "{hline 60}"
						di as error "✗ Update failed"
						di as text ""
						di as text "Please try updating manually:"
						di as text "  . net install registream, from(https://registream.org/stata) replace"
					}
				}
				else {
					di as text ""
					di as text "Update cancelled. To update later, run:"
					di as text "  . registream update package"
					di as text ""
					di as text "Or update manually:"
					di as text "  . net install registream, from(https://registream.org/stata) replace"
				}
			}
			else {
				di as result "You have the latest version!"
			}
		}

		di as result ""
		di as result "{hline 60}"
		di as result ""
	}

	* If "dataset" or "datasets", check dataset updates
	else if ("`what'" == "dataset" | "`what'" == "datasets") {
		di as result ""
		di as result "{hline 60}"
		di as result "RegiStream Dataset Update Check"
		di as result "{hline 60}"
		di as result ""

		* Call interactive update workflow
		if ("`domain'" != "" | "`lang'" != "") {
			_rs_updates update_datasets_interactive "`registream_dir'", domain(`domain') lang(`lang')
		}
		else {
			_rs_updates update_datasets_interactive "`registream_dir'"
		}

		di as result ""
		di as result "{hline 60}"
		di as result ""
	}
	else {
		di as error "Unknown update target: `what'"
		di as text "Usage: registream update [package|dataset|datasets]  (default: package)"
		exit 198
	}
end

* =============================================================================
* Subcommand: registream info
* =============================================================================
program define _registream_info
	version 16.0

	* Get version from helper function
	_rs_utils get_version
	local REGISTREAM_VERSION "`r(version)'"

	* Get registream directory
	_rs_utils get_dir
	local registream_dir "`r(dir)'"

	* Initialize config (ensures it exists)
	_rs_config init "`registream_dir'"

	* Get config values (with defaults if config is read-only)
	_rs_config get "`registream_dir'" "usage_logging"
	local usage_logging = r(value)
	if ("`usage_logging'" == "") local usage_logging "true"

	_rs_config get "`registream_dir'" "telemetry_enabled"
	local telemetry = r(value)
	if ("`telemetry'" == "") local telemetry "false"

	_rs_config get "`registream_dir'" "internet_access"
	local internet = r(value)
	if ("`internet'" == "") local internet "true"

	_rs_config get "`registream_dir'" "auto_update_check"
	local auto_update = r(value)
	if ("`auto_update'" == "") local auto_update "true"

	* Display info
	di as result ""
	di as result "{hline 60}"
	di as result "RegiStream Configuration"
	di as result "{hline 60}"
	di as text "Directory:        {result:`registream_dir'}"
	di as text "Config file:      {result:`registream_dir'/config.yaml}"
	di as text ""
	di as text "Package:"
	di as text "  version:         {result:`REGISTREAM_VERSION'}"
	di as text ""
	di as text "Settings:"
	di as text "  usage_logging:       {result:`usage_logging'} (local only, stays on your machine)"
	di as text "  telemetry_enabled:   {result:`telemetry'} (sends anonymized data to registream.org)"
	di as text "  internet_access:     {result:`internet'}"
	di as text "  auto_update_check:   {result:`auto_update'}"
	di as result "{hline 60}"
	di as text ""
	di as text "Citation:"
	di as text "  Clark, J. & Wen, J. (2024–). RegiStream: Streamline Your"
	di as text "  Register Data Workflow. Available at: https://registream.org"
	di as text ""
	di as text "Full citation (with version & datasets): {stata registream cite:registream cite}"
	di as result ""
end

* =============================================================================
* Subcommand: registream config
* =============================================================================
program define _registream_config
	version 16.0

	syntax [, USAGE_logging(string) TELEMETRY_enabled(string) INTERNET_access(string) AUTO_update_check(string)]

	* Get registream directory
	_rs_utils get_dir
	local registream_dir "`r(dir)'"

	* Initialize config
	_rs_config init "`registream_dir'"

	* If no options, just show config
	if ("`usage_logging'" == "" & "`telemetry_enabled'" == "" & "`internet_access'" == "" & "`auto_update_check'" == "") {
		_registream_info
		exit 0
	}

	* Update usage_logging if provided
	if ("`usage_logging'" != "") {
		if (!inlist("`usage_logging'", "true", "false")) {
			di as error "usage_logging must be 'true' or 'false'"
			exit 198
		}
		_rs_config set "`registream_dir'" "usage_logging" "`usage_logging'"
		di as result "✓ usage_logging set to: `usage_logging'"
	}

	* Update telemetry_enabled if provided
	if ("`telemetry_enabled'" != "") {
		if (!inlist("`telemetry_enabled'", "true", "false")) {
			di as error "telemetry_enabled must be 'true' or 'false'"
			exit 198
		}
		_rs_config set "`registream_dir'" "telemetry_enabled" "`telemetry_enabled'"
		di as result "✓ telemetry_enabled set to: `telemetry_enabled'"
	}

	* Update internet_access if provided
	if ("`internet_access'" != "") {
		if (!inlist("`internet_access'", "true", "false")) {
			di as error "internet_access must be 'true' or 'false'"
			exit 198
		}
		_rs_config set "`registream_dir'" "internet_access" "`internet_access'"
		di as result "✓ internet_access set to: `internet_access'"
	}

	* Update auto_update_check if provided
	if ("`auto_update_check'" != "") {
		if (!inlist("`auto_update_check'", "true", "false")) {
			di as error "auto_update_check must be 'true' or 'false'"
			exit 198
		}
		_rs_config set "`registream_dir'" "auto_update_check" "`auto_update_check'"
		di as result "✓ auto_update_check set to: `auto_update_check'"
	}

	di as text ""
	di as text "Config updated successfully!"
	di as text ""
end

* =============================================================================
* Subcommand: registream version
* =============================================================================
program define _registream_version
	version 16.0

	* Get version from helper function
	_rs_utils get_version
	local REGISTREAM_VERSION "`r(version)'"

	di as result ""
	di as text "RegiStream version {result:`REGISTREAM_VERSION'}"
	di as result ""
end

* =============================================================================
* Subcommand: registream cite
* =============================================================================
program define _registream_cite
	version 16.0

	* Get version from helper function
	_rs_utils get_version
	local REGISTREAM_VERSION "`r(version)'"

	* Get registream directory for dataset versions
	_rs_utils get_dir
	local registream_dir "`r(dir)'"

	di as result ""
	di as result "{hline 60}"
	di as result "Citation"
	di as result "{hline 60}"
	di as text ""
	di as text "To cite RegiStream in publications, please use:"
	di as text ""
	di as text "  Clark, J. & Wen, J. (2024–). RegiStream: Streamline Your"
	di as text "  Register Data Workflow. Available at: https://registream.org"
	di as text ""
	di as text "For version-specific citation (recommended for replicability):"
	di as text ""
	di as text "  Clark, J. & Wen, J. (2024–). RegiStream: Streamline Your"
	di as text "  Register Data Workflow (Version `REGISTREAM_VERSION')."
	di as text "  Available at: https://registream.org"
	di as text ""
	di as text "BibTeX:"
	di as text "{hline 60}"
	di as text "@software{clark2024registream,"
	di as text "  author  = {Clark, Jeffrey and Wen, Jie},"
	di as text "  title   = {RegiStream: Streamline Your Register Data Workflow},"
	di as text "  version = {`REGISTREAM_VERSION'},"
	di as text "  year    = {2024--},"
	di as text "  url     = {https://registream.org}"
	di as text "}"
	di as text "{hline 60}"
	di as text ""

	* Show installed dataset versions for reproducibility
	di as text "Installed datasets:"
	di as text ""

	* Check for datasets.csv in autolabel_keys directory
	local autolabel_dir "`registream_dir'/autolabel_keys"
	local datasets_csv "`autolabel_dir'/datasets.csv"
	cap confirm file "`datasets_csv'"
	if (_rc == 0) {
		* Read datasets.csv line by line
		tempname fh
		file open `fh' using "`datasets_csv'", read
		file read `fh' line

		* Skip header line
		file read `fh' line

		local found_any = 0
		while r(eof)==0 {
			* Parse semicolon-delimited line
			* Format: dataset_key;domain;type;lang;version;schema;downloaded;source;file_size;last_checked
			local dataset_key = trim(word(subinstr("`line'", ";", " ", .), 1))
			local dataset_version = trim(word(subinstr("`line'", ";", " ", .), 5))

			if ("`dataset_key'" != "" & "`dataset_version'" != "") {
				di as text "  • `dataset_key' (version: `dataset_version')"
				local found_any = 1
			}

			file read `fh' line
		}
		file close `fh'

		if (`found_any' == 0) {
			di as text "  (none installed yet)"
		}
	}
	else {
		di as text "  (none installed yet)"
	}

	di as result ""
	di as result "{hline 60}"
	di as result ""
end

* =============================================================================
* Subcommand: registream stats
* =============================================================================
program define _registream_stats
	* Parse optional "all" argument
	local all_flag ""
	if (trim("`0'") == "all" | trim("`0'") == ", all") {
		local all_flag "all"
	}

	* Get registream directory
	_rs_utils get_dir
	local registream_dir "`r(dir)'"

	* Initialize usage tracking (ensures config exists)
	_rs_usage init "`registream_dir'"

	* Display stats
	if ("`all_flag'" != "") {
		_rs_usage stats "`registream_dir'" all
	}
	else {
		_rs_usage stats "`registream_dir'"
	}
end

* =============================================================================
* MASTER WRAPPER FUNCTIONS
* =============================================================================

* Wrapper start: Initialize everything + log usage + background check
program define _registream_wrapper_start, rclass
	args current_version command_line

	* Get registream directory
	_rs_utils get_dir
	local registream_dir "`r(dir)'"
	return local registream_dir "`registream_dir'"

	* Initialize config
	_rs_config init "`registream_dir'"

	* Parse command for conditional logic
	local first_word : word 1 of `command_line'

	* Log local usage (fast, synchronous) - skip "stats" to avoid recursion
	if ("`first_word'" != "stats") {
		_rs_config get "`registream_dir'" "usage_logging"
		if (r(value) == "true" | r(value) == "1") {
			_rs_usage init "`registream_dir'"
			_rs_usage log "`registream_dir'" "registream `command_line'" "`current_version'"
		}
	}

	* NOTE: Telemetry and update check moved to wrapper_end for consolidated heartbeat
	* This ensures instant startup with no blocking on network operations
end

* Wrapper end: Consolidated heartbeat (telemetry + update check) + notification
program define _registream_wrapper_end
	args current_version registream_dir command_line

	* Get registream directory if not provided
	if ("`registream_dir'" == "") {
		_rs_utils get_dir
		local registream_dir "`r(dir)'"
	}

	* Parse command for conditional logic
	if ("`command_line'" != "") {
		gettoken first_word rest : command_line, parse(" ,")
	}

	* Check if we should send heartbeat (telemetry OR update check enabled)
	_rs_config get "`registream_dir'" "telemetry_enabled"
	local telemetry_enabled = r(value)
	_rs_config get "`registream_dir'" "internet_access"
	local internet_access = r(value)
	_rs_config get "`registream_dir'" "auto_update_check"
	local auto_update_enabled = r(value)

	* Default to true if not found
	if ("`auto_update_enabled'" == "") local auto_update_enabled "true"

	* Send heartbeat if: (telemetry OR update_check) AND internet AND not "update"/"stats"/"config" command
	local should_heartbeat = 0
	if (("`telemetry_enabled'" == "true" | "`telemetry_enabled'" == "1" | "`auto_update_enabled'" == "true" | "`auto_update_enabled'" == "1") & ("`internet_access'" == "true" | "`internet_access'" == "1") & "`first_word'" != "update" & "`first_word'" != "stats" & "`first_word'" != "config") {
		local should_heartbeat = 1
	}

	if (`should_heartbeat' == 1) {
		* Consolidated heartbeat: telemetry + update check in one request
		* Uses native Stata copy - ZERO shell commands, ZERO flashes
		cap qui _rs_updates send_heartbeat "`registream_dir'" "`current_version'" "registream `command_line'"
	}

	* Show update notification if available
	_rs_updates show_notification "`current_version'"
end
