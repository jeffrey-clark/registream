#!/usr/bin/env python3

# --- SET PROJECT ROOT 
import os
import sys
import json
import shutil
import zipfile
import datetime
import re
from pathlib import Path

# Find the project root directory dynamically
root_dir = os.path.abspath(__file__)  # Start from the current file's directory

# Traverse upwards until the .project_root file is found or until reaching the system root
while not os.path.exists(os.path.join(root_dir, '.project_root')) and root_dir != '/':
    root_dir = os.path.dirname(root_dir)

# Make sure the .project_root file is found
assert root_dir != '/', "The .project_root file was not found. Make sure it exists in your project root."

sys.path.append(root_dir)

# ---


import pandas as pd
from python import src
from python.src import lookup
import seaborn as sns
import matplotlib.pyplot as plt
import statsmodels.api as sm



if __name__ == "__main__":

    # Load your data
    lisa_df = pd.read_stata(os.path.join(root_dir, 'test/lisa.dta'))

    # Load labels automatically
    lisa_df.rs.autolabel(domain='scb', lang='swe')
    lisa_df.rs.autolabel(label_type='values', domain='scb', lang='swe')

    # Labeled DataFrame usage
    print(lisa_df.rs.head())

    # Direct labeled column access
    print(lisa_df.rs.astsni2007.value_counts())

    # Simple, elegant plotting with labels applied
    import seaborn as sns
    import matplotlib.pyplot as plt

    sns.scatterplot(data=lisa_df.rs, x='ssyk3', y='ssyk4', hue='astsni2007')
    plt.title("Labeled Plot Example")
    plt.show()

    # lookup
    print(lookup('astsni2007', domain='scb', lang='swe'))


    # Use lisa_df.rs directly with original column names
    X = lisa_df.rs[['dispinkfam04']]  # This will return a DataFrame with labeled column
    y = lisa_df.rs['dispink04']       # This will return a Series with label as name
    
    X = sm.add_constant(X)
    model = sm.OLS(y, X).fit()
    print(model.summary())

