

cap program drop _rs_summarize_dataset
program define _rs_summarize_dataset
	version 16.0
    local version "{{VERSION}}"
    local release_date "{{DATE}}"
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
