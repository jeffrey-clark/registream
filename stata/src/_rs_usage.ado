cap program drop _rs_usage
program define _rs_usage
	version 16.0

	gettoken subcmd 0 : 0, parse(" ,")

	if ("`subcmd'" == "init") {
		_usage_init `0'
	}
	else if ("`subcmd'" == "log") {
		_usage_log `0'
	}
	else if ("`subcmd'" == "stats") {
		_usage_stats `0'
	}
	else if ("`subcmd'" == "send_online") {
		_usage_send_online `0'
	}
	else {
		di as error "Invalid _rs_usage subcommand: `subcmd'"
		exit 198
	}
end

* Initialize usage tracking (ensure config exists)
program define _usage_init
	args dir

	* Ensure config exists
	_rs_config init "`dir'"

	* Check if usage file exists, create if not
	local usage_file "`dir'/usage_stata.csv"

	if (!fileexists("`usage_file'")) {
		cap file close usagefile
		file open usagefile using "`usage_file'", write replace
		file write usagefile "timestamp;user_id;platform;version;command_string;os;platform_version" _n
		file close usagefile
	}
end

* Log a command usage (append to usage_stata.csv)
program define _usage_log
	args dir command_string version

	* Check if local usage logging is enabled
	_rs_config get "`dir'" "usage_logging"
	local enabled "`r(value)'"

	if ("`enabled'" != "true" & "`enabled'" != "1") {
		exit 0
	}

	* Get user ID (compute hash from username + hostname)
	local username "`c(username)'"
	local hostname "`c(hostname)'"

	* Create simple hash from string lengths and character codes
	local hash 0
	local chars "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_."
	forval i = 1/`=min(length("`username'"), 20)' {
		local char_val = substr("`username'", `i', 1)
		local pos = strpos("`chars'", "`char_val'")
		if (`pos' > 0) {
			local hash = mod(`hash' * 31 + `pos', 4000000000)
		}
	}
	forval i = 1/`=min(length("`hostname'"), 20)' {
		local char_val = substr("`hostname'", `i', 1)
		local pos = strpos("`chars'", "`char_val'")
		if (`pos' > 0) {
			local hash = mod(`hash' * 31 + `pos', 4000000000)
		}
	}
	local user_id = string(`hash', "%010.0f")

	* Get current timestamp
	local timestamp "`c(current_date)'T`c(current_time)'Z"

	* Get system info (use machine type for OS to distinguish macOS from Linux in batch mode)
	local machine = c(machine_type)
	local os_raw = c(os)

	* Detect OS using same logic as _rs_utils get_dir
	if (strpos("`machine'", "Macintosh") > 0 | "`os_raw'" == "MacOSX") {
		local os "MacOSX"
	}
	else if ("`os_raw'" == "Windows") {
		local os "Windows"
	}
	else if ("`os_raw'" == "Unix") {
		local os "Unix"
	}
	else {
		local os "`os_raw'"
	}

	local platform_version "`c(stata_version)'"

	* Open usage file for appending
	local usage_file "`dir'/usage_stata.csv"

	cap file close usagefile
	file open usagefile using "`usage_file'", write append

	* Write CSV row with semicolon delimiter: timestamp;user_id;platform;version;command_string;os;platform_version
	file write usagefile "`timestamp';`user_id';stata;`version';`command_string';`os';`platform_version'" _n

	file close usagefile

	* Check if online telemetry is enabled
	_rs_config get "`dir'" "telemetry_enabled"
	local telemetry_enabled "`r(value)'"

	_rs_config get "`dir'" "internet_access"
	local internet_access "`r(value)'"

	* Send online telemetry if both enabled
	if ("`telemetry_enabled'" == "true" & "`internet_access'" == "true") {
		_usage_send_online "`dir'" "`command_string'" "`version'"
	}

	* Usage tracking is silent - no output displayed to user
end

* Display usage statistics
program define _usage_stats
	args dir all

	local usage_file "`dir'/usage_stata.csv"

	* Check if usage file exists
	if (!fileexists("`usage_file'")) {
		di as result ""
		di as result "No usage data available yet."
		di as result "Start using RegiStream to collect statistics."
		exit 0
	}

	* Get current user ID (if not showing all)
	if ("`all'" == "") {
		* Compute hash from username + hostname (same as in _usage_log)
		local username "`c(username)'"
		local hostname "`c(hostname)'"

		local hash 0
		local chars "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_."
		forval i = 1/`=min(length("`username'"), 20)' {
			local char_val = substr("`username'", `i', 1)
			local pos = strpos("`chars'", "`char_val'")
			if (`pos' > 0) {
				local hash = mod(`hash' * 31 + `pos', 4000000000)
			}
		}
		forval i = 1/`=min(length("`hostname'"), 20)' {
			local char_val = substr("`hostname'", `i', 1)
			local pos = strpos("`chars'", "`char_val'")
			if (`pos' > 0) {
				local hash = mod(`hash' * 31 + `pos', 4000000000)
			}
		}
		local my_user_id = string(`hash', "%010.0f")
	}

	* Read CSV with import delimited
	quietly {
		import delimited using "`usage_file'", clear delimiter(";") varnames(1) stringcols(_all)

		local my_calls 0
		local unique_users 0
		local first_date ""
		local last_date ""

		* Count unique users
		tab user_id
		local unique_users = r(r)

		* Filter to current user if not showing all
		if ("`all'" == "") {
			keep if user_id == "`my_user_id'"
		}

		* Count calls
		local my_calls = _N

		* Get first and last dates
		if (`my_calls' > 0) {
			* Extract date from timestamp (before 'T')
			gen date_str = substr(timestamp, 1, strpos(timestamp, "T") - 1)
			sum date_str
			local first_date = date_str[1]
			local last_date = date_str[_N]
		}
	}

	* Display stats
	di as result ""
	di as result "========================================="

	if ("`all'" != "") {
		di as result "RegiStream System-Wide Statistics"
		di as result "========================================="
		di as result "Unique Users:        `unique_users'"
		di as result "Total Calls:         `my_calls'"
	}
	else {
		di as result "RegiStream Usage Statistics"
		di as result "========================================="
		di as result "Your Anonymous ID:   `my_user_id'"
		di as result "Your Total Calls:    `my_calls'"
	}

	di as result ""

	if (`my_calls' > 0 & "`first_date'" != "") {
		di as result "First Use:  `first_date'"
		di as result "Last Use:   `last_date'"
		di as result ""
	}

	if ("`all'" == "") {
		di as text "View detailed log: `usage_file'"
		di as text "Disable local logging: registream config, usage_logging(false)"
	}
	di as result "========================================="
	di as result ""
end

* Send telemetry data to registream.org (online telemetry)
* This function sends anonymized usage data to help improve RegiStream
* Data sent: timestamp, user_id (hashed), platform, version, command_string, os, platform_version
* Same 7 fields as local CSV - no additional data collected
* No dataset content or personal data is transmitted
program define _usage_send_online
	args dir command_string version

	* Get user ID (same hash computation as local logging)
	local username "`c(username)'"
	local hostname "`c(hostname)'"

	local hash 0
	local chars "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_."
	forval i = 1/`=min(length("`username'"), 20)' {
		local char_val = substr("`username'", `i', 1)
		local pos = strpos("`chars'", "`char_val'")
		if (`pos' > 0) {
			local hash = mod(`hash' * 31 + `pos', 4000000000)
		}
	}
	forval i = 1/`=min(length("`hostname'"), 20)' {
		local char_val = substr("`hostname'", `i', 1)
		local pos = strpos("`chars'", "`char_val'")
		if (`pos' > 0) {
			local hash = mod(`hash' * 31 + `pos', 4000000000)
		}
	}
	local user_id = string(`hash', "%010.0f")

	* Get current timestamp
	local timestamp "`c(current_date)'T`c(current_time)'Z"

	* Get system info (use machine type for OS to distinguish macOS from Linux in batch mode)
	local machine = c(machine_type)
	local os_raw = c(os)

	* Detect OS using same logic as _rs_utils get_dir
	if (strpos("`machine'", "Macintosh") > 0 | "`os_raw'" == "MacOSX") {
		local os "MacOSX"
	}
	else if ("`os_raw'" == "Windows") {
		local os "Windows"
	}
	else if ("`os_raw'" == "Unix") {
		local os "Unix"
	}
	else {
		local os "`os_raw'"
	}

	local platform_version "`c(stata_version)'"

	* Build JSON payload (matches local CSV columns exactly)
	* Escape double quotes in command_string by replacing with single quotes
	local command_escaped : subinstr local command_string `"""' "'", all

	local json_payload `"{"timestamp": "`timestamp'", "user_id": "`user_id'", "platform": "stata", "version": "`version'", "command_string": "`command_escaped'", "os": "`os'", "platform_version": "`platform_version'"}"'

	* Get API host (supports dev mode override via _rs_utils get_api_host)
	* Suppress output to keep telemetry silent
	qui _rs_utils get_api_host
	local api_host "`r(host)'"
	local api_endpoint "`api_host'/api/v1/telemetry"

	* Send to registream.org via curl (silent failure on error)
	* Use temporary file for payload
	tempfile payload_file
	cap file close payloadfile
	cap file open payloadfile using "`payload_file'", write replace text

	if (_rc == 0) {
		file write payloadfile `"`json_payload'"'
		cap file close payloadfile

		* Send POST request with curl (silent, timeout 5 seconds, fail gracefully)
		* -s: silent mode, -S: show errors, --max-time: timeout, -f: fail on HTTP errors
		cap shell curl -s -S -f --max-time 5 -X POST -H "Content-Type: application/json" -d @"`payload_file'" "`api_endpoint'" 2>&1 > /dev/null

		* Clean up temp file
		cap erase "`payload_file'"
	}

	* Silent on all outcomes - no user feedback, no error messages
	* Usage tracking should never interrupt the user's workflow
end
