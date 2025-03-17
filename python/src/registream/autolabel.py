import ast
import pandas as pd
from .label_fetcher import LabelFetcher
from tqdm import tqdm
import json
import re
import seaborn as sns
import matplotlib.pyplot as plt
from functools import wraps

# Helper for safer JSON parsing
def safe_json_parse(value):
    """Convert string to dictionary safely, using JSON or fallback."""
    # Handle None or empty strings
    if value is None or not isinstance(value, str) or value.strip() == '':
        return {}
        
    try:
        # First try direct JSON loads in case it's already valid JSON
        parsed = json.loads(value)
        return _normalize_dict_keys(parsed)
    except json.JSONDecodeError:
        try:
            # Try converting Python-style dict strings to JSON format
            # Handle both single and double quotes properly
            processed_value = value
            # Replace unescaped single quotes with double quotes, but preserve escaped ones
            processed_value = re.sub(r"(?<!\\)'", '"', processed_value)
            parsed = json.loads(processed_value)
            return _normalize_dict_keys(parsed)
        except json.JSONDecodeError:
            try:
                # Use ast.literal_eval as a fallback for Python literal structures
                parsed = ast.literal_eval(value)
                return _normalize_dict_keys(parsed)
            except (SyntaxError, ValueError):
                # Final fallback: try to handle simple key-value pairs manually
                try:
                    if '{' in value and '}' in value:
                        # Extract content between curly braces
                        content = value.split('{', 1)[1].rsplit('}', 1)[0].strip()
                        if not content:
                            return {}
                            
                        result = {}
                        # Basic key-value extraction
                        parts = content.split(',')
                        for part in parts:
                            if ':' in part:
                                k, v = part.split(':', 1)
                                # Clean up quotes and whitespace
                                k = k.strip().strip('"\'')
                                v = v.strip().strip('"\'')
                                # Try to convert numeric keys to strings for consistency
                                try:
                                    if k.isdigit():
                                        k = str(int(k))
                                    elif k.replace('.', '', 1).isdigit():
                                        k = str(float(k))
                                except (ValueError, TypeError):
                                    pass
                                result[k] = v
                        return result
                except Exception:
                    # If all parsing attempts fail, return empty dict
                    pass
                    
                return {}

def _normalize_dict_keys(obj):
    """
    Recursively normalize dictionary keys to ensure they're strings.
    This helps with numeric keys and nested dictionaries.
    """
    if not isinstance(obj, dict):
        return obj
        
    result = {}
    for k, v in obj.items():
        # Ensure keys are strings
        str_key = str(k)
        
        # Recursively normalize nested dictionaries
        if isinstance(v, dict):
            result[str_key] = _normalize_dict_keys(v)
        elif isinstance(v, list):
            # Handle lists of dictionaries
            result[str_key] = [_normalize_dict_keys(item) if isinstance(item, dict) else item 
                              for item in v]
        else:
            result[str_key] = v
            
    return result

# Store the original pandas methods before any modification
_original_setitem = pd.DataFrame.__setitem__
_original_rename = pd.DataFrame.rename

