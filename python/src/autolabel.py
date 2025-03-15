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

# Add the autolabel method to pandas DataFrame
pd.DataFrame.autolabel = autolabel

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



