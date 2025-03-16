import ast
import pandas as pd
from .label_fetcher import LabelFetcher
from tqdm import tqdm

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
            raise KeyError(f"Expected columns {required_cols}, got: {labels_df.columns.tolist()}")

        df.attrs['registream_labels']['variable_labels'] = labels_df.set_index('variable')['variable_desc'].to_dict()
        
        if verbose:
            print(f"\n✓ Applied variable labels to {len(df.attrs['registream_labels']['variable_labels'])} variables\n")

    elif label_type == 'values':
        required_cols = {'variable', 'value_labels'}
        if not required_cols.issubset(labels_df.columns):
            raise KeyError(f"Expected columns {required_cols}, got: {labels_df.columns.tolist()}")

        success_count = 0
        error_count = 0
        
        if verbose:                
            # Use tqdm only if verbose is True
            for _, row in tqdm(labels_df.iterrows(), total=len(labels_df), desc="Parsing value labels"):
                var = row['variable']
                val_labels_str = row['value_labels']
                try:
                    val_dict = ast.literal_eval(val_labels_str)
                    df.attrs['registream_labels']['value_labels'][var] = val_dict
                    success_count += 1
                except Exception as e:
                    print(f"Warning parsing value_labels for '{var}': {e}")
                    error_count += 1
            
            print(f"\n✓ Applied value labels to {success_count} variables ({error_count} errors)\n")
        else:
            # No progress bar if verbose is False
            for _, row in labels_df.iterrows():
                var = row['variable']
                val_labels_str = row['value_labels']
                try:
                    val_dict = ast.literal_eval(val_labels_str)
                    df.attrs['registream_labels']['value_labels'][var] = val_dict
                except Exception:
                    pass  # Silently skip errors when not verbose
    
    return df

# Add a function to rename columns while preserving labels
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
    This method preserves variable and value labels when renaming columns.
    It works like the standard pandas rename method but updates the label
    dictionaries to maintain the connection between columns and their labels.
    """
    # Check if the DataFrame has been labeled
    has_labels = 'registream_labels' in df.attrs
    
    # If no columns specified, just return the DataFrame
    if columns is None:
        return df
    
    # Make a copy of the DataFrame to avoid modifying the original
    result = df.rename(columns=columns, **kwargs)
    
    # If the DataFrame has been labeled, update the label dictionaries
    if has_labels:
        # Get the current label dictionaries
        variable_labels = df.attrs['registream_labels']['variable_labels'].copy()
        value_labels = df.attrs['registream_labels']['value_labels'].copy()
        
        # Update the variable labels dictionary
        for old_name, new_name in columns.items():
            if old_name in variable_labels:
                variable_labels[new_name] = variable_labels.pop(old_name)
        
        # Update the value labels dictionary
        for old_name, new_name in columns.items():
            if old_name in value_labels:
                value_labels[new_name] = value_labels.pop(old_name)
        
        # Update the label dictionaries in the result DataFrame
        result.attrs['registream_labels'] = {
            'variable_labels': variable_labels,
            'value_labels': value_labels
        }
    
    return result

# Add a function to copy labels from one column to another
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
    
    Notes:
    ------
    This function copies both variable and value labels from one column to another.
    It's useful when creating new columns that should inherit labels from existing ones.
    """
    # Check if the DataFrame has been labeled
    if 'registream_labels' not in df.attrs:
        return df
    
    # Make a copy of the DataFrame to avoid modifying the original
    result = df.copy()
    
    # Copy variable label if it exists
    if source_col in result.attrs['registream_labels']['variable_labels']:
        result.attrs['registream_labels']['variable_labels'][target_col] = \
            result.attrs['registream_labels']['variable_labels'][source_col]
    
    # Copy value labels if they exist
    if source_col in result.attrs['registream_labels']['value_labels']:
        result.attrs['registream_labels']['value_labels'][target_col] = \
            result.attrs['registream_labels']['value_labels'][source_col]
    
    return result

# Add functions to get, set, and update variable and value labels
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

# For backward compatibility, keep get_variable_label as an alias
def get_variable_label(df, column):
    """
    Get the variable label for a specific column.
    
    Parameters:
    -----------
    df : pandas.DataFrame
        The DataFrame containing the column
    column : str
        The column name to get the label for
        
    Returns:
    --------
    str or None
        The variable label, or None if not found
    """
    return get_variable_labels(df, column)