# Main function to apply labels to a DataFrame
def autolabel(df, label_type='variables', domain='scb', lang='eng', variables="*", verbose=True):
    """
    Apply variable and value labels to a pandas DataFrame.
    
    Parameters:
    -----------
    df : pandas.DataFrame
        The DataFrame to label
    label_type : str, default 'variables'
        Type of labels to apply ('variables' or 'values')
    domain : str, default 'scb'
        The domain to search for variables
    lang : str, default 'eng'
        Language for variable descriptions ('eng' or 'swe')
    variables : list or str, default "*"
        List of variables to label or "*" for all
    verbose : bool, default True
        Whether to print progress information
        
    Returns:
    --------
    pandas.DataFrame
        The original DataFrame with labels applied
        
    Notes:
    ------
    The directory for label files is determined by:
    1. The REGISTREAM_DIR environment variable if set
    2. Default platform-specific location otherwise:
       - Windows: C:\\Users\\<username>\\AppData\\Local\\registream\\autolabel_keys\\
       - macOS/Linux: ~/.registream/autolabel_keys/
    """
    # Initialize the labels in the attrs dictionary if they don't exist
    if 'registream_labels' not in df.attrs:
        df.attrs['registream_labels'] = {'variable_labels': {}, 'value_labels': {}}
    
    # Determine which variables to process
    if variables == "*":
        # Only process variables that are in the DataFrame
        variables_to_process = list(df.columns)
    elif isinstance(variables, list):
        # Only process variables that are in both the list and the DataFrame
        variables_to_process = [var for var in variables if var in df.columns]
    else:
        raise ValueError("variables must be '*' or a list of variable names")
    
    if not variables_to_process:
        if verbose:
            print("No variables to process. Make sure the specified variables exist in the DataFrame.")
        return df
    
    fetcher = LabelFetcher(domain=domain, lang=lang, label_type=label_type)
    csv_path = fetcher.ensure_labels()

    # Read only the necessary columns from the CSV
    labels_df = pd.read_csv(csv_path, delimiter=',', encoding='utf-8', on_bad_lines='skip')
    labels_df.columns = labels_df.columns.str.strip()
    labels_df['variable'] = labels_df['variable'].str.strip()
    
    # Filter to only include variables in the DataFrame
    labels_df = labels_df[labels_df['variable'].isin(variables_to_process)]
    
    if labels_df.empty:
        if verbose:
            print(f"No matching variables found in the {domain} domain for the specified columns.")
        return df

    if label_type == 'variables':
        required_cols = {'variable', 'variable_desc'}
        if not required_cols.issubset(labels_df.columns):
            return df  # Completely silently return without any message

        df.attrs['registream_labels']['variable_labels'] = labels_df.set_index('variable')['variable_desc'].to_dict()
        
        if verbose:
            print(f"\n✓ Applied variable labels to {len(df.attrs['registream_labels']['variable_labels'])} variables\n")

    elif label_type == 'values':
        required_cols = {'variable', 'value_labels'}
        if not required_cols.issubset(labels_df.columns):
            return df  # Completely silently return without any message

        success_count = 0
        error_count = 0
        
        if verbose:                
            # Use tqdm only if verbose is True
            for _, row in tqdm(labels_df.iterrows(), total=len(labels_df), desc="Parsing value labels"):
                var = row['variable']
                val_labels_str = row['value_labels']
                val_dict = safe_json_parse(val_labels_str)
                # Always initialize value labels, even if empty
                df.attrs['registream_labels']['value_labels'][var] = val_dict
                if val_dict:  # If not empty
                    success_count += 1
                else:
                    # Silently count errors but don't print warnings
                    error_count += 1
            
            print(f"\n✓ Applied value labels to {success_count} variables\n")
        else:
            # No progress bar if verbose is False
            for _, row in labels_df.iterrows():
                var = row['variable']
                val_labels_str = row['value_labels']
                val_dict = safe_json_parse(val_labels_str)
                # Always initialize value labels, even if empty
                df.attrs['registream_labels']['value_labels'][var] = val_dict
    
    return df

# Conditional monkey-patching: Only affect DataFrames with registream_labels
def _conditional_setitem(self, key, value):
    """
    Custom __setitem__ that preserves labels only if they exist.
    Works transparently with standard pandas for unlabeled DataFrames.
    """
    # Call the original method first
    _original_setitem(self, key, value)
    
    # Only apply label preservation for DataFrames with registream_labels
    if isinstance(value, pd.Series) and 'registream_labels' in self.attrs:
        source_col = value.name
        
        # Copy variable labels if available
        if source_col and source_col in self.attrs['registream_labels']['variable_labels']:
            self.attrs['registream_labels']['variable_labels'][key] = \
                self.attrs['registream_labels']['variable_labels'][source_col]
        
        # Copy value labels if available
        if source_col and source_col in self.attrs['registream_labels']['value_labels']:
            self.attrs['registream_labels']['value_labels'][key] = \
                self.attrs['registream_labels']['value_labels'][source_col]

