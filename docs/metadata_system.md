# RegiStream Metadata System

## Overview

RegiStream v2.0.0 introduces a unified metadata tracking system using a single YAML file that works for both Stata and Python.

---

## Architecture

### Single Source of Truth: `datasets.csv`

**Location:** `~/.registream/autolabel_keys/datasets.csv`

**Purpose:**
- Track all downloaded datasets
- Store version, schema, and download information
- Enable offline version checking
- Detect file modifications
- Work across Stata and Python

**Format:**
```yaml
# RegiStream Dataset Metadata
# Auto-generated - tracks all downloaded datasets
# Readable from both Stata and Python

datasets:
  scb_variables_eng:
    version: "latest"
    schema: "1.0"
    downloaded: "2025-10-18T17:30:45Z"
    source: "api"
    file_size: 124567  # bytes - fast integrity check

  scb_variables_swe:
    version: "latest"
    schema: "1.0"
    downloaded: "2025-10-18T17:31:12Z"
    source: "api"
    file_size: 128934

  custom_variables_eng:
    # User-created dataset - minimal tracking
    schema: "1.0"
    source: "custom"
```

---

## Behavior Rules

### Rule 1: Dataset Found in `datasets.csv` ✅

**When:** Dataset exists in YAML metadata file

**What Happens:**
1. Load metadata (version, schema, download date, file size)
2. Check CSV file size
   - **If size matches:** All good, proceed
   - **If size differs:** Show warning but continue

**Example Warning (size mismatch):**
```
⚠ Warning: Dataset scb_variables_eng may have been modified
  Expected size: 124567 bytes
  Actual size:   125000 bytes

  This could indicate:
  • Custom modification
  • File corruption
  • Incomplete download

  To restore official version:
    1. Delete the file: rm ~/.registream/autolabel_keys/scb_variables_eng.*
    2. Re-run: autolabel variables ..., domain(scb) lang(eng)
```

### Rule 2: Dataset NOT in `datasets.csv` ⚠️

**When:** Dataset file exists but no metadata entry

**What Happens:**
1. Show informational warning
2. Continue with schema validation
3. If schema passes → works fine!
4. If schema fails → error and exit

**Example Warning (no metadata):**
```
ℹ Dataset scb_variables_eng not found in metadata tracking

  This could be:
  • Custom/user-created dataset
  • Pre-installed dataset without metadata
  • Manually copied file from another system

  Schema validation will still run to ensure compatibility.

  To download official version with full metadata:
    1. Delete existing file
    2. Re-run autolabel to download from API
```

### Rule 3: Schema Validation ALWAYS Runs ✅

**When:** Every time a dataset is loaded

**What:**
- Check required columns exist
- Verify Schema 1.0 format (not 0.5)
- Ensure compatibility with RegiStream v2.0.0

**Why:**
- Works offline
- Works for custom datasets
- Prevents incompatibility errors

**Example Error (Schema 0.5 detected):**
```
ERROR: Dataset uses Schema 0.5 (incompatible)

  Column 'variable' found (Schema 0.5 format)
  RegiStream v2.0.0 requires 'variable_name' (Schema 1.0)

  Action required:
    • Re-download from API to get Schema 1.0
    • Or downgrade to RegiStream v1.0.1
```

---

## Use Cases

### Use Case 1: Official API Download

**Scenario:** User downloads dataset from RegiStream API

**Flow:**
1. User runs: `autolabel variables age, domain(scb) lang(eng)`
2. CSV downloaded from API
3. **Metadata created in `datasets.csv`:**
   ```yaml
   scb_variables_eng:
     version: "latest"
     schema: "1.0"
     downloaded: "2025-10-18T17:30:45Z"
     source: "api"
     file_size: 124567
   ```
4. DTA created from CSV (Stata only)
5. Future runs: No download, uses existing file

### Use Case 2: Custom Dataset

**Scenario:** User creates their own `my_variables_eng.csv`

**Flow:**
1. User creates CSV with Schema 1.0 format
2. User runs: `autolabel variables age, domain(my) lang(eng)`
3. **No metadata created** (custom dataset)
4. Schema validation runs → passes if Schema 1.0
5. Works perfectly!

