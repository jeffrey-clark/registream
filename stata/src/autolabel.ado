cap program drop autolabel
program define autolabel
    version 16.0
	local version "{{VERSION}}"
    local release_date "{{DATE}}"
    
    * First argument is a required string (either 'variables' or 'values')
    * Followed by an optional varlist, and options: domain, exclude, lang
    syntax anything(name=arguments) , DOMAIN(string) LANG(string) [ EXCLUDE(varlist) SUFFIX(string)]
	
	
	* -----  PARSE THE LABEL_TYPE AND VARLIST ---------
	
	
	* Extract the first word from namelist (should be 'variables', 'values', or 'lookup')
    local label_type : word 1 of `arguments'
	local varlist : subinstr local arguments "`label_type'" "", all
	
	
    if !inlist("`label_type'", "variables", "values", "lookup") {
        di as error "Invalid first argument `label_type'. Please specify either 'variables', 'values' or 'lookup."
        exit 1
    }
	
	
	
	* Valid variable express checks for varaibels and values, not lookup
	
	if inlist("`label_type'", "variables", "values") {
		
		* Handle case where no varlist is provided (select all variables)
		if "`varlist'" == "" {
			unab varlist : _all  // expand all variables in the dataset
		} 
		else {
		
			local unique_vars ""
			local error_flag 0
		
			
			foreach var of local varlist {
				cap qui ds `var'

				if (_rc == 0) {
				   local expanded_vars =r(varlist)
					foreach x in `expanded_vars' {
						 if !strpos("`unique_vars'", "`x'") {
							local unique_vars `unique_vars' `x'
						}
					}
				
				} 
				
				else {
					* If no match, set the error flag and report the invalid variable
					di as error "`var' is not a valid variable in the dataset."
					local error_flag 1
				}
			}
			
			* If any invalid variables were encountered, exit with an error
			if `error_flag' == 1 {
				exit 198
			}
				
			* Update varlist with the expanded variables
			local varlist `unique_vars'
		
		}
		
		
		* -----  HANDLE EXCLUSION OF VARIABLES ---------
		
		if "`exclude'" != "" {
			local exclude_error 0
			local new_varlist ""
			
			* Verify the variables in the exclude varlist and remove them from `varlist`
			foreach ex_var of local exclude {
				cap qui ds `ex_var'
				if _rc != 0 {
					* If any exclude variable is invalid, display an error
					di as error "`ex_var' in the EXCLUDE list is not a valid variable."
					local exclude_error 1
				}
			}
			
			* If any invalid exclude variables were encountered, exit with an error
			if `exclude_error' == 1 {
				exit 198
			}
			
			* Create a new varlist excluding the variables in the exclude list
			foreach var of local varlist {
				if !strpos("`exclude'", "`var'") {
					local new_varlist "`new_varlist' `var'"
				}
			}
			
			* Update varlist with the new varlist that excludes the variables
			local varlist "`new_varlist'"
		}
		
	}

	* ----- DOMAIN, LANGUAGE, DATA_DIR IDENTIFICATION  ---------
   
   
    * Ensure domain is specified
    if "`domain'" == "" {
        di as error "Domain not specified. Please specify domain(scb)."
        exit 1
    }

    * Currently support only 'scb' as a domain
    if "`domain'" != "scb" {
        di as error "Domain `domain' is not supported. Currently, only 'scb' is available."
        exit 1
    }

    * Ensure language is specified
    if !inlist("`lang'", "swe", "eng") {
        di as error "Language `lang' is not supported. Currently, only 'eng' (English) and 'swe' (Swedish) are available."
        exit 1
    }
	
	* Check if we have $registream_dir override
	if "$registream_dir" != "" {
		
		_rs_confirmdir "$registream_dir"
		
		if (r(exists) == 0) {
			qui di as error "The global \$registream_dir is not a valid directory"
			qui di as error "Current Value: $registream_dir"
			qui di as error "You have two options:"
			qui di as error "  1) ensure that the value is a valid directory path."
			qui di as error "  2) unset the global, which will revert to the default registream directory locations "                
			exit 1
		} 
		
		local registream_dir "$registream_dir"
		
		if substr("`registream_dir'", -1, 1) == "/" | substr("`registream_dir'", -1, 1) == "\" {
			local registream_dir = substr("`registream_dir'", 1, length("`registream_dir'") - 1)
		}
		
		local autolabel_dir "`registream_dir'/autolabel_keys"
		
	}
	* Otherwise proceed with default registream locations
	else {
			
		* Detect the operating system and set the path
		local os = c(os)
		local username = c(username)	

		if "`os'" == "Windows" {
			local homedir "C:/Users/`username'"
			local registream_dir "`homedir'/AppData/Local/registream"
			local autolabel_dir "`registream_dir'/autolabel_keys"
		}
		else if "`os'" == "MacOSX" {	
			local homedir "/Users/`username'"
			local registream_dir "`homedir'/.registream"
			local autolabel_dir "`registream_dir'/autolabel_keys"
		}
		else {
			di as error "Home directory not known. Try setting global \$registream_dir to a valid directory for label data storage."
			exit 1
		}
		
		* Check if the home directory exists 
		_rs_confirmdir "`homedir'"
		
		if (r(exists) == 0) {
			qui di as error "Home directory cannot be accessed. Try setting global \$registream_dir"
		}
	}
	
	
	* Confirm that the registream_dir and autolabel_dir exists
	local alerted 0
	foreach d in "`registream_dir'" "`autolabel_dir'" {
		
		_rs_confirmdir "`d'"
		
		if (r(exists) == 0) {
			
			if (`alerted' == 0) {
				dis as result "Creating system folders..."
				local alerted 1
			}
			
			dis as text "Creating dir: `d'"
			mkdir "`d'"
		}	
		
		
	}
		
		
	* -----  DOWNLOAD AND EXTRACT VARIABLE DATA ---------
	
	* Construct the file paths
	local var_filename = "scb_variables_`lang'"
	local var_filepath_zip = "`autolabel_dir'/`var_filename'.zip"
	local var_filepath_zipfold "`autolabel_dir'/`var_filename'"
	local var_filepath_csv = "`autolabel_dir'/`var_filename'.csv"
	local var_filepath_dta = "`autolabel_dir'/`var_filename'.dta"
	
	_rs_download_extract, zip("`var_filepath_zip'") zipfold("`var_filepath_zipfold'") ///
    csv("`var_filepath_csv'") dta("`var_filepath_dta'") file("`var_filename'") ///
    dir("`autolabel_dir'") clean("variables")

	
	* -----  END DOWNLOAD AND EXTRACT VARIABLE DATA ---------
	
	
	
	* ----- AUTOLABEL VARIABLES ---------

    if "`label_type'" == "variables" {
	
        di as text "Labeling variables in domain `domain' using language `lang'"
        
		quietly {
		
		preserve
		
			keep `varlist'
			
			* reduce number of rows for improved speed (and since we do not need distribution data for labelling)
			set seed 270523
			sample 100, count

			_rs_summarize_dataset
			gen variable_original = variable
			order variable_original, first
			replace variable = lower(variable) 

			
			merge 1:1 variable using "`var_filepath_dta'", keep(1 3) nogen
			
			gen var_label = variable_desc
			replace var_label = variable_desc + " (" + unit + ")" if unit != ""


			// Create a tempfile for the .do file
			tempfile tmpfile

			// Ensure the file handle is released in case it was previously used
			cap file close myfile

			// Open the tempfile for writing
			file open myfile using `tmpfile', write replace

			local n = _N 
			forval i = 1/`n' {

				// Define the variable name
				local var_name = variable_original[`i']
				
				// Define the variable label
				local var_label = var_label[`i']

				// Write the label command to the file
				if "`suffix'" == "" {
					file write myfile `"label variable `var_name' "`var_label'" "' _n
				} 
				else {
					local var_name_suffix "`var_name'`suffix'"
					file write myfile `"cap gen `var_name_suffix' = `var_name'"' _n
					file write myfile `"label variable `var_name_suffix' "`var_label'" "' _n
				}
				
			}

			// Close the file
			file close myfile

		restore

		// Execute the tempfile as a .do file


			do `tmpfile'
		}
			
    } 
	
	* ----- AUTOLABEL VALUE LABELS ---------

	else if "`label_type'" == "values" {
	
		
		* -----  DOWNLOAD AND EXTRACT VALUE LABEL DATA ---------
		
			
		* Construct the file paths
		local val_filename = "scb_value_labels_`lang'"
		local val_filepath_zip = "`autolabel_dir'/`val_filename'.zip"
		local val_filepath_zipfold "`autolabel_dir'/`val_filename'"
		local val_filepath_csv = "`autolabel_dir'/`val_filename'.csv"
		local val_filepath_dta = "`autolabel_dir'/`val_filename'.dta"
		
		_rs_download_extract, zip("`val_filepath_zip'") zipfold("`val_filepath_zipfold'") ///
    csv("`val_filepath_csv'") dta("`val_filepath_dta'") file("`val_filename'") ///
    dir("`autolabel_dir'") clean("values")
		
		
		* -----  END DOWNLOAD AND EXTRACT VALUE LABEL  DATA ---------
		


        di as text "Labeling values in domain `domain' using language `lang'"
        
		quietly {
		
		preserve

			keep `varlist'
			
			* reduce number of rows for improved speed (and since we do not need distribution data for labelling)
			set seed 270523
			sample 100, count
			
			_rs_summarize_dataset
			gen variable_original = variable
			order variable_original, first
			replace variable = lower(variable) 

			merge 1:1 variable using "`var_filepath_dta'", keep(1 3) nogen
			merge m:1 value_label_id using "`val_filepath_dta'", keep(1 3) nogen


			// Create a tempfile for the .do file
			tempfile tmpfile

			// Ensure the file handle is released in case it was previously used
			cap file close myfile

			// Open the tempfile for writing
			file open myfile using `tmpfile', write replace

			local n = _N 
			forval i = 1/`n' {

				// Define the variable name
				local var_name = variable_original[`i']	
			
				* ---- APPLY VALUE LABELS 
				if ((value_type[`i'] == "Koder") & (substr(type[`i'], 1, 3) == "str")) {
				
				// Determine the total number of words
				local str_value = value_labels_str[`i'] 

				// Count the number of words in the string
				local nwords : word count `str_value'
				
				if `nwords' > 0 {
				
				* --- APPLY SUFFIX PASSED IN OPTION
				if "`suffix'" == "" {
					// no change
				} 
				else {
					local var_name_suffix "`var_name'`suffix'"
					file write myfile `"cap gen `var_name_suffix' = `var_name'"' _n
					local var_name "`var_name_suffix'"
				}
				* ---------------------------------

				
				local enc_suffix "β" 
				local enc_var_name "`var_name'`enc_suffix'"
				// file write myfile "dis " _char(34) "`var_name'" _char(34) _n
				file write myfile `"cap drop `enc_var_name' "' _n
				file write myfile `"encode `var_name', gen(`enc_var_name') "' _n
				
				file write myfile `"local labelname : value label `enc_var_name' "' _n
				
				file write myfile `"levelsof `enc_var_name' , local(levels) "' _n
					
				forval i = 1(2)`nwords' {
					local j = `i'+1
					local code : word `i' of `str_value'
					local lbl : word `j' of `str_value'
					_rs_escape_ascii "`code'"
					local clean_code "`r(escaped_string)'"
					dis "`code'"
					dis "`lbl'"
					
					file write myfile `"local nl_`clean_code' "`lbl'" "' _n
				}
				
				
				file write myfile "foreach l of local levels {" _n
				file write myfile "    local val : label " _char(96) "labelname" _char(39) " " _char(96) "l" _char(39) _n
				
				* perform ascii escape...
				file write myfile " _rs_escape_ascii " _char(96) "val" _char(39) _n
				file write myfile " local clean_val " _char(96) "r(escaped_string)" _char(39) _n
				

				// Writing the dynamic `nl_value` with backticks and single quotes
				file write myfile "    local nl_value " _char(34) _char(96) "nl_" _char(96) "clean_val" _char(39) _char(39) _char(34) _n

				// Writing the if condition
				file write myfile "    if " _char(34) _char(96) "nl_value" _char(96) _char(34) " != " _char(34) _char(34) " {" _n

				// Writing the label definition dynamically using the same format
				// file write myfile "dis"  _char(34) _char(96) "nl_" _char(96) "val" _char(39) _char(39) _char(34) _n
				file write myfile "        label define " _char(96) "labelname" _char(39) " " _char(96) "l" _char(39) " " _char(34) _char(96) "nl_" _char(96) "val" _char(39) _char(39) _char(34) ", modify" _n

				file write myfile "    }" _n
				file write myfile "}" _n

				file write myfile `"drop `var_name' "' _n
				file write myfile `"rename `enc_var_name' `var_name' "' _n

				}

			  }
			
			}

			// Close the file
			file close myfile

		restore

		// Execute the tempfile as a .do file

			do `tmpfile'
		}
		
    }
	
	else if "`label_type'" == "lookup" {
		
		preserve
			
		
		* -----  DOWNLOAD AND EXTRACT VARIABLE AND VALUE DATA ---------
		
		* Construct the file paths
		local var_filename = "scb_variables_`lang'"
		local var_filepath_zip = "`autolabel_dir'/`var_filename'.zip"
		local var_filepath_zipfold "`autolabel_dir'/`var_filename'"
		local var_filepath_csv = "`autolabel_dir'/`var_filename'.csv"
		local var_filepath_dta = "`autolabel_dir'/`var_filename'.dta"
		
		_rs_download_extract, zip("`var_filepath_zip'") zipfold("`var_filepath_zipfold'") ///
		csv("`var_filepath_csv'") dta("`var_filepath_dta'") file("`var_filename'") ///
		dir("`autolabel_dir'") clean("variables")
		
			
		* Construct the file paths
		local val_filename = "scb_value_labels_`lang'"
		local val_filepath_zip = "`autolabel_dir'/`val_filename'.zip"
		local val_filepath_zipfold "`autolabel_dir'/`val_filename'"
		local val_filepath_csv = "`autolabel_dir'/`val_filename'.csv"
		local val_filepath_dta = "`autolabel_dir'/`val_filename'.dta"
		
		_rs_download_extract, zip("`val_filepath_zip'") zipfold("`val_filepath_zipfold'") ///
		csv("`val_filepath_csv'") dta("`val_filepath_dta'") file("`val_filename'") ///
		dir("`autolabel_dir'") clean("values")
			
		
		di as text "Looking up variables in domain `domain' using language `lang'"
		
		quietly {
				
		* --- Create a dataset with the passed variables 
		clear
		set obs `: word count `varlist''  // Set number of observations equal to the number of variables in varlist
		gen str50 variable = ""            // Create variable column
		gen var_id = .                     // Initialize var_id column

		* Loop through the varlist and populate the 'variable' column and var_id
		local i = 1
		foreach v of local varlist {
			replace variable = "`v'" in `i'
			replace var_id = `i' in `i'
			local ++i
		}

		tempfile lookup_vars
		save `lookup_vars'
		
		* --- Merge with the variables dataset 

		use "`var_filepath_dta'", clear
		merge 1:1 variable using `lookup_vars', keep(2 3)
		merge m:1 value_label_id using "`val_filepath_dta'", keep(1 3) nogen
		
		* Display the found variable i.e. 
		sort var_id 
		
		* Initialize a local to store missing variables
		local missing_vars ""
		
		}

		* Loop through each row in the dataset
		forval i = 1/`=_N' {
			* Take the value of _merge for the current row
			local current_merge = _merge[`i']

			* If the variable was found in both datasets (_merge == 3)
			if `current_merge' == 3 {
				di as text _dup(90)("-")
				
				* Ensure variable name is displayed in bold and aligned
				di as result "| VARIABLE:     {bf}`=variable[`i']'"
				
				* Display the variable description with alignment
				di as text "| LABEL:        " "`=variable_desc[`i']'"
				
				* Format the definition and handle line breaks manually by adding indentation
				* Use subinstr to escape apostrophes temporarily
				quietly {
					gen str200 _temp_def = subinstr(definition[`i'], "'", "|APOS|", .) in `i'
					local definition_str = _temp_def[`i']
					drop _temp_def
				}
				* Restore apostrophes
				local definition_str = subinstr("`definition_str'", "|APOS|", "'", .)
				local def_first = trim(substr("`definition_str'", 1, 70))
				di as text "| DEFINITION:   " "`def_first'"

				* If definition length exceeds 70 characters, continue with indentation
				if length("`definition_str'") > 70 {
					local remaining_def = substr("`definition_str'", 71, .)
					while length("`remaining_def'") > 0 {
						local def_chunk = trim(substr("`remaining_def'", 1, 70))
						di as text "|               " "`def_chunk'"
						local remaining_def = substr("`remaining_def'", 71, .)
					}
				}
				
				*.  ------------
				
				// Determine the total number of words
				local str_value = value_labels_str[`i'] 

				// Count the number of words in the string
				local nwords : word count `str_value'

				if `nwords' > 0 {
					local max_display 8
					local nlabels = floor(`nwords'/2)

					/// Calculate how many words to loop over (up to 8 pairs, or 16 words)
					local max_iter = min(`nwords', 16)

					// Loop through the first 8 pairs of value labels
					forval k = 1(2)`max_iter' {
						local j = `k' + 1
						local code : word `k' of `str_value'
						local lbl : word `j' of `str_value'
						
						// Truncate the label if it exceeds 65 characters
						if length("`code': `lbl'") > 70 {
							local lbl = substr("`lbl'", 1, 65) + "..."
						}

						// Print the first label as the start of the block
						if `k' == 1 {
							di as text "| VALUE LABELS: `code': `lbl'"
						}
						// Indent the remaining labels
						else {
							di as text "|               `code': `lbl'"
						}
					}

					// If there are more than 8 labels, show the remaining count
					if `nlabels' > `max_display' {
						local remaining = `nlabels' - `max_display'
						di as text "|               (and `remaining' more labels)"
					}
				} 
				else {
					// di as text "| VALUE LABELS: No value labels available"
				}

				di as text _dup(90)("-")

				* - ------------
			
			}
			
			* If the variable was only in the lookup dataset (_merge == 2)
			else if `current_merge' == 2 {
				local missing_vars `missing_vars' "`=variable[`i']'"
			}
			
		}

		* If there are any missing variables, display them in red
		if "`missing_vars'" != "" {
			di as error _dup(90)("-")
			di as error "The following variables were not found in `domain':"
			
			* Loop through each variable in the missing_vars local macro
			foreach var of local missing_vars {
				di as error "   • `var'"
			}
			
			di as error _dup(90)("-")
		}			
				
	restore
	
	}

end






