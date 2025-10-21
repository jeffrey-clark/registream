cap program drop _rs_validate_schema
program define _rs_validate_schema
	version 16.0
	* Validates that loaded DTA file matches Schema 1.0 requirements
	* Syntax: _rs_validate_schema, type(variables|values)
	syntax , type(string)

	* Check schema version characteristic
	cap local schema_ver : char _dta[schema_version]
	if (_rc == 0 & "`schema_ver'" != "") {
		if ("`schema_ver'" != "1.0") {
			di as error ""
			di as error "Schema version mismatch detected!"
			di as error "  Found: Schema `schema_ver'"
			di as error "  Required: Schema 1.0"
			di as error ""
			di as error "Your cached metadata is outdated."
			di as error "Solution: Delete cached files and re-run autolabel to download fresh metadata."
			di as error ""
			exit 198
		}
	}
	else {
		* No schema version found - assume old Schema 0.5
		di as error ""
		di as error "No schema version found in cached metadata!"
		di as error "This indicates old Schema 0.5 format."
		di as error "RegiStream 2.0.0 requires Schema 1.0."
		di as error ""
		di as error "Solution: Delete cached files and re-run autolabel to download fresh metadata."
		di as error ""
		exit 198
	}

	* Validate required columns based on type
	if ("`type'" == "variables") {
		* Required columns for variables schema
		local required_cols "variable_name variable_label variable_definition variable_unit variable_type value_label_id"

		foreach col of local required_cols {
			cap confirm variable `col'
			if (_rc != 0) {
				di as error ""
				di as error "Schema validation failed: Required column '`col'' not found!"
				di as error "  File type: Variables"
				di as error "  Schema version: 1.0"
				di as error ""
				di as error "Your metadata file is corrupted or incompatible."
				di as error "Solution: Delete cached files and re-run autolabel."
				di as error ""
				exit 198
			}
		}

		* Validate variable_type values (should be: categorical, continuous, text, date, binary)
		cap confirm variable variable_type
		if (_rc == 0) {
			quietly {
				cap count if !inlist(variable_type, "categorical", "continuous", "text", "date", "binary", "")
				if (_rc == 0) {
					local bad_types = r(N)
				}
				else {
					local bad_types = 0
				}
			}
			if (`bad_types' > 0) {
				di as text "Warning: Found `bad_types' rows with non-standard variable_type values"
				di as text "  Expected: categorical, continuous, text, date, binary"
				di as text "  Proceeding anyway..."
			}
		}

		* Basic sanity check: variable_name should not be empty
		quietly count if missing(variable_name) | variable_name == ""
		if (r(N) > 0) {
			di as error ""
			di as error "Data validation failed: Found `r(N)' rows with empty variable_name!"
			di as error "  Metadata file is corrupted."
			di as error ""
			exit 198
		}
	}
	else if ("`type'" == "values") {
		* Required columns for value labels schema
		* Note: value_labels_json, conflict, harmonized_automatically are dropped during DTA conversion
		local required_cols "value_label_id variable_name value_labels_stata"

		foreach col of local required_cols {
			cap confirm variable `col'
			if (_rc != 0) {
				di as error ""
				di as error "Schema validation failed: Required column '`col'' not found!"
				di as error "  File type: Value Labels"
				di as error "  Schema version: 1.0"
				di as error ""
				di as error "Your metadata file is corrupted or incompatible."
				di as error "Solution: Delete cached files and re-run autolabel."
				di as error ""
				exit 198
			}
		}

		* Basic sanity checks
		quietly count if missing(value_label_id)
		if (r(N) > 0) {
			di as error ""
			di as error "Data validation failed: Found `r(N)' rows with empty value_label_id!"
			di as error "  Metadata file is corrupted."
			di as error ""
			exit 198
		}

		* Check that value_labels_stata is not empty
		quietly count if missing(value_labels_stata) | value_labels_stata == ""
		if (r(N) > 0) {
			di as text "Warning: Found `r(N)' rows with empty value_labels_stata"
			di as text "  These rows will be skipped during labeling."
			di as text "  Proceeding anyway..."
		}
	}
	else {
		di as error "Invalid type specified: `type'"
		di as error "Must be 'variables' or 'values'"
		exit 198
	}

	* If we got here, validation passed
	di as text "✓ Schema validation passed (Schema 1.0)"
end
