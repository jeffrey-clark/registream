# RegiStream Important Limitations

## ⚠️ CRITICAL: String Categorical Variables Lose Original Data

### The Issue

**When you apply value labels to STRING categorical variables, the original string codes are permanently replaced.**

The `autolabel values` command handles two types of categorical variables differently:

**Numeric categorical variables** (e.g., `kon` with values 1, 2):
- Uses Stata's `label define` + `label values` to attach text labels
- **Preserves** original numeric codes (1, 2, etc.)
- Can be re-labeled multiple times without data loss
- Original numeric codes remain accessible for filtering and analysis

**String categorical variables** (e.g., `astsni2007` with values "41200", "85201"):
- Uses Stata's `encode` to convert strings to numeric with labels
- **Replaces** original string codes with sequential integers (1, 2, 3...)
- **Original string data is lost permanently**
- Cannot re-run `autolabel values` without reloading original data

### Example: Data Loss with String Categoricals

```stata
* Original data: astsni2007 is a string variable
list astsni2007 in 1/5
// Output: "41200" "85201" "41200" "47100" "85201"

* Apply value labels
autolabel values astsni2007, domain(scb) lang(eng)

* After encoding: Original string codes are GONE
list astsni2007 in 1/5
// Output: 1 2 1 3 2  (with labels "Construction", "Primary schools", etc.)

* Can no longer filter by original codes!
count if astsni2007 == "41200"  // ERROR! Variable is now numeric

* Cannot re-label in different language without reloading data
autolabel values astsni2007, domain(scb) lang(swe)  // Works but uses wrong codes (1,2,3)
```

### Solution: Use the suffix() Option

To preserve original string data, use the `suffix()` option to create a new labeled variable:

```stata
* Keep original variable, create new labeled version
autolabel values astsni2007, domain(scb) lang(eng) suffix("_lbl")

* Result:
* - astsni2007 (original string codes: "41200", "85201", etc.)
* - astsni2007_lbl (labeled numeric: 1="Construction", 2="Primary schools", etc.)

* Can still filter by original codes
count if astsni2007 == "41200"  // Works!

* And use labeled version for display
tab astsni2007_lbl
```

### Correct Workflows

#### Option 1: Default Behavior (Replace Original)
```stata
* If you don't need original string codes
use mydata, clear
autolabel values, domain(scb) lang(eng)
// String categorical variables are now numeric with labels
// Original string codes are lost
```

#### Option 2: Preserve Original Data
```stata
* Keep original string variables
use mydata, clear
autolabel values, domain(scb) lang(eng) suffix("_lbl")
// Original variables unchanged
// New labeled variables created with "_lbl" suffix
```

#### Option 3: Multiple Languages (Requires Reloading)
```stata
* English version
use mydata, clear
autolabel variables, domain(scb) lang(eng)
autolabel values, domain(scb) lang(eng)
save mydata_eng, replace

* Swedish version (reload original data!)
use mydata, clear  // Must reload to get original string codes
autolabel variables, domain(scb) lang(swe)
autolabel values, domain(scb) lang(swe)
save mydata_swe, replace
```

### Technical Details

**For string categorical variables**, `autolabel values` uses Stata's `encode` function:
1. Creates a numeric copy with sequential codes (1, 2, 3...)
2. Attaches value labels from metadata to the numeric version
3. Drops the original string variable
4. Renames the numeric version to the original name

**For numeric categorical variables**, `autolabel values` uses `label define` + `label values`:
1. Creates value label definition preserving original numeric codes
2. Attaches labels to existing numeric variable
3. Original numeric codes remain unchanged

---

**Last Updated:** 2025-10-20
**Version:** 2.0.0
