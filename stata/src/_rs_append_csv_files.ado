cap program drop _rs_append_csv_files
program _rs_append_csv_files
	version 16.0
    local version "{{VERSION}}"
    local release_date "{{DATE}}"
    args folder output_file

    // List all CSV files in the directory with the specified suffix
    local csv_files : dir "`folder'" files "*.csv"
    
    // Create a local to store the sorted list of CSV files
    local sorted_files ""

    // Loop through the files to append in order
    foreach file of local csv_files {
        // Extract the numeric suffix from the file name
        local suffix = substr("`file'", -6, 1)  // Adjust this based on the file name structure (suffix like _0, _1, _2)
        
        // Append files in the sorted order to the macro
        local sorted_files "`sorted_files' `file'"
    }

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
			// Import the CSV file
			import delimited using "`folder'/`this_file'", clear encoding("utf-8") bindquote(strict) maxquotedrows(unlimited)
			
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
