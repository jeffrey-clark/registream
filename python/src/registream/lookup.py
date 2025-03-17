import pandas as pd
import ast
from .label_fetcher import LabelFetcher

def lookup(variables, domain='scb', lang='eng'):
    """
    Look up detailed information about variables.
    
    Parameters:
    -----------
    variables : list or str
        List of variable names to look up
    domain : str, default 'scb'
        The domain to search for variables
    lang : str, default 'eng'
        Language for variable descriptions ('eng' or 'swe')
        
    Returns:
    --------
    None, prints information to console
    
    Notes:
    ------
    The directory for label files is determined by:
    1. The REGISTREAM_DIR environment variable if set
    2. Default platform-specific location otherwise:
       - Windows: C:\\Users\\<username>\\AppData\\Local\\registream\\autolabel_keys\\
       - macOS/Linux: ~/.registream/autolabel_keys/
    """
    # If a single string is passed, convert to list
    if isinstance(variables, str):
        variables = [variables]
        
    # Get variable information
    fetcher = LabelFetcher(domain=domain, lang=lang, label_type='variables')
    var_csv_path = fetcher.ensure_labels()
    var_df = pd.read_csv(var_csv_path, delimiter=',', encoding='utf-8', on_bad_lines='skip')
    var_df.columns = var_df.columns.str.strip()
    var_df['variable'] = var_df['variable'].str.strip()
    
    # Get value labels information
    val_fetcher = LabelFetcher(domain=domain, lang=lang, label_type='values')
    val_csv_path = val_fetcher.ensure_labels()
    val_df = pd.read_csv(val_csv_path, delimiter=',', encoding='utf-8', on_bad_lines='skip')
    val_df.columns = val_df.columns.str.strip()
    val_df['variable'] = val_df['variable'].str.strip()
    
    # Create a lookup DataFrame with the requested variables
    lookup_vars = pd.DataFrame({'variable': variables})
    
    # Merge with variable information
    merged_df = pd.merge(lookup_vars, var_df, on='variable', how='left')
    
    # Track missing variables
    missing_vars = []
    
    # Display information for each variable
    for i, row in merged_df.iterrows():
        var_name = row['variable']
        
        # Check if variable was found
        if pd.notna(row.get('variable_desc', pd.NA)):
            # Print separator
            print("-" * 90)
            
            # Print variable name in bold (using ANSI escape codes)
            print(f"| VARIABLE:     \033[1m{var_name}\033[0m")
            
            # Print variable label
            var_desc = row.get('variable_desc', 'No description available')
            print(f"| LABEL:        {var_desc}")
            
            # Print definition with wrapping
            definition = row.get('definition', 'No definition available')
            if pd.notna(definition):
                # Split definition into chunks of 70 characters
                first_line = True
                remaining_def = definition
                while remaining_def:
                    if first_line:
                        print(f"| DEFINITION:   {remaining_def[:70].strip()}")
                        first_line = False
                    else:
                        print(f"|               {remaining_def[:70].strip()}")
                    remaining_def = remaining_def[70:] if len(remaining_def) > 70 else ""
            else:
                print("| DEFINITION:   No definition available")
            
            # Get value labels for this variable
            val_row = val_df[val_df['variable'] == var_name].iloc[0] if not val_df[val_df['variable'] == var_name].empty else None
            
            if val_row is not None and pd.notna(val_row.get('value_labels', pd.NA)):
                try:
                    # Parse value labels string into a dictionary
                    val_dict = ast.literal_eval(val_row['value_labels'])
                    
                    # Display up to 8 value labels
                    max_display = 8
                    items = list(val_dict.items())
                    
                    if items:
                        for j, (code, label) in enumerate(items[:max_display]):
                            # Truncate label if too long
                            if len(f"{code}: {label}") > 70:
                                label = label[:65] + "..."
                            
                            if j == 0:
                                print(f"| VALUE LABELS: {code}: {label}")
                            else:
                                print(f"|               {code}: {label}")
                        
                        # Show count of remaining labels
                        if len(items) > max_display:
                            remaining = len(items) - max_display
                            print(f"|               (and {remaining} more labels)")
                except Exception as e:
                    pass  # Silently skip value labels that can't be parsed
            
            # Print separator
            print("-" * 90)
        else:
            missing_vars.append(var_name)
    
    # Display missing variables
    if missing_vars:
        print("-" * 90)
        print(f"\033[91mThe following variables were not found in {domain}:\033[0m")
        for var in missing_vars:
            print(f"\033[91m   • {var}\033[0m")
        print("-" * 90) 