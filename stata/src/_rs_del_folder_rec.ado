cap program drop _rs_del_folder_rec
program _rs_del_folder_rec
	version 16.0
    local version "{{VERSION}}"
    local release_date "{{DATE}}"
    // Take the folder path as a string argument
    args folder

    // List all files in the current directory
    local files : dir "`folder'" files "*"
    
    // Delete all files in the directory
    foreach file in `files' {
        erase "`folder'/`file'"
    }

    // List all subdirectories
    local subdirs : dir "`folder'" dirs "*"
    
    // Recursively call the program to delete files and subdirectories
    foreach subdir in `subdirs' {
        delete_folder_recursive "`folder'/`subdir'"
    }

    // Delete the directory once all contents are removed
    rmdir "`folder'"
end
