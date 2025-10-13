cap program drop _rs_download_extract
program define _rs_download_extract
	version 16.0
    local version "{{VERSION}}"
    local release_date "{{DATE}}"
    * Define syntax to pass necessary locals (all in lowercase)
    syntax , zip(string) zipfold(string) csv(string) dta(string) file(string) dir(string) clean(string)

    * Ensure that the CSV file exists
    if (fileexists("`csv'") == 0) {
        
        * MONA CHECK: if no csv, but constituent folder, proceed to build
		_rs_confirmdir "`zipfold'"
		if (r(exists) == 1) {
            // discovered the constituent csv files, skip download, proceed to build
        }
        else {
            * Display the request for download
            di ""
            di as result "The file `file'.csv does not exist."
            di as result "Would you like to download it? Type 'yes' or 'no': "

            * Capture user input for download permission
            display as input _request(permission)

            * Check if permission is granted
            if ("$permission" != "yes") {
                di as error "Download permission not granted. Exiting."
                exit 1
            }

            * Download the zip file
            cap copy "https://registream.org/data/`file'.zip" "`zip'", replace

            * Unzip the zip file and clean up
            cap _rs_del_folder_rec "`zipfold'"
            cap erase "`dta'"

            if (fileexists("`zip'") == 0) {
                di as error "Failed to download zip file. Possible reasons:"
                qui di as error "  1) Temporary loss of internet connection. Check and retry."
                qui di as error "  2) Working on an offline server. Import the constituent csv files and try again."
                exit 1
            }
            else {
				quietly{
					local original_dir `"`c(pwd)'"'
					cd "`dir'"
					unzipfile "`file'.zip", replace
					cd "`original_dir'"
				}
            }
        }

        * Append the constituent csv files
		preserve
		_rs_append_csv_files "`zipfold'" "`csv'"
		restore

		
        if (fileexists(trim("`csv'")) == 0) {
            di as error "Oops something went wrong. Contact developers."
            exit 1
        }
    }

    * Since the CSV file exists, remove the constituent folder and zipfile
    if (fileexists("`csv'") == 1) {
        cap _rs_del_folder_rec "`zipfold'"
        cap erase "`zip'"
    }

    * Convert the CSV file to DTA if not already done
    if (fileexists("`dta'") == 0) {
        quietly {
            preserve
            import delimited using "`csv'", clear ///
                encoding("utf-8") bindquote(strict) maxquotedrows(unlimited) varnames(1)
            gen variable_lower = lower(variable)
            drop variable
            rename variable_lower variable
            order variable, first
            sort variable
            bysort variable : keep if _n == 1 
            
            * Custom cleaning logic based on the type
            if ("`clean'" == "values") {
                drop if value_labels == "{}"
                drop variable conflict harmonized_automatically value_labels
            }
            
            save "`dta'", replace
            restore
        }
    }
end
