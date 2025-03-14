

cap program drop _rs_escape_ascii
program define _rs_escape_ascii, rclass
	version 16.0
    local version "{{VERSION}}"
    local release_date "{{DATE}}"
    // Input: A single string (not a variable list)
    args input_string
    
    // Escape special characters by replacing them with _q followed by ASCII code
    local escaped = "`input_string'"
    local escaped = subinstr("`escaped'", ".", "q46", .)  // Replace "." with _q46
    local escaped = subinstr("`escaped'", "*", "q42", .)  // Replace "*" with _q42
    local escaped = subinstr("`escaped'", "/", "q47", .)  // Replace "/" with _q47
    local escaped = subinstr("`escaped'", "&", "q38", .)  // Replace "&" with _q38
    local escaped = subinstr("`escaped'", "-", "q45", .)  // Replace "-" with _q45
    local escaped = subinstr("`escaped'", "_", "q95", .)  // Replace "_" with _q95
    local escaped = subinstr("`escaped'", "[", "q91", .)  // Replace "[" with _q91
    local escaped = subinstr("`escaped'", "]", "q93", .)  // Replace "]" with _q93
    local escaped = subinstr("`escaped'", "{", "q123", .)  // Replace "{" with _q123
    local escaped = subinstr("`escaped'", "}", "q125", .)  // Replace "}" with _q125
    local escaped = subinstr("`escaped'", " ", "q32", .)   // Replace space with _q32
    
    // Return the escaped string
    return local escaped_string = "`escaped'"
end

