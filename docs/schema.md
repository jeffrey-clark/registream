# RegiStream Metadata Schema Documentation

**Current Version:** Schema v1.0
**RegiStream Software:** v2.0.0+
**Last Updated:** 2025-10-20
**Status:** Implemented & Production-Ready

---

## Overview

This document describes the RegiStream metadata schema format, including variable and value label specifications, validation system, and migration guidance.

RegiStream metadata files are distributed as semicolon-delimited CSV files with UTF-8 encoding. The schema defines two file types:
- **Variables files**: Describe dataset variables with labels, definitions, units, and types
- **Value labels files**: Provide category labels for categorical variables in dual formats (JSON and Stata-optimized)

### Version History

| Schema Version | RegiStream Version | Release Date | Status |
|----------------|-------------------|--------------|--------|
| 0.5 | v1.0.0 - v1.0.1 | 2024-10-13 | Legacy (frozen) |
| 1.0 | v2.0.0+ | 2025-01-14 | Current (stable) |

### Key Improvements in Schema v1.0

1. **Consistent Naming**: All columns use `snake_case` with underscores
2. **No Stata Conflicts**: Column names don't conflict with Stata reserved keywords
3. **Dual Label Formats**: JSON for modern tools, optimized format for Stata parsing
4. **Canonical Variable Types**: Clear, standardized type system
5. **Zero-Padded Chunks**: Proper lexicographic sorting of chunked CSV files

---

## Variables Schema

### File Format
- **Delimiter**: Semicolon (`;`)
- **Encoding**: UTF-8
- **Chunking**: Zero-padded numbers (e.g., `_0000.csv`, `_0001.csv`)

### Columns

| Column Name | Type | Description | Example |
|-------------|------|-------------|---------|
| `variable_name` | string | Variable identifier (lowercase in DTA) | `kon`, `jurform`, `inkomst` |
| `variable_label` | string | Short descriptive label | `Sex`, `Legal form`, `Income` |
| `variable_definition` | string | Detailed explanation | `Gender of the person. Binary classification.` |
| `variable_unit` | string | Unit of measurement (if applicable) | `SEK`, `kg`, `%` |
| `variable_type` | string | Canonical variable type | `categorical`, `continuous`, `text`, `date`, `binary` |
| `value_label_id` | integer | Link to value labels (if applicable) | `1`, `2`, `42` |

### Variable Types

| Type | Description | Has Value Labels? | Example Variables |
|------|-------------|-------------------|-------------------|
| `categorical` | Discrete categories | Yes | Sex, Legal form, Country code |
| `continuous` | Numeric measurements | No | Income, Age, Temperature |
| `text` | Free-form strings | No | Names, Addresses, Comments |
| `date` | Temporal data | No | Birth date, Registration date |
| `binary` | Boolean/indicators | Yes (0/1) | Is active, Has children |

### Example Row
```csv
variable_name,variable_label,variable_definition,variable_unit,variable_type,value_label_id
kon,Sex,Gender of the person.,,categorical,2
inkomst,Income,Annual income in Swedish Kronor,SEK,continuous,
```

---

## Value Labels Schema

### File Format
- **Delimiter**: Semicolon (`;`)
- **Encoding**: UTF-8
- **Chunking**: Zero-padded numbers (e.g., `_0000.csv`, `_0001.csv`)

### Columns

| Column Name | Type | Description | Purpose |
|-------------|------|-------------|---------|
| `value_label_id` | integer | Unique identifier linking to variables | Merging |
| `variable_name` | string | Variable this label set applies to | Reference |
| `value_labels_json` | string | Proper JSON format with double quotes | Python, R, APIs, docs |
| `value_labels_stata` | string | Space-separated quoted pairs | Stata parsing (fast) |
| `conflict` | integer | Harmonization conflict flag (0/1) | Metadata |
| `harmonized_automatically` | integer | Auto-harmonization flag (0/1) | Metadata |

### Dual Label Format Rationale