**Warning shown:**
```
ℹ Dataset my_variables_eng not found in metadata tracking
  This appears to be a custom dataset.
  Schema validation will still run.
```

### Use Case 3: Modified Official Dataset

**Scenario:** User downloads official dataset, then edits CSV manually

**Flow:**
1. Dataset downloaded with metadata
2. User edits CSV (adds/removes rows)
3. File size changes
4. Next run: **Warning shown** (size mismatch)
5. User decides:
   - **Keep custom version:** Ignore warning, continue
   - **Restore official:** Delete file, re-download

### Use Case 4: MONA/Offline System

**Scenario:** User pre-downloads all datasets with internet, then goes offline

**Flow:**
1. **Online:** Download all datasets
2. `datasets.csv` created with all metadata
3. **Go offline** (no internet)
4. `autolabel` still works:
   - Reads metadata from `datasets.csv` ✅
   - No API calls needed ✅
   - Version info available ✅
   - Schema validation runs ✅

### Use Case 5: Copying Datasets Between Systems

**Scenario:** User copies dataset files from one system to another

**Flow:**
1. Copy CSV files to new system
2. **Option A:** Copy `datasets.csv` too
   - Full metadata preserved ✅
   - Version info available ✅
3. **Option B:** Don't copy `datasets.csv`
   - Warning shown ⚠️
   - Schema validation still runs ✅
   - Works if schema matches ✅

---

## Reading Metadata from Console

### Check Specific Dataset

```stata
* Future feature - read metadata from Stata console
autolabel version scb_variables_eng
```

**Output:**
```
Dataset: scb_variables_eng
  Version:    latest
  Schema:     1.0
  Downloaded: 2025-10-18T17:30:45Z
  Source:     api
  File size:  124567 bytes
  Status:     ✓ File size matches (no modifications detected)
```

### List All Tracked Datasets

```stata
* Future feature - list all datasets
autolabel version
```

**Output:**
```
Tracked Datasets:

  scb_variables_eng
    Version: latest | Schema: 1.0 | Downloaded: 2025-10-18

  scb_variables_swe
    Version: latest | Schema: 1.0 | Downloaded: 2025-10-18

  scb_values_eng
    Version: latest | Schema: 1.0 | Downloaded: 2025-10-18

Total: 3 datasets tracked
```

---

## Python Integration

### Reading Metadata in Python

```python
import yaml

def get_dataset_metadata(domain, type, lang):
    """Read dataset metadata from datasets.csv"""
    import os

    registream_dir = os.path.expanduser("~/.registream")
    yaml_file = f"{registream_dir}/autolabel_keys/datasets.csv"

    if not os.path.exists(yaml_file):
        return None

    with open(yaml_file) as f:
        data = yaml.safe_load(f)

    dataset_key = f"{domain}_{type}_{lang}"
    return data.get("datasets", {}).get(dataset_key)

# Usage
meta = get_dataset_metadata("scb", "variables", "eng")
if meta:
    print(f"Version: {meta['version']}")
    print(f"Schema: {meta['schema']}")
    print(f"Downloaded: {meta['downloaded']}")
else:
    print("Dataset not found in metadata (custom or missing)")
```

### Creating Metadata in Python

```python
def store_dataset_metadata(domain, type, lang, version, schema, csv_file):
    """Store dataset metadata after download"""
    import os
    import yaml
    from datetime import datetime

    registream_dir = os.path.expanduser("~/.registream")
    yaml_file = f"{registream_dir}/autolabel_keys/datasets.csv"
    dataset_key = f"{domain}_{type}_{lang}"

    # Get file size
    file_size = os.path.getsize(csv_file) if os.path.exists(csv_file) else 0

    # Load existing or create new
    if os.path.exists(yaml_file):
        with open(yaml_file) as f:
            data = yaml.safe_load(f) or {}
    else:
        data = {"datasets": {}}

    # Add/update dataset
    if "datasets" not in data:
        data["datasets"] = {}

    data["datasets"][dataset_key] = {
        "version": version,
        "schema": schema,
        "downloaded": datetime.utcnow().isoformat() + "Z",
        "source": "api",
        "file_size": file_size
    }

    # Write back
    with open(yaml_file, 'w') as f:
        f.write("# RegiStream Dataset Metadata\n")
        f.write("# Auto-generated - tracks all downloaded datasets\n")
        f.write("# Readable from both Stata and Python\n\n")
        yaml.dump(data, f, default_flow_style=False)
```