def set_variable_label(df, column, label):
    """
    Set the variable label for a specific column.
    
    Parameters:
    -----------
    df : pandas.DataFrame
        The DataFrame containing the column
    column : str
        The column name to set the label for
    label : str or callable
        The label to set, or a function that takes the current label and returns a new one
        
    Returns:
    --------
    pandas.DataFrame
        The original DataFrame with the updated label (for method chaining)
    """
    # Initialize the registream_labels attribute if it doesn't exist
    if 'registream_labels' not in df.attrs:
        df.attrs['registream_labels'] = {'variable_labels': {}, 'value_labels': {}}
    
    # If label is a function, apply it to the current label
    if callable(label):
        current_label = get_variable_label(df, column)
        new_label = label(current_label)
    else:
        new_label = label
    
    # Set the variable label
    df.attrs['registream_labels']['variable_labels'][column] = new_label
    
    return df


def set_variable_labels(df, labels_dict):
    """
    Set variable labels for multiple columns at once.
    
    Parameters:
    -----------
    df : pandas.DataFrame
        The DataFrame containing the columns
    labels_dict : dict
        Dictionary mapping column names to their labels
        
    Returns:
    --------
    pandas.DataFrame
        The original DataFrame with the updated labels (for method chaining)
    """
    # Initialize the registream_labels attribute if it doesn't exist
    if 'registream_labels' not in df.attrs:
        df.attrs['registream_labels'] = {'variable_labels': {}, 'value_labels': {}}
    
    # Set the variable labels for each column in the dictionary
    for column, label in labels_dict.items():
        # If label is a function, apply it to the current label
        if callable(label):
            current_label = get_variable_label(df, column)
            new_label = label(current_label)
        else:
            new_label = label
        
        # Set the variable label
        df.attrs['registream_labels']['variable_labels'][column] = new_label
    
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

# For backward compatibility, keep the original method
def get_value_label(df, column):
    """
    Get the value labels for a specific column.
    
    Parameters:
    -----------
    df : pandas.DataFrame
        The DataFrame containing the column
    column : str
        The column name to get the value labels for
        
    Returns:
    --------
    dict or None
        The value labels dictionary, or None if not found
    """
    return get_value_labels(df, column)

def set_value_labels(df, column, value_labels):
    """
    Set the value labels for a specific column.
    
    Parameters:
    -----------
    df : pandas.DataFrame
        The DataFrame containing the column
    column : str
        The column name to set the value labels for
    value_labels : dict or callable
        Dictionary mapping values to labels, or a function that takes the current 
        value labels dictionary and returns a new one
        
    Returns:
    --------
    pandas.DataFrame
        The original DataFrame with the updated value labels (for method chaining)
    """
    # Initialize the registream_labels attribute if it doesn't exist
    if 'registream_labels' not in df.attrs:
        df.attrs['registream_labels'] = {'variable_labels': {}, 'value_labels': {}}
    
    # If value_labels is a function, apply it to the current value labels
    if callable(value_labels):
        current_value_labels = get_value_labels(df, column) or {}
        new_value_labels = value_labels(current_value_labels)
    else:
        new_value_labels = value_labels
    
    # Set the value labels
    df.attrs['registream_labels']['value_labels'][column] = new_value_labels
    
    return df


def set_value_labels_dict(df, value_labels_dict):
    """
    Set value labels for multiple columns at once.
    
    Parameters:
    -----------
    df : pandas.DataFrame
        The DataFrame containing the columns
    value_labels_dict : dict
        Dictionary mapping column names to their value labels dictionaries
        
    Returns:
    --------
    pandas.DataFrame
        The original DataFrame with the updated value labels (for method chaining)
    """
    # Initialize the registream_labels attribute if it doesn't exist
    if 'registream_labels' not in df.attrs:
        df.attrs['registream_labels'] = {'variable_labels': {}, 'value_labels': {}}
    
    # Set the value labels for each column in the dictionary
    for column, value_labels in value_labels_dict.items():
        # If value_labels is a function, apply it to the current value labels
        if callable(value_labels):
            current_value_labels = get_value_labels(df, column) or {}
            new_value_labels = value_labels(current_value_labels)
        else:
            new_value_labels = value_labels
        
        # Set the value labels
        df.attrs['registream_labels']['value_labels'][column] = new_value_labels
    
    return df




# Store the original __setitem__ method
original_setitem = pd.DataFrame.__setitem__

# Define a custom __setitem__ method that transfers labels when duplicating columns
def custom_setitem(self, key, value):
    # Call the original __setitem__ method
    original_setitem(self, key, value)
    
    # Check if we're copying a column and if the DataFrame has been labeled
    if isinstance(value, pd.Series) and 'registream_labels' in self.attrs:
        # Get the name of the source column
        source_col = value.name
        
        # If the source column has labels, copy them to the new column
        if source_col in self.attrs['registream_labels']['variable_labels']:
            self.attrs['registream_labels']['variable_labels'][key] = \
                self.attrs['registream_labels']['variable_labels'][source_col]
        
        if source_col in self.attrs['registream_labels']['value_labels']:
            self.attrs['registream_labels']['value_labels'][key] = \
                self.attrs['registream_labels']['value_labels'][source_col]