**Why keep both formats?**

1. **JSON Format** (`value_labels_json`):
   - Standard format for modern tools
   - Easy to parse in Python, R, JavaScript
   - Good for documentation and APIs
   - Example: `{"K": "Woman", "M": "Man", "1": "Man"}`

2. **Stata Format** (`value_labels_stata`):
   - Optimized for Stata's `word` function
   - No JSON parsing needed (Stata 16 lacks native parser)
   - Faster and more reliable
   - Example: `"K" "Woman" "M" "Man" "1" "Man"`

**Performance Note:** Stata string manipulation is slow. JSON parsing would require complex regex operations and is error-prone with quotes and special characters. The `value_labels_stata` format allows instant extraction using Stata's built-in `word` function.

### Example Row
```csv
value_label_id,variable_name,value_labels_json,value_labels_stata,conflict,harmonized_automatically
2,kon,"{""K"": ""Woman"", ""M"": ""Man"", ""1"": ""Man"", ""2"": ""Woman""}","""K"" ""Woman"" ""M"" ""Man"" ""1"" ""Man"" ""2"" ""Woman""",1,1
```

### Parsing Examples

**Python:**
```python
import json
import pandas as pd

df = pd.read_csv('scb_value_labels_eng.csv', sep=';')
labels = json.loads(df.loc[df['variable_name'] == 'kon', 'value_labels_json'].iloc[0])
# Result: {'K': 'Woman', 'M': 'Man', ...}
```

**Stata:**
```stata
local str_value = value_labels_stata[`i']
local nwords : word count `str_value'

forval j = 1(2)`nwords' {
    local k = `j'+1
    local code : word `j' of `str_value'
    local label : word `k' of `str_value'
    * code = "K", label = "Woman"
}
```

---

## File Naming Convention

### Pattern
```
{domain}_{dataset_type}_{language}_v{version}_{chunk}.csv
```

### Examples
```
scb_variables_eng_v20250114_0000.csv
scb_variables_eng_v20250114_0001.csv
scb_value_labels_eng_v20250114_0000.csv
scb_value_labels_eng_v20250114_0001.csv
...
scb_value_labels_eng_v20250114_0011.csv
```

### Zero-Padding Rules
- Padding width = number of digits in total chunk count
- Examples:
  - 2 chunks: `_0.csv`, `_1.csv`
  - 10 chunks: `_00.csv` through `_09.csv`
  - 100 chunks: `_000.csv` through `_099.csv`

### Why Zero-Padding?
Ensures correct lexicographic sorting:
- Correct: `_0000.csv`, `_0001.csv`, `_0010.csv`, `_0100.csv`
- Wrong: `_0.csv`, `_1.csv`, `_10.csv`, `_100.csv` (sorts as 0, 1, 100, 10)

---

## Schema Validation

**Added in:** RegiStream v2.0.0
**Purpose:** Ensure metadata compatibility and provide clear error messages

### How Validation Works

The schema validation system automatically checks that cached metadata files match the expected Schema v1.0 format. This prevents confusing errors when users have old cached data or corrupted files.

#### 1. Schema Version Tracking

Every DTA file generated by RegiStream 2.0.0+ includes a Stata characteristic:

```stata
char _dta[schema_version] "1.0"
```

This characteristic is automatically added when converting CSV to DTA.

#### 2. Automatic Validation

Validation happens automatically in two scenarios:

**a) When creating a new DTA file:**
```stata
* Convert CSV to DTA
import delimited ...
char _dta[schema_version] "1.0"
_rs_validate_schema, type(variables)  // or type(values)
save "`dta_file'", replace
```

**b) When loading an existing DTA file:**
```stata
* DTA already exists, validate it
use "`dta_file'", clear
_rs_validate_schema, type(variables)  // or type(values)
```

#### 3. What Gets Validated

**For Variables Files:**
- Schema version = "1.0"
- Required columns present:
  - `variable_name`
  - `variable_label`
  - `variable_definition`
  - `variable_unit`
  - `variable_type`
  - `value_label_id`
- `variable_name` not empty
- `variable_type` values (warning if non-standard)

**For Value Labels Files:**
- Schema version = "1.0"
- Required columns present:
  - `value_label_id`
  - `variable_name`
  - `value_labels_json`
  - `value_labels_stata`
- `value_label_id` not empty
- `variable_name` not empty
- `value_labels_stata` not empty when JSON exists (warning)

### Common Error Messages

#### Schema Version Mismatch

**Scenario:** User has old Schema 0.5 cached files

**Error:**
```
Schema version mismatch detected!
  Found: Schema 0.5
  Required: Schema 1.0

