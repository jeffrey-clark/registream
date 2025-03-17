"""
RegiStream: Streamline your registry data workflow
"""

# Import and expose only the main components
from .autolabel import (
    autolabel, AutoLabelAccessor, 
    get_variable_labels, set_variable_labels,
    get_value_labels, set_value_labels,
    rename_with_labels, copy_labels, meta_search
)
from .lookup import lookup

# Export these symbols when importing the package
__all__ = ['lookup', 'autolabel']

# Add the methods to pandas DataFrame
import pandas as pd
pd.DataFrame.autolabel = autolabel
pd.DataFrame.get_variable_labels = get_variable_labels
pd.DataFrame.set_variable_labels = set_variable_labels
pd.DataFrame.get_value_labels = get_value_labels
pd.DataFrame.set_value_labels = set_value_labels
pd.DataFrame.rename_with_labels = rename_with_labels
pd.DataFrame.copy_labels = copy_labels
pd.DataFrame.meta_search = meta_search

# Version information
__version__ = "1.0.0"

