# RegiStream Important Limitations

## ⚠️ CRITICAL: Cannot Run `autolabel values` Multiple Times on Same Dataset

### The Issue

**You CANNOT run `autolabel values` more than once on the same dataset.**

Once you apply value labels using `autolabel values`, the string categorical variables are **encoded** to numeric variables with value labels attached. After encoding:

1. The original string variable is **dropped**
2. A new numeric variable with the same name is created
3. Value labels are attached to the numeric variable

If you try to run `autolabel values` again (e.g., to switch languages), it will **FAIL** because:
- The variables are now numeric (not string)
- The condition `substr(type[i], 1, 3) == "str"` will be FALSE
- The encoding logic only works on string variables

### Example of What NOT to Do

```stata
* Load data
use mydata, clear

* This works fine
autolabel values, domain(scb) lang(eng)

* This will FAIL! Variables are already encoded
autolabel values, domain(scb) lang(swe)  // ERROR!
```

### Correct Workflows

#### Option 1: Choose One Language
```stata
* Choose either English OR Swedish, not both
use mydata, clear
autolabel variables, domain(scb) lang(eng)
autolabel values, domain(scb) lang(eng)
```

#### Option 2: Separate Datasets for Each Language
```stata
* English version
use mydata, clear
autolabel variables, domain(scb) lang(eng)
autolabel values, domain(scb) lang(eng)
save mydata_eng, replace

* Swedish version (start fresh!)
use mydata, clear  // Reload original data
autolabel variables, domain(scb) lang(swe)
autolabel values, domain(scb) lang(swe)
save mydata_swe, replace
```

#### Option 3: Variables Only (No Values)
```stata
* You CAN switch variable labels multiple times
use mydata, clear
autolabel variables, domain(scb) lang(eng)
autolabel variables, domain(scb) lang(swe)  // This is OK!

* Just don't use autolabel values twice
```

### Why This Happens

The `autolabel values` command uses Stata's `encode` function which:
1. Creates a numeric copy of the string variable
2. Attaches value labels to the numeric version
3. Drops the original string variable
4. Renames the numeric version to the original name

After this transformation, the variable is permanently changed from string to numeric. Re-running `autolabel values` expects string variables, so it fails.

### Technical Details

The condition that filters which variables to process is:
```stata
if ((variable_type[i] == "categorical") & (substr(type[i], 1, 3) == "str")) {
    // Apply value labels
}
```

After encoding:
- `variable_type[i] == "categorical"` ✓ Still TRUE
- `substr(type[i], 1, 3) == "str"` ✗ NOW FALSE (type is "long" or "byte")

So no variables pass the filter, and the command fails.

---

**Last Updated:** 2025-10-20
**Version:** 2.0.0