def _conditional_rename(self, *args, **kwargs):
    """
    Custom rename that preserves variable and value labels only if they exist.
    Works transparently with standard pandas for unlabeled DataFrames.
    """
    # If DataFrame does not have registream_labels, use standard pandas behavior
    if 'registream_labels' not in self.attrs:
        return _original_rename(self, *args, **kwargs)
    
    # Get the columns mapping
    columns = kwargs.get('columns', None)
    if args and isinstance(args[0], dict):
        columns = args[0]
    
    # Call the original rename method
    result = _original_rename(self, *args, **kwargs)
    
    # Handle MultiIndex columns differently
    if isinstance(result.columns, pd.MultiIndex):
        # Copy the registream_labels to preserve them
        if 'registream_labels' not in result.attrs:
            result.attrs['registream_labels'] = self.attrs['registream_labels'].copy()
        
        # Note: We don't update the mappings for MultiIndex columns
        # but we preserve existing label information
        return result
    
    # Make sure the result has the registream_labels attribute
    if 'registream_labels' not in result.attrs:
        result.attrs['registream_labels'] = self.attrs['registream_labels'].copy()
    
    # If columns is provided and is a dictionary, update label mappings
    if columns and isinstance(columns, dict):
        # Update variable labels using comprehension for efficiency
        result.attrs['registream_labels']['variable_labels'] = {
            columns.get(k, k): v for k, v in self.attrs['registream_labels']['variable_labels'].items()
        }
        
        # Update value labels using comprehension for efficiency
        result.attrs['registream_labels']['value_labels'] = {
            columns.get(k, k): v for k, v in self.attrs['registream_labels']['value_labels'].items()
        }
    
    return result

# Apply the conditional monkey-patching
pd.DataFrame.__setitem__ = _conditional_setitem
pd.DataFrame.rename = _conditional_rename

# Helper function to copy labels when duplicating columns
def _copy_column_labels(df, source_col, target_col):
    """Copy labels from one column to another if present."""
    if 'registream_labels' in df.attrs:
        # Copy variable label if exists
        if source_col in df.attrs['registream_labels']['variable_labels']:
            df.attrs['registream_labels']['variable_labels'][target_col] = \
                df.attrs['registream_labels']['variable_labels'][source_col]
        
        # Copy value labels if exists
        if source_col in df.attrs['registream_labels']['value_labels']:
            df.attrs['registream_labels']['value_labels'][target_col] = \
                df.attrs['registream_labels']['value_labels'][source_col]
    return df

# Function to rename columns while preserving labels
def rename_with_labels(df, columns=None, **kwargs):
    """
    Rename columns while preserving variable and value labels.
    
    Parameters:
    -----------
    df : pandas.DataFrame
        The DataFrame to rename columns in
    columns : dict, optional
        Dictionary mapping old column names to new column names
    **kwargs : dict, optional
        Additional arguments to pass to DataFrame.rename()
        
    Returns:
    --------
    pandas.DataFrame
        DataFrame with renamed columns and preserved labels
    
    Notes:
    ------
    This method is kept for backward compatibility.
    With conditional monkey-patching, standard df.rename() now preserves labels automatically.
    """
    # We can now just use the standard rename method since we've conditionally monkey-patched it
    return df.rename(columns=columns, **kwargs)

# Function to copy labels from one column to another
def copy_labels(df, source_col, target_col):
    """
    Copy variable and value labels from one column to another.
    
    Parameters:
    -----------
    df : pandas.DataFrame
        The DataFrame containing the columns
    source_col : str
        The source column name to copy labels from
    target_col : str
        The target column name to copy labels to
        
    Returns:
    --------
    pandas.DataFrame
        DataFrame with labels copied from source to target column
    """
    # Create a copy only if needed
    result = df.copy()
    _copy_column_labels(result, source_col, target_col)
    return result

# Add a function to get, set, and update variable and value labels
def get_variable_labels(df, columns=None):
    """
    Get variable labels for one or more columns.
    
    Parameters:
    -----------
    df : pandas.DataFrame
        The DataFrame containing the columns
    columns : str, list, or None
        - If str: The name of a single column to get the label for
        - If list: List of column names to get labels for
        - If None: Get labels for all columns that have labels
        
    Returns:
    --------
    str or dict
        - If columns is a string: The label for that column, or None if not found
        - If columns is a list or None: Dictionary mapping column names to their labels
    """
    if 'registream_labels' not in df.attrs:
        return {} if columns is None or isinstance(columns, list) else None
    
    # If columns is None, return all variable labels
    if columns is None:
        return df.attrs['registream_labels']['variable_labels'].copy()
    
    # If columns is a string, return the label for that column
    if isinstance(columns, str):
        return df.attrs['registream_labels']['variable_labels'].get(columns)
    
    # If columns is a list, return a dictionary of labels for those columns
    if isinstance(columns, list):
        return {col: df.attrs['registream_labels']['variable_labels'].get(col) 
                for col in columns if col in df.attrs['registream_labels']['variable_labels']}
    
    # If columns is not a string, list, or None, raise an error
    raise TypeError("columns must be a string, list, or None")