# Replace the __setitem__ method with our custom one
pd.DataFrame.__setitem__ = custom_setitem

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
    import re
    
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
            raise AttributeError(
                "This DataFrame has not been labeled yet. "
                "Please call df.autolabel() first to apply labels."
            )
    
    @property
    def variable_labels(self):
        return self._df.attrs['registream_labels']['variable_labels']
    
    @property
    def value_labels(self):
        return self._df.attrs['registream_labels']['value_labels']

    def __getattr__(self, attr):
        if attr in self._df.columns:
            series = self._df[attr].copy()
            series.name = self.variable_labels.get(attr, attr)
            if attr in self.value_labels:
                return series.astype(str).replace(self.value_labels[attr])
            return series
        else:
            labeled_df = self._df.rename(columns=self.variable_labels)
            attr_value = getattr(labeled_df, attr)
            return attr_value
            
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
        return self._df.__getitem__(key)
    
    @property
    def columns(self):
        """Return the original column names for compatibility with seaborn."""
        return self._df.columns
            
    def __dataframe__(self, nan_as_null=False, allow_copy=True):
        """Support the DataFrame interchange protocol for seaborn plotting."""
        # Create a temporary DataFrame with the original column names preserved
        df_for_plot = self._df.copy()
        
        # Apply value labels (no tqdm needed as it's fast)
        for col, val_dict in self.value_labels.items():
            if col in df_for_plot.columns:
                df_for_plot[col] = df_for_plot[col].astype(str).replace(val_dict)
        
        # Return the DataFrame with original column names preserved
        return df_for_plot.__dataframe__(nan_as_null=nan_as_null, allow_copy=allow_copy)

    def rename(self, columns=None, **kwargs):
        """
        Rename columns while preserving variable and value labels.
        
        Parameters:
        -----------
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
        This method preserves variable and value labels when renaming columns.
        It works like the standard pandas rename method but updates the label
        dictionaries to maintain the connection between columns and their labels.
        """
        return rename_with_labels(self._df, columns=columns, **kwargs)
    
    def meta_search(self, pattern, include_values=False):
        """
        Search for variables in metadata (names and labels) using regex pattern.
        
        Parameters:
        -----------
        pattern : str
            Regex pattern to search for in variable names and labels
        include_values : bool, default False
            Whether to also search in value labels
            
        Returns:
        --------
        None
            Prints search results to console
        """
        meta_search(self._df, pattern, include_values)

    def get_variable_labels(self, columns=None):
        """
        Get variable labels for one or more columns.
        
        Parameters:
        -----------
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
        return get_variable_labels(self._df, columns)
    
    def set_variable_label(self, column, label):
        """
        Set the variable label for a specific column.
        
        Parameters:
        -----------
        column : str
            The column name to set the label for
        label : str or callable
            The label to set, or a function that takes the current label and returns a new one
            
        Returns:
        --------
        pandas.DataFrame
            The original DataFrame with the updated label (for method chaining)
        """
        return set_variable_label(self._df, column, label)
    
    def get_value_labels(self, columns=None):
        """
        Get value labels for one or more columns.
        
        Parameters:
        -----------
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
        return get_value_labels(self._df, columns)
    
    def set_value_labels(self, column, value_labels):
        """
        Set the value labels for a specific column.
        
        Parameters:
        -----------
        column : str
            The column name to set the value labels for
        value_labels : dict or callable
            Dictionary mapping values to labels, or a function that takes the current 
            value labels dictionary and returns a new one
            
        Returns:
        --------
        pandas.DataFrame
            The original DataFrame with the updated value labels (for method chaining)
        """
        return set_value_labels(self._df, column, value_labels)

    def set_variable_labels(self, labels_dict):
        """
        Set variable labels for multiple columns at once.
        
        Parameters:
        -----------
        labels_dict : dict
            Dictionary mapping column names to their labels
            
        Returns:
        --------
        pandas.DataFrame
            The original DataFrame with the updated labels (for method chaining)
        """
        return set_variable_labels(self._df, labels_dict)

    def get_variable_label(self, column):
        """
        Get the variable label for a specific column.
        
        Parameters:
        -----------
        column : str
            The column name to get the label for
        
        Returns:
        --------
        str or None
            The variable label, or None if not found
        """
        return get_variable_label(self._df, column)

    def get_value_label(self, column):
        """
        Get the value labels for a specific column.
        
        Parameters:
        -----------
        column : str
            The column name to get the value labels for
        
        Returns:
        --------
        dict or None
            The value labels dictionary, or None if not found
        """
        return get_value_label(self._df, column)






