cap program drop _rs_confirmdir
program define _rs_confirmdir, rclass
	version 16.0
    local version "{{VERSION}}"
    local release_date "{{DATE}}"
    * Capture the first argument as a string (directory path)
    syntax anything(name=arguments)

    * Extract the first word from namelist (should be the directory path)
    local check_path : word 1 of `arguments'
    local syntax_check : subinstr local arguments "`check_path'" "", all

    * Check if more than one argument was passed
    if "`syntax_check'" != "" {
        di as error "Invalid syntax: pass just one argument, i.e., the filepath."
        exit 198  // Exit with an error if invalid syntax
    }
	
	local original_dir "`c(pwd)'"

    * Try to change the directory to see if the path exists
    cap cd "`check_path'"

    * Set _rc based on the success of changing the directory
    if (_rc == 0) {
        * Directory exists
        qui cd "`original_dir'" // Return to the original directory
        return scalar exists = 1
    }
    else {
        * Directory does not exist
        return  scalar exists = 0
    }
end

	
	