def set_variable_labels(df, labels, label=None):
    """
    Set variable labels for one or more columns.

    Parameters:
    -----------
    df : pandas.DataFrame
        The DataFrame containing the columns
    labels : str, list, or dict
        - If str: The column name to set the label for (requires `label` argument)
        - If list: List of column names to set the same label for (requires `label` argument)
        - If dict: Dictionary mapping column names to labels or callables
    label : str or callable, optional
        The label to set (required if `labels` is a string or list), or a function that 
        takes the current label and returns a new one
    
    Returns:
    --------
    pandas.DataFrame
        The original DataFrame with the updated label(s) (for method chaining)
    """
    # Initialize the registream_labels attribute if it doesn't exist
    if 'registream_labels' not in df.attrs:
        df.attrs['registream_labels'] = {'variable_labels': {}, 'value_labels': {}}

    # If `labels` is a string, treat it as a single variable assignment
    if isinstance(labels, str):
        if label is None:
            raise ValueError("Must provide a `label` when setting a single variable label.")
        
        # Handle callable input for single column
        if callable(label):
            current_label = df.attrs['registream_labels']['variable_labels'].get(labels)
            new_label = label(current_label)
            df.attrs['registream_labels']['variable_labels'][labels] = new_label
        else:
            df.attrs['registream_labels']['variable_labels'][labels] = label
    
    # If `labels` is a list, apply the same label to all columns in the list
    elif isinstance(labels, list):
        if label is None:
            raise ValueError("Must provide a `label` when setting labels for a list of columns.")
        
        for col in labels:
            # Handle callable input for each column in the list
            if callable(label):
                current_label = df.attrs['registream_labels']['variable_labels'].get(col)
                new_label = label(current_label)
                df.attrs['registream_labels']['variable_labels'][col] = new_label
            else:
                df.attrs['registream_labels']['variable_labels'][col] = label
    
    # If `labels` is a dictionary, update multiple columns
    elif isinstance(labels, dict):
        for col, col_label in labels.items():
            # Handle callable input for each column in the dictionary
            if callable(col_label):
                current_label = df.attrs['registream_labels']['variable_labels'].get(col)
                new_label = col_label(current_label)
                df.attrs['registream_labels']['variable_labels'][col] = new_label
            else:
                df.attrs['registream_labels']['variable_labels'][col] = col_label
    else:
        raise TypeError("labels must be a string, list, or dictionary.")

    return df


def get_value_labels(df, columns=None):
    """
    Get value labels for one or more columns.
    
    Parameters:
    -----------
    df : pandas.DataFrame
        The DataFrame containing the columns
    columns : str, list, or None
        - If str: The name of a single column to get the value labels for
        - If list: List of column names to get value labels for
        - If None: Get value labels for all columns that have them
        
    Returns:
    --------
    dict or dict of dicts
        - If columns is a string: The value labels dictionary for that column, or None if not found
        - If columns is a list or None: Dictionary mapping column names to their value labels dictionaries
    """
    if 'registream_labels' not in df.attrs:
        return {} if columns is None or isinstance(columns, list) else None
    
    # If columns is None, return all value labels
    if columns is None:
        return df.attrs['registream_labels']['value_labels'].copy()
    
    # If columns is a string, return the value labels for that column
    if isinstance(columns, str):
        return df.attrs['registream_labels']['value_labels'].get(columns)
    
    # If columns is a list, return a dictionary of value labels for those columns
    if isinstance(columns, list):
        return {col: df.attrs['registream_labels']['value_labels'].get(col) 
                for col in columns if col in df.attrs['registream_labels']['value_labels']}
    
    # If columns is not a string, list, or None, raise an error
    raise TypeError("columns must be a string, list, or None")