---

## File Structure

```
~/.registream/
├── config.yaml                          # User configuration (no dataset metadata)
└── autolabel_keys/
    ├── datasets.csv                     # METADATA - source of truth
    ├── scb_variables_eng.csv            # Data (Stata + Python)
    ├── scb_variables_eng.dta            # Data (Stata binary)
    ├── scb_variables_swe.csv
    ├── scb_variables_swe.dta
    ├── scb_values_eng.csv
    ├── scb_values_eng.dta
    └── custom_variables_eng.csv         # Custom dataset (no metadata)
```

---

## Migration from v1.0.1

### Legacy Datasets (No Metadata)

**Problem:** Users upgrading from v1.0.1 have datasets without metadata

**Solution:** Legacy detection triggers re-download

**Flow:**
1. User upgrades to v2.0.0
2. Legacy dataset exists (no `datasets.csv` entry)
3. **Legacy prompt shown:**
   ```
   Legacy Dataset Detected - Re-download Required

   This dataset was downloaded with v1.0.1 (Schema 0.5)
   and is incompatible with v2.0.0 (Schema 1.0).

   Type 'yes' to re-download:
   ```
4. User types `yes`
5. Old file deleted, new file downloaded
6. Metadata created in `datasets.csv`
7. Future runs: No prompt!

---

## Metadata Fields

### Required Fields (All Datasets)

- **`version`**: Dataset version (e.g., "latest", "v20251014")
- **`schema`**: Schema version (e.g., "1.0")
- **`source`**: Source of dataset ("api", "custom", "unknown")

### Optional Fields (API Downloads)

- **`downloaded`**: ISO 8601 timestamp of download
- **`file_size`**: File size in bytes (for integrity check)

---

## Benefits of This System

✅ **Cross-Platform**: Same YAML for Stata and Python
✅ **Offline Compatible**: Metadata stored locally, no API needed
✅ **Custom Dataset Friendly**: Works without metadata if schema matches
✅ **Modification Detection**: File size check catches changes
✅ **Human Readable**: YAML is easy to read and edit
✅ **Machine Readable**: Easy to parse programmatically
✅ **Portable**: Copy YAML + CSV together to another system
✅ **Version Aware**: Always know what version is installed
✅ **Schema Validation**: Always enforced regardless of metadata

---

## Future Enhancements

### Planned Features

1. **Update Checking**: Compare installed version vs latest from API
2. **Batch Update Command**: `autolabel update` downloads all newer versions
3. **Metadata Console**: `autolabel version [dataset]` shows info
4. **Checksum Validation**: MD5/SHA256 instead of file size
5. **Source Tracking**: Track which API host dataset came from

---

## FAQ

**Q: What if I delete `datasets.csv`?**
A: Datasets still work! You'll see warnings about missing metadata, but schema validation ensures compatibility.

**Q: Can I edit `datasets.csv` manually?**
A: Yes, but be careful with YAML syntax. It's auto-generated, so manual edits may be overwritten on next download.

**Q: What if file size changes but content is the same?**
A: Shouldn't happen in practice. If it does, warning is harmless - just informational.

**Q: Do custom datasets need metadata?**
A: No! Custom datasets work fine without metadata. Schema validation ensures compatibility.

**Q: Can I use datasets from v1.0.1 with v2.0.0?**
A: No - Schema 0.5 vs 1.0 are incompatible. Legacy detection will prompt you to re-download.

**Q: Does this work offline?**
A: Yes! Metadata is stored locally. No internet needed after initial download.

**Q: Can I share datasets between users?**
A: Yes! Copy CSV + metadata entry from `datasets.csv`. Or just copy CSV (schema validation still works).

---

**Status:** ✅ Implemented in RegiStream v2.0.0
**Updated:** 2025-10-18
