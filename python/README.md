# RegiStream Python Package

A Python package for streamlining registry data workflows.

## Installation

```bash
pip install registream
```

## Main Features

### Auto-Labeling

The `autolabel` functionality provides powerful tools for working with labeled data:

- **Pandas Integration**: Add labels directly to pandas DataFrames with the `.autolabel()` method
- **Variable Labels**: Add descriptive labels to your DataFrame columns
- **Value Labels**: Map numeric codes to human-readable categorical values
- **Smart Display**: View your data with human-readable labels instead of raw codes
- **Label Persistence**: Labels stay with your data through operations like filtering and selection

```python
import pandas as pd
import registream

# Load your data
df = pd.read_csv('your_data.csv')

# Add labels to your DataFrame
df.autolabel(domain='scb', lang='eng')

# Access the labeled view of your data
df.lab.head()

# Get all variable labels
var_labels = df.get_variable_labels()

# Get all value labels
val_labels = df.get_value_labels()

# Set custom variable labels
df.set_variable_labels({'column_name': 'My Custom Label'})

# Set custom value labels
df.set_value_labels('column_name', {1: 'Yes', 0: 'No'})

# Search metadata
results = df.meta_search('pattern')
```

### Data Lookup

The `lookup` functionality makes it easy to find and understand registry data:

- **Variable Lookup**: Find detailed information about specific variables
- **Multi-domain Support**: Look up information across different data domains
- **Multilingual**: Get information in different languages (currently supports English and Swedish)

```python
from registream import lookup

# Look up information about specific variables
lookup(['carb', 'random_var', 'yrkarbtyp', 'kaross'], domain='scb', lang='eng')

# Look up a single variable
lookup('carb')
```


## License

BSD 3-Clause License

Copyright (c) 2025, Jeffrey Clark & Jie Wen

See LICENSE file for complete license text. 