def set_value_labels(df, columns, value_labels=None, overwrite=False):
    """
    Set or update value labels for one or more columns.

    Parameters:
    -----------
    df : pandas.DataFrame
        The DataFrame containing the columns.
    columns : str, list, or dict
        - If str: The column name to set/update value labels for (requires `value_labels`).
        - If list: List of column names to set/update the same value labels for (requires `value_labels`).
        - If dict: Dictionary mapping column names to value label dictionaries.
    value_labels : dict, optional
        Dictionary mapping values to labels (required if `columns` is a string or list).
    overwrite : bool, optional
        If True, replaces existing value labels instead of merging/updating. Default is False.

    Returns:
    --------
    pandas.DataFrame
        The original DataFrame with updated value labels (for method chaining).
    
    Raises:
    -------
    TypeError: If columns is not a string, list, or dictionary.
    ValueError: If setting a single column without providing a valid dictionary.
    """

    # Ensure the labels structure exists
    if 'registream_labels' not in df.attrs:
        df.attrs['registream_labels'] = {'variable_labels': {}, 'value_labels': {}}

    # Handle setting or updating value labels
    if isinstance(columns, str):
        if value_labels is None:
            raise ValueError("Must provide `value_labels` when setting for a single column.")
        
        if overwrite:
            df.attrs['registream_labels']['value_labels'][columns] = value_labels
        else:
            current_labels = df.attrs['registream_labels']['value_labels'].get(columns, {})
            df.attrs['registream_labels']['value_labels'][columns] = {**current_labels, **value_labels}

    elif isinstance(columns, list):
        if value_labels is None:
            raise ValueError("Must provide `value_labels` when setting for a list of columns.")
        
        for column in columns:
            if overwrite:
                df.attrs['registream_labels']['value_labels'][column] = value_labels
            else:
                current_labels = df.attrs['registream_labels']['value_labels'].get(column, {})
                df.attrs['registream_labels']['value_labels'][column] = {**current_labels, **value_labels}

    elif isinstance(columns, dict):
        for column, labels in columns.items():
            if overwrite:
                df.attrs['registream_labels']['value_labels'][column] = labels
            else:
                current_labels = df.attrs['registream_labels']['value_labels'].get(column, {})
                df.attrs['registream_labels']['value_labels'][column] = {**current_labels, **labels}

    else:
        raise TypeError("`columns` must be a string, list, or a dictionary when setting value labels.")

    return df

# Add a metadata search method to pandas DataFrame
def meta_search(df, pattern, include_values=False):
    """
    Search for variables in metadata (names and labels) using regex pattern.
    
    Parameters:
    -----------
    df : pandas.DataFrame
        The DataFrame to search in
    pattern : str
        Regex pattern to search for in variable names and labels
    include_values : bool, default False
        Whether to also search in value labels
        
    Returns:
    --------
    None
        Prints search results to console
    """
    # Compile the regex pattern (case insensitive)
    regex = re.compile(pattern, re.IGNORECASE)
    
    # Create a list to store matching variables
    matches = []
    
    # Check if the DataFrame has been labeled
    has_labels = 'registream_labels' in df.attrs
    
    # Get variable labels if available
    variable_labels = {}
    value_labels = {}
    if has_labels:
        variable_labels = df.attrs['registream_labels']['variable_labels']
        value_labels = df.attrs['registream_labels']['value_labels']
    
    # Search in all columns
    for col in df.columns:
        # Check for match in variable name
        name_match = regex.search(col)
        
        # Check for match in variable label (if available)
        label_match = None
        var_label = variable_labels.get(col, '')
        if var_label:
            label_match = regex.search(str(var_label))
        
        # Check for value label matches if requested
        value_matches = []
        if include_values and col in value_labels:
            for val, val_label in value_labels[col].items():
                if regex.search(str(val_label)):
                    value_matches.append(f"{val}: {val_label}")
        
        # If any match is found, add to results
        if name_match or label_match or value_matches:
            matches.append({
                'variable': col,
                'label': var_label,
                'name_match': bool(name_match),
                'label_match': bool(label_match),
                'value_matches': value_matches
            })
    
    # Print results
    if matches:
        print(f"\n{len(matches)} variables found matching '{pattern}':")
        print("-" * 80)
        
        for match in matches:
            var_name = match['variable']
            var_label = match['label']
            
            # Highlight the matching parts in the variable name
            if match['name_match']:
                highlighted_name = regex.sub(lambda m: f"\033[1;32m{m.group(0)}\033[0m", var_name)
            else:
                highlighted_name = var_name
            
            # Print the variable name and label
            if var_label:
                # Highlight the matching parts in the variable label
                if match['label_match']:
                    highlighted_label = regex.sub(lambda m: f"\033[1;32m{m.group(0)}\033[0m", str(var_label))
                else:
                    highlighted_label = var_label
                print(f"• {highlighted_name}: {highlighted_label}")
            else:
                print(f"• {highlighted_name}")
            
            # Print value label matches if any
            if match['value_matches']:
                print("  Value labels:")
                for val_match in match['value_matches'][:3]:  # Show at most 3 value matches
                    highlighted_val = regex.sub(lambda m: f"\033[1;32m{m.group(0)}\033[0m", val_match)
                    print(f"    - {highlighted_val}")
                
                if len(match['value_matches']) > 3:
                    print(f"    - ... and {len(match['value_matches']) - 3} more matches")
        
        print("-" * 80)
    else:
        print(f"\nNo variables found matching '{pattern}'")

