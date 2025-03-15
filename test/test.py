#!/usr/bin/env python3

# --- SET PROJECT ROOT 
import os
import sys
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
from python.src import autolabel, lookup
import seaborn as sns
import matplotlib.pyplot as plt
import statsmodels.api as sm


# set custom directory
# os.environ['REGISTREAM_DIR'] = "path/to/your/custom/directory"


if __name__ == "__main__":

    # Load your data
    lisa_df = pd.read_stata(os.path.join(root_dir, 'test/lisa.dta'))

    # Apply the labels and value labels automatically
    lisa_df.autolabel(domain='scb', lang='swe')
    lisa_df.autolabel(label_type='values', domain='scb', lang='swe')



    # Preview the dataset without variable labels
    print(lisa_df.head())

    # Preview the dataset with variable labels
    print(lisa_df.lab.head())

    # Tabulate a variable without value labels
    print(lisa_df.astsni2007.value_counts())

    # Tabulate a variable with value labels
    print(lisa_df.lab.astsni2007.value_counts())


    # make a labeled plot
    sns.scatterplot(data=lisa_df.lab, x='ssyk3', y='ssyk4', hue='astsni2007')
    plt.title("Labeled Plot Example")
    plt.show()

    # lookup a variable
    lookup('astsni2007', domain='scb', lang='swe')


    # --- Regression analysis ---

    # Use lisa_df.rs directly with original column names
    X = lisa_df.lab[['dispinkfam04']]  # This will return a DataFrame with labeled column
    y = lisa_df.lab['dispink04']       # This will return a Series with label as name
    
    X = sm.add_constant(X)
    model = sm.OLS(y, X).fit()
    print(model.summary())

