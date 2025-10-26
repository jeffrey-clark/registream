NOTE:  readme.txt template -- do not remove empty entries, but you may
                              add entries for additional authors
------------------------------------------------------------------------------

Package name:   <leave blank>

DOI:  <leave blank>

Title: autolabel: Automating variable and value labeling in Stata

Author 1 name: Jeffrey Clark
Author 1 from: Stockholm University, Stockholm, Sweden
Author 1 email: jeffrey.clark@su.se

Author 2 name: Jie Wen
Author 2 from: Stockholm School of Economics, Stockholm, Sweden
Author 2 email: jie.wen@hhs.se

Author 3 name:
Author 3 from:
Author 3 email:

Author 4 name:
Author 4 from:
Author 4 email:

Author 5 name:
Author 5 from:
Author 5 email:

Help keywords: autolabel

File list: autolabel.ado _autolabel_utils.ado _rs_validate_schema.ado autolabel.sthlp examples.do create_synthetic_scb_data.do examples.log create_synthetic_scb_data.log synthetic_scb_data.dta scb_variables_eng.csv scb_variables_swe.csv scb_value_labels_eng.csv scb_value_labels_swe.csv

Notes: This is a stripped-down Stata Journal submission version of autolabel from RegiStream v2.0.0 schema 1.0. All metadata files are included as CSV files (autolabel converts them to .dta format on first use). Examples use synthetic data (synthetic_scb_data.dta) that can be regenerated using create_synthetic_scb_data.do. To reproduce all examples shown in the paper, run examples.do. SCB metadata is a subset for demonstration in both English and Swedish languages to showcase multilingual support (full collection available at registream.org). Tested with Stata 16.0+.