# Register the labeled accessor
@pd.api.extensions.register_dataframe_accessor("lab")
class AutoLabelAccessor:
    def __init__(self, pandas_obj):
        self._df = pandas_obj
        # Check if the DataFrame has been labeled
        if 'registream_labels' not in self._df.attrs:
            self._df.attrs['registream_labels'] = {'variable_labels': {}, 'value_labels': {}}
            
        # Apply monkeypatch to make the accessor work with regular Seaborn calls
        self._apply_seaborn_monkeypatch()
        
        # Display mode controls whether to show value labels in the data cells
        # 'variable_only': Only variable labels in headers (default)
        # 'both': Both variable labels in headers and value labels in cells
        self._display_mode = 'variable_only'
    
    def _apply_seaborn_monkeypatch(self):
        """
        Apply a monkeypatch to make standard Seaborn functions automatically apply labels.
        This happens only when this accessor's methods are called.
        """
        try:            
            # Only apply the monkeypatch once per class
            if not hasattr(self.__class__, '_monkeypatched'):
                self.__class__._monkeypatched = True
                
                # Save original plot functions
                original_plot_functions = {}
                
                # Functions to patch - include all common plotting functions
                functions_to_patch = ['scatterplot', 'lineplot', 'barplot', 'boxplot', 
                                    'violinplot', 'stripplot', 'swarmplot', 'countplot',
                                    'histplot', 'kdeplot', 'ecdfplot', 'heatmap',
                                    'relplot', 'lmplot', 'regplot', 'residplot']
                
                # Also patch pandas plot method
                pd_plot = pd.DataFrame.plot
                
                @wraps(pd_plot)
                def wrapped_pd_plot(df, *args, **kwargs):
                    # Check if it was called through a labeled accessor
                    if hasattr(df, '_is_labeled_accessor_call') and df._is_labeled_accessor_call:
                        # Get the accessor that called this method
                        accessor = df._current_accessor
                        
                        # Call the original plotting method
                        ax = pd_plot(df, *args, **kwargs)
                        
                        # Apply axis labels after plotting
                        x = kwargs.get('x', None)
                        y = kwargs.get('y', None)
                        
                        if hasattr(ax, 'set_xlabel') and x in accessor.variable_labels:
                            ax.set_xlabel(accessor.variable_labels[x])
                        
                        if hasattr(ax, 'set_ylabel') and y in accessor.variable_labels:
                            if isinstance(y, str) and y in accessor.variable_labels:
                                ax.set_ylabel(accessor.variable_labels[y])
                        
                        return ax
                    else:
                        # Regular DataFrame, call the original method
                        return pd_plot(df, *args, **kwargs)
                
                # Patch pandas plot method
                pd.DataFrame.plot = wrapped_pd_plot
                
                for func_name in functions_to_patch:
                    if hasattr(sns, func_name):
                        original_func = getattr(sns, func_name)
                        original_plot_functions[func_name] = original_func
                        
                        @wraps(original_func)
                        def wrapped_func(func_name=func_name, *args, **kwargs):
                            orig_func = original_plot_functions[func_name]
                            data = kwargs.get('data', None)
                            
                            # Check if we're given a labeled accessor
                            if data is not None and hasattr(data, '_df') and isinstance(data, AutoLabelAccessor):
                                # Instead of replacing column names, we'll use the original DataFrame
                                # and set up a post-plot function to update axis labels
                                labels_info = {
                                    'variable_labels': data.variable_labels,
                                    'value_labels': data.value_labels
                                }
                                
                                # Get axis parameters
                                x_param = kwargs.get('x', None)
                                y_param = kwargs.get('y', None)
                                hue_param = kwargs.get('hue', None)

                                # Create a copy of the DataFrame for plotting
                                df_with_values = data._df.copy()
                                
                                # Smart handling of value labels - only apply to categorical variables
                                # For x-axis in scatter/line plots, often we want to keep the original values
                                for col, val_dict in labels_info['value_labels'].items():
                                    # Skip the x-axis variable for scatter/line plots to avoid "Year XXXX" labels
                                    if col == x_param and func_name in ['scatterplot', 'lineplot']:
                                        continue
                                    # Only apply value labels to hue variable for better category display
                                    if col == hue_param or (col != x_param and col != y_param):
                                        if col in df_with_values.columns:
                                            df_with_values[col] = df_with_values[col].astype(str).replace(val_dict)
                                
                                # Replace the accessor with the prepared DataFrame
                                kwargs['data'] = df_with_values
                                
                                # Call the original function
                                ax = orig_func(*args, **kwargs)
                                
                                # After plotting, apply axis labels based on the parameters
                                # Update x-axis label if applicable
                                if x_param and x_param in labels_info['variable_labels']:
                                    ax.set_xlabel(labels_info['variable_labels'][x_param])
                                
                                # Update y-axis label if applicable
                                if y_param and y_param in labels_info['variable_labels']:
                                    ax.set_ylabel(labels_info['variable_labels'][y_param])
                                
                                # Update hue legend if applicable
                                if hue_param and hue_param in labels_info['variable_labels']:
                                    legend = ax.get_legend()
                                    if legend:
                                        # Update legend title
                                        legend.set_title(labels_info['variable_labels'][hue_param])
                                        
                                        # Apply value labels to legend text if available
                                        if hue_param in labels_info['value_labels']:
                                            value_dict = labels_info['value_labels'][hue_param]
                                            for text in legend.get_texts():
                                                original_text = text.get_text()
                                                if original_text in value_dict:
                                                    text.set_text(value_dict[original_text])
                                
                                return ax
                            else:
                                # If it's not a labeled accessor, use the original function
                                return orig_func(*args, **kwargs)
                        
                        # Replace the original Seaborn function
                        setattr(sns, func_name, wrapped_func)
        except ImportError:
            # Seaborn not available, skip monkeypatching
            pass
    
    @property
    def display_mode(self):
        """Get the current display mode."""
        return self._display_mode
        
    @display_mode.setter
    def display_mode(self, mode):
        """Set the display mode for labeled data.
        
        Parameters:
        -----------
        mode : str
            'variable_only': Only show variable labels in column headers (default)
            'both': Show variable labels in headers and value labels in cells
        """
        valid_modes = ['variable_only', 'both']
        if mode not in valid_modes:
            raise ValueError(f"Display mode must be one of {valid_modes}")
        self._display_mode = mode
        
    def show_values(self):
        """Set display mode to show both variable labels and value labels."""
        self.display_mode = 'both'
        return self
        
    def show_variables_only(self):
        """Set display mode to show only variable labels in column headers."""
        self.display_mode = 'variable_only'
        return self
    
    def _apply_value_labels(self, df=None):
        """Return a copy of the DataFrame with value labels applied to categorical variables."""
        df_to_use = df if df is not None else self._df
        df_copy = df_to_use.copy()
        
        # Apply value labels when in 'both' mode
        if self._display_mode == 'both':
            for col, val_dict in self.value_labels.items():
                if col in df_copy.columns and val_dict:  # Only apply if value labels exist
                    df_copy[col] = df_copy[col].astype(str).replace(val_dict)
        
        # Always apply variable labels to column names
        if self.variable_labels:
            df_copy = df_copy.rename(columns=self.variable_labels)
            
        return df_copy
    
    def __repr__(self):
        """Return string representation with labels applied according to display mode."""
        return self._apply_value_labels().__repr__()
        
    def _repr_html_(self):
        """Return HTML representation with labels applied according to display mode."""
        return self._apply_value_labels()._repr_html_()
    
    def head(self, n=5):
        """Return first n rows with labels applied according to display mode."""
        return self._apply_value_labels(self._df.head(n))
        
    def tail(self, n=5):
        """Return last n rows with labels applied according to display mode."""
        return self._apply_value_labels(self._df.tail(n))
        
    def sample(self, n=None, frac=None, replace=False, weights=None, random_state=None, axis=None):
        """Return random sample with labels applied according to display mode."""
        sample_df = self._df.sample(n=n, frac=frac, replace=replace, 
                                    weights=weights, random_state=random_state, axis=axis)
        return self._apply_value_labels(sample_df)
    
    @property
    def variable_labels(self):
        return self._df.attrs['registream_labels']['variable_labels']
    
    @property
    def value_labels(self):
        # Create a wrapper around the value_labels dictionary that returns an empty dict for missing keys
        value_labels_dict = self._df.attrs['registream_labels']['value_labels']
        
        # Create a wrapper class that returns an empty dict for missing keys
        class ValueLabelsDict(dict):
            def __init__(self, original_dict):
                self.original_dict = original_dict
                
            def __getitem__(self, key):
                if key in self.original_dict:
                    return self.original_dict[key]
                return {}  # Return empty dict instead of raising KeyError
                
            def get(self, key, default=None):
                return self.original_dict.get(key, default)
                
            def __contains__(self, key):
                return key in self.original_dict
                
            def items(self):
                return self.original_dict.items()
                
            def keys(self):
                return self.original_dict.keys()
                
            def values(self):
                return self.original_dict.values()
                
            def copy(self):
                return self.original_dict.copy()
        
        return ValueLabelsDict(value_labels_dict)

    def __getattr__(self, attr):
        if attr in self._df.columns:
            series = self._df[attr].copy()
            series.name = self.variable_labels.get(attr, attr)
            if attr in self.value_labels:
                return series.astype(str).replace(self.value_labels[attr])
            return series
        else:
            # Handle special attributes needed by seaborn and pandas
            if attr in ['_is_copy', '_constructor', '_constructor_sliced', '_constructor_expanddim', 
                       '_mgr', '_data', 'dtypes', 'ndim', 'shape', 'values', 'iloc', 'loc']:
                return getattr(self._df, attr)
            
            # For other attributes, try to get them from the DataFrame with labeled columns
            try:
                labeled_df = self._df.rename(columns=self.variable_labels)
                attr_value = getattr(labeled_df, attr)
                return attr_value
            except AttributeError:
                # If the attribute doesn't exist on the labeled DataFrame, try the original
                return getattr(self._df, attr)

    def __iter__(self):
        """Support iteration for compatibility with pandas/seaborn."""
        return iter(self._df)

    def __contains__(self, item):
        """Support 'in' operator for compatibility with pandas/seaborn."""
        return item in self._df

    def keys(self):
        """Support keys() method for compatibility with pandas/seaborn."""
        return self._df.keys()

    def __getitem__(self, key):
        """Support direct column access by name or index."""
        if isinstance(key, str) and key in self._df.columns:
            # Return labeled series for a column name
            return self.__getattr__(key)
        elif isinstance(key, list):
            # Handle lists of column names for regression analysis
            result = pd.DataFrame()
            for col in key:
                if col in self._df.columns:
                    series = self.__getattr__(col)
                    result[series.name] = series
                else:
                    result[col] = self._df[col]
            return result
        # For other types of access, delegate to the DataFrame
        try:
            # Decide whether to apply value labels based on display mode
            if self._display_mode == 'both':
                # Apply value labels but keep original column names
                df_with_values = self._df.copy()
                for col, val_dict in self.value_labels.items():
                    if col in df_with_values.columns:
                        df_with_values[col] = df_with_values[col].astype(str).replace(val_dict)
                return df_with_values[key]
            else:
                return self._df[key]
        except:
            return self._df[key]

    def __call__(self, *args, **kwargs):
        """Support method chaining with plot method or other pandas functions."""
        # Mark the DataFrame for special pandas method handling
        df = self._df.copy()
        df._is_labeled_accessor_call = True
        df._current_accessor = self
        return df

    def __array__(self, dtype=None):
        """Support numpy array protocol for direct use with matplotlib."""
        if dtype is not None:
            return self._df.__array__(dtype)
        return self._df.__array__()

    def __len__(self):
        """Support len() function for compatibility with seaborn."""
        return len(self._df)

    @property
    def columns(self):
        """Return the original column names for compatibility with seaborn."""
        return self._df.columns

    def autolabel(self, label_type='variables', domain='scb', lang='eng', variables="*", verbose=True):
        """
        Apply variable and value labels directly from the accessor.
        
        Parameters:
        -----------
        label_type : str, default 'variables'
            Type of labels to apply ('variables' or 'values')
        domain : str, default 'scb'
            The domain to search for variables
        lang : str, default 'eng'
            Language for variable descriptions ('eng' or 'swe')
        variables : list or str, default "*"
            List of variables to label or "*" for all
        verbose : bool, default True
            Whether to print progress information
        """
        # Use the existing autolabel function but return self for method chaining
        autolabel(self._df, label_type, domain, lang, variables, verbose)
        return self