Your cached metadata is outdated.
Solution: Delete cached files and re-run autolabel to download fresh metadata.
```

#### Missing Schema Version

**Scenario:** DTA file has no schema version characteristic (pre-2.0.0 files)

**Error:**
```
No schema version found in cached metadata!
This indicates old Schema 0.5 format.
RegiStream 2.0.0 requires Schema 1.0.

Solution: Delete cached files and re-run autolabel to download fresh metadata.
```

#### Missing Required Column

**Scenario:** Corrupted or incompatible metadata file

**Error:**
```
Schema validation failed: Required column 'variable_label' not found!
  File type: Variables
  Schema version: 1.0

Your metadata file is corrupted or incompatible.
Solution: Delete cached files and re-run autolabel.
```

### Troubleshooting Validation Errors

If you encounter a schema validation error:

**Option 1: Delete cached files (Recommended)**
```stata
* On Mac/Linux:
! rm -rf ~/.registream/autolabel_keys/*.dta

* On Windows:
! del %USERPROFILE%\AppData\Local\registream\autolabel_keys\*.dta

* Then re-run autolabel
autolabel variables, domain(scb) lang(eng)
```

**Option 2: Use full path override**
```stata
* Create fresh directory
global registream_dir "/path/to/fresh/directory"
autolabel variables, domain(scb) lang(eng)
```

**Option 3: Manual download**
Place fresh CSV files from https://registream.org/data/ in:
- `~/.registream/autolabel_keys/scb_variables_eng/`
- `~/.registream/autolabel_keys/scb_value_labels_eng/`

Then run autolabel - it will detect the folders and build fresh DTA files.

---

## Migration from Schema 0.5 to Schema 1.0

### Column Mapping

**Variables:**
| Schema 0.5 | Schema 1.0 | Notes |
|------------|------------|-------|
| `variable` | `variable_name` | Avoids Stata keyword conflict |
| `variable_desc` | `variable_label` | Clearer naming |
| `definition` | `variable_definition` | Consistent prefix |
| `unit` | `variable_unit` | Consistent prefix |
| `value_type` | `variable_type` | Canonical types |
| `type` | *(removed)* | Stata-specific, not needed |

**Value Labels:**
| Schema 0.5 | Schema 1.0 | Notes |
|------------|------------|-------|
| `variable` | `variable_name` | Consistent with variables schema |
| `value_labels` | `value_labels_json` | Clearer purpose |
| *(none)* | `value_labels_stata` | New: Stata-optimized format |
| `value_labels_str` | *(removed)* | Renamed to `value_labels_stata` |

### Code Changes Required

**RegiStream v2.0.0+ handles Schema 1.0 automatically.** No user action required.

**For custom code:**
```stata
* OLD (Schema 0.5)
gen var_label = variable_desc
replace var_label = variable_desc + " (" + unit + ")" if unit != ""
local str_value = value_labels_str[`i']

* NEW (Schema 1.0)
gen var_label = variable_label
replace var_label = variable_label + " (" + variable_unit + ")" if variable_unit != ""
local str_value = value_labels_stata[`i']
```

---

## Best Practices

### For Metadata Producers

1. **Always zero-pad** chunk numbers based on total chunk count
2. **Use semicolon delimiters** consistently
3. **Validate JSON** in `value_labels_json` column
4. **Keep both formats** in sync (json and stata)
5. **Lowercase variable names** for consistency

### For Metadata Consumers

1. **Let Stata auto-detect** delimiter (don't force `;` if issues)
2. **Use `value_labels_stata`** for label application (faster)
3. **Use `value_labels_json`** for documentation/export
4. **Always use full paths** (not `~`) when setting `$registream_dir`
5. **Check file existence** before processing

### For Stata Package Developers

1. **Don't use `variable` as column name** (Stata keyword)
2. **Standardize on `variable_name`** throughout codebase
3. **Use `_rs_append_csv_files`** for chunk processing
4. **Handle both `;` and `,` delimiters** gracefully
5. **Document schema version** in DTA file characteristics

---

## Performance & File Sizes

### Typical Sizes (SCB English)

| File | Rows | Size (CSV) | Size (DTA) | Chunks |
|------|------|------------|------------|--------|
| `scb_variables_eng` | ~15,000 | 3.9 MB | 7.7 MB | 2 |
| `scb_value_labels_eng` | ~13,000 | 208 MB | 95 MB | 12 |

### Processing Time (on MacBook Pro M1)

| Operation | Time | Notes |
|-----------|------|-------|
| Append variables chunks | <1s | 2 chunks |
| Append value labels chunks | ~15s | 12 chunks, 208MB |
| CSV → DTA conversion (variables) | ~2s | |
| CSV → DTA conversion (value labels) | ~30s | Large file |
| Apply variable labels (100 vars) | <1s | |
| Apply value labels (100 vars) | ~5s | Encoding + replacement |

---

## Developer Reference

### Validation Function: `_rs_validate_schema`

**Location:** `stata/src/_rs_validate_schema.ado`

**Syntax:**
```stata
_rs_validate_schema, type(variables|values)
```

**Parameters:**
- `type(variables)`: Validate variables schema (6 required columns)
- `type(values)`: Validate value labels schema (4 required columns)

**Return Code:**
- `0`: Validation passed
- `198`: Validation failed (with descriptive error message)

**Example Usage:**
```stata
use "`var_filepath_dta'", clear
cap _rs_validate_schema, type(variables)
if (_rc != 0) {
    di as error "Validation failed!"
    exit `=_rc'
}
```

### Quick Reference

**Variables (6 columns):**
```
variable_name, variable_label, variable_definition, variable_unit, variable_type, value_label_id
```

**Value Labels (6 columns):**
```
value_label_id, variable_name, value_labels_json, value_labels_stata, conflict, harmonized_automatically
```

---

## Testing & Validation

### Test Dataset
```stata
* Create sample data
clear
set obs 100

gen str10 kon = ""
replace kon = "M" in 1/50
replace kon = "K" in 51/100

gen str20 jurform = ""
replace jurform = "10" in 1/30
replace jurform = "21" in 31/60
replace jurform = "41" in 61/100

* Apply labels
global registream_dir "/path/to/.registream"
run "stata/src/autolabel.ado"

autolabel variables, domain(scb) lang(eng)
autolabel values, domain(scb) lang(eng)

* Verify
describe kon jurform
tab kon
tab jurform
```

### Expected Output
```
Variable labels:
  kon: Sex
  jurform: Legal form

Value labels:
  kon:
    K -> Woman
    M -> Man

  jurform:
    10 -> Natural persons
    21 -> Simple companies
    41 -> Banking joint stock company
```

---

## Related Documentation

- [stata/development.md](stata/development.md) - Stata development workflows
- [api_documentation.md](api_documentation.md) - API v1 reference
- [client_guide.md](client_guide.md) - Client implementation guide

---

## Support & Contact

- **Issues**: https://github.com/your-repo/registream/issues
- **Documentation**: https://registream.org/docs
- **Schema Version**: Check `schema_version` in DTA file characteristics

---

**End of Documentation**
