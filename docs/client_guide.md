# RegiStream Client Guide

**Version:** 2.0.0
**Last Updated:** 2025-10-20
**Status:** Production Ready ✅

This guide is for developers building clients (Stata, Python, R, etc.) that consume the RegiStream API.

---

## Quick Start

### Base URL

```
https://registream.org/api/v1
```

### Basic Download

```bash
# Download latest SCB variables (English)
curl -O https://registream.org/api/v1/datasets/scb/variables/eng

# Download latest SCB value labels (Swedish)
curl -O https://registream.org/api/v1/datasets/scb/value_labels/swe
```

---

## Core Endpoints for Clients

### 1. Download Dataset

```
GET /api/v1/datasets/{domain}/{type}/{lang}
GET /api/v1/datasets/{domain}/{type}/{lang}/{version}
```

**Parameters:**
- `domain` - Dataset domain (currently hosted on API: `scb` for Statistics Sweden)
- `type` - File type: `variables`, `value_labels`, or `values` (alias for `value_labels`)
- `lang` - Language code (currently hosted on API: `eng` for English, `swe` for Swedish)
- `version` - (optional) Version number, `latest` (default), or `legacy`

**Note:** The API currently hosts only `scb` domain with `eng` and `swe` languages. However, RegiStream clients support any domain/language combination via **custom local datasets**. To use custom datasets, place CSV files in `~/.registream/autolabel_keys/` following the naming pattern: `<domain>_<variables|value_labels>_<lang>.csv` (e.g., `my_variables_eng.csv`, `who_value_labels_swe.csv`).

**Returns:** ZIP file containing CSV data

**Response Headers:**
```
X-Dataset-Domain: scb
X-Dataset-Type: variables
X-Dataset-Language: eng
X-Dataset-Version: 20251018
X-Dataset-Requested-Version: latest
Cache-Control: public, max-age=86400
```

---

### 2. Check Version Before Download

```
GET /api/v1/datasets/{domain}/{type}/{lang}/latest/info
```

**Returns:** JSON with version information (no file download)

**Example:**
```bash
curl https://registream.org/api/v1/datasets/scb/variables/eng/latest/info
```

**Response:**
```json
{
  "version": "20251014",
  "schema": "1.0",
  "domain": "scb",
  "type": "variables",
  "language": "eng",
  "filename": "scb_variables_eng_v20251014.zip"
}
```

**Use Case:** Check if you already have the latest version before downloading.

---

### 3. Check for Updates (Bulk)

```
POST /api/v1/datasets/check_updates
```

**Supports two formats:**
- JSON (default)
- CSV (add `?format=csv`)

#### JSON Format

**Request:**
```json
{
  "datasets": [
    {
      "domain": "scb",
      "type": "variables",
      "lang": "eng",
      "version": "20251010",
      "schema": "1.0"
    },
    {
      "domain": "scb",
      "type": "values",
      "lang": "eng",
      "version": "unknown",
      "schema": "1.0"
    }
  ]
}
```

**Response:**
```json
{
  "updates": [
    {
      "domain": "scb",
      "type": "variables",
      "lang": "eng",
      "current_version": "20251010",
      "latest_version": "20251014",
      "available_for_download": true,
      "update_available": true,
      "message": "Update available: 20251010 → 20251014"
    },
    {
      "domain": "scb",
      "type": "value_labels",
      "lang": "eng",
      "current_version": "unknown",
      "latest_version": "20251014",
      "available_for_download": true,
      "update_available": true,
      "message": "Dataset found with version 20251014. Re-download to get proper metadata."
    }
  ],
  "checked": 2,
  "updates_available": 2
}
```

#### CSV Format (Recommended for Stata)

**Request:**
```csv
domain,type,lang,version,schema
scb,variables,eng,20251010,1.0
scb,values,eng,unknown,1.0
```

**Response:**
```csv
domain,type,lang,current_version,latest_version,update_available,available_for_download,message
scb,variables,eng,20251010,20251014,1,1,Update available: 20251010 → 20251014
scb,value_labels,eng,unknown,20251014,1,1,Dataset found with version 20251014. Re-download to get proper metadata.
```

**Note:** Booleans are `0` (false) or `1` (true) for easy Stata processing.

---

## Client Implementation Guide

### Stata Client

#### Download Dataset

```stata
* Download latest
copy "https://registream.org/api/v1/datasets/scb/variables/eng" ///
    "scb_variables.zip", replace

* Unzip and import
unzipfile "scb_variables.zip"
import delimited using "scb_variables_eng.csv", clear
```

#### Check for Updates (CSV Format)

```stata
* Create CSV request
tempfile req resp
file open fh using "`req'", write replace
file write fh "domain,type,lang,version,schema" _n
file write fh "scb,variables,eng,unknown,1.0" _n
file close fh

* API call
shell curl -s -X POST --data-binary @"`req'" \
    "https://registream.org/api/v1/datasets/check_updates?format=csv" > "`resp'"

* Import and check results
import delimited using "`resp'", clear
if update_available[1] == 1 {
    di "Update available: " message[1]
    di "Latest version: " latest_version[1]
}
```

#### Check Version Without Downloading

```stata
* Get version info
tempfile info
shell curl -s "https://registream.org/api/v1/datasets/scb/variables/eng/latest/info" > "`info'"

* Parse response (use JSON parser in production)
file open fh using "`info'", read
file read fh line
di "`line'"
file close fh
```

---

### Python Client

#### Download Dataset

```python
import requests
import zipfile
import io

# Download
url = 'https://registream.org/api/v1/datasets/scb/variables/eng'
response = requests.get(url)

# Check version from headers
version = response.headers.get('X-Dataset-Version')
print(f"Downloaded version: {version}")

# Save ZIP
with open('scb_variables.zip', 'wb') as f:
    f.write(response.content)

# Or extract directly
with zipfile.ZipFile(io.BytesIO(response.content)) as z:
    z.extractall('.')
```

#### Check for Updates

```python
import requests

data = {
    "datasets": [
        {
            "domain": "scb",
            "type": "variables",
            "lang": "eng",
            "version": "20251010",
            "schema": "1.0"
        }
    ]
}

response = requests.post(
    'https://registream.org/api/v1/datasets/check_updates',
    json=data
)

result = response.json()
for update in result['updates']:
    if update['update_available']:
        print(f"Update: {update['message']}")
```

#### Check Version First

```python
import requests

# Get version info without downloading
response = requests.get(
    'https://registream.org/api/v1/datasets/scb/variables/eng/latest/info'
)

info = response.json()
print(f"Latest version: {info['version']}")
print(f"Schema: {info['schema']}")
print(f"Filename: {info['filename']}")

# Only download if needed
if info['version'] != current_version:
    # Download the file
    download_url = f"https://registream.org{info['download_url']}"
    # ... download logic
```

---

### R Client

#### Download Dataset

```r
library(httr)

# Download
url <- "https://registream.org/api/v1/datasets/scb/variables/eng"
response <- GET(url, write_disk("scb_variables.zip", overwrite = TRUE))

# Check version from headers
version <- headers(response)$`x-dataset-version`
cat("Downloaded version:", version, "\n")

# Extract and read
unzip("scb_variables.zip")
variables <- read.csv("scb_variables_eng.csv")
head(variables)
```

#### Check for Updates

```r
library(httr)
library(jsonlite)

data <- list(
  datasets = list(
    list(
      domain = "scb",
      type = "variables",
      lang = "eng",
      version = "20251010",
      schema = "1.0"
    )
  )
)

response <- POST(
  "https://registream.org/api/v1/datasets/check_updates",
  body = data,
  encode = "json"
)

result <- fromJSON(content(response, "text"))
print(result$updates)
```

---

## Data Format

### ZIP Structure

```
scb_variables_eng_v20251014.zip
└── scb_variables_eng.csv
```

### Variables CSV Schema (v1.0)

| Column | Type | Description |
|--------|------|-------------|
| `variable_name` | string | Variable identifier (lowercase) |
| `variable_label` | string | Short description |
| `variable_definition` | string | Detailed definition |
| `variable_unit` | string | Unit of measurement |
| `variable_type` | string | Type: categorical, continuous, text, date, binary |
| `value_label_id` | string | Link to value labels (if categorical) |

### Value Labels CSV Schema (v1.0)

| Column | Type | Description |
|--------|------|-------------|
| `variable_name` | string | Variable identifier |
| `value_label_id` | string | Label set identifier |
| `value_labels_stata` | string | Stata format: `1 "Male" 2 "Female"` |

---

## Version Management

### Version Types

1. **`latest`** - Most recent dated version (e.g., resolves to `20251018`)
2. **Dated versions** - Specific snapshots (e.g., `20251018`, `20251014`)
3. **`legacy`** - Schema 0.5 frozen version (backward compatibility)

### Checking Versions

**Before downloading:**
```
GET /api/v1/datasets/{domain}/{type}/{lang}/latest/info
```

**Bulk check:**
```
POST /api/v1/datasets/check_updates
```

### Storing Version Metadata

After downloading, store metadata locally:

```
{
  "domain": "scb",
  "type": "variables",
  "lang": "eng",
  "version": "20251014",
  "schema": "1.0",
  "downloaded_at": "2025-10-19T10:30:00Z"
}
```

This allows you to check for updates later by sending `version: "20251014"` to the check_updates endpoint.

---

## Error Handling

### HTTP Status Codes

- `200 OK` - Success
- `400 Bad Request` - Invalid parameters
- `404 Not Found` - Dataset doesn't exist
- `500 Server Error` - Server-side error

### Error Response Format

```json
{
  "error": "domain_not_found",
  "message": "Dataset 'who' not found. Available domains: scb",
  "requested_domain": "who",
  "available_domains": ["scb"],
  "suggestion": "scb"
}
```

### Client Error Handling Example

```python
import requests

try:
    response = requests.get(
        'https://registream.org/api/v1/datasets/scb/variables/eng'
    )
    response.raise_for_status()

except requests.exceptions.HTTPError as e:
    if e.response.status_code == 404:
        error_data = e.response.json()
        print(f"Error: {error_data['message']}")
        if 'suggestion' in error_data:
            print(f"Did you mean: {error_data['suggestion']}?")
    else:
        print(f"HTTP error: {e}")

except requests.exceptions.RequestException as e:
    print(f"Request failed: {e}")
```

---

## Caching Strategy

### Client-Side Caching

Clients should respect cache headers:

| File Type | Cache Duration | Strategy |
|-----------|----------------|----------|
| `latest` files | 24 hours | Check daily for updates |
| Versioned files | Indefinite | Never changes, cache forever |
| `legacy` files | Indefinite | Frozen, cache forever |

### Example: Conditional Download

```python
import os
import time
import requests

cache_file = 'scb_variables_eng.zip'
cache_age_hours = 24

def should_download():
    if not os.path.exists(cache_file):
        return True

    age_seconds = time.time() - os.path.getmtime(cache_file)
    age_hours = age_seconds / 3600

    return age_hours > cache_age_hours

if should_download():
    # Download fresh copy
    response = requests.get(
        'https://registream.org/api/v1/datasets/scb/variables/eng'
    )
    with open(cache_file, 'wb') as f:
        f.write(response.content)
else:
    print("Using cached version")
```

---

## Best Practices

### 1. Use Versioned Downloads for Reproducibility

```python
# Good: Pinned version for reproducible research
url = 'https://registream.org/api/v1/datasets/scb/variables/eng/20251014'

# Also good: Latest for current data
url = 'https://registream.org/api/v1/datasets/scb/variables/eng/latest'
```

### 2. Check Version Before Downloading

```python
# Check what version you'd get
info = requests.get('.../{domain}/{type}/{lang}/latest/info').json()

# Only download if different from local version
if info['version'] != local_version:
    # Download...
```

### 3. Handle "Unknown" Versions

When version metadata is missing or corrupt:

```json
{
  "domain": "scb",
  "type": "variables",
  "lang": "eng",
  "version": "unknown",
  "schema": "1.0"
}
```

The API will suggest re-downloading to restore metadata.

### 4. Use CSV Format for Stata

```stata
* CSV is much easier than JSON parsing in Stata
shell curl -X POST --data-binary @request.csv \
    "https://registream.org/api/v1/datasets/check_updates?format=csv" > response.csv

import delimited using response.csv, clear
* Now you can use normal Stata commands
```

### 5. Store Download Metadata

After every download, save:
- Domain, type, language
- Version number
- Schema version
- Download timestamp

This enables smart update checking.

### 6. Use Custom Local Datasets

RegiStream clients support any domain/language combination through custom local datasets. This is useful for:
- Organization-specific data dictionaries
- Custom registry data not hosted on the API
- Internal datasets with your own naming conventions

**File Location:**
- macOS/Linux: `~/.registream/autolabel_keys/`
- Windows: `C:/Users/username/AppData/Local/registream/autolabel_keys/`

**Naming Convention:**
```
<domain>_<type>_<lang>.csv
```

**Examples:**
- `my_variables_eng.csv` - Custom domain "my", English variable labels
- `who_value_labels_swe.csv` - WHO domain, Swedish value labels
- `internal_variables_eng.csv` - Internal organization data

**File Format:**
Follow Schema 1.0 format. For variables CSV:

```csv
variable_name,variable_label,variable_definition,variable_unit,variable_type,value_label_id
age,Age,Age in years,years,continuous,
sex,Sex,Biological sex,,categorical,sex_labels
```

For value_labels CSV:

```csv
variable_name,value_label_id,value_labels_stata
sex,sex_labels,1 "Male" 2 "Female" 3 "Other"
```

**Usage in Stata:**
```stata
* No download needed - uses local file
autolabel variables age sex, domain(my) lang(eng)

* Works the same as API datasets!
autolabel values sex, domain(my) lang(eng)
```

**Note:** Custom datasets work offline and don't require metadata tracking. Schema validation still runs to ensure compatibility.

---

## Type Aliases

For backward compatibility, `values` is an alias for `value_labels`:

```bash
# These are equivalent:
/api/v1/datasets/scb/values/eng
/api/v1/datasets/scb/value_labels/eng
```

Both resolve to the same file: `scb_value_labels_eng_latest.zip`

---

## Development & Testing

### Local Testing

```bash
# Point to local server
export API_HOST="http://localhost:5000"

# Or in Stata
global REGISTREAM_API_HOST "http://localhost:5000"
```

### Test Endpoints

```bash
# Check API is up
curl -I https://registream.org/api/v1/datasets

# Test download
curl -O https://registream.org/api/v1/datasets/scb/variables/eng

# Test version info
curl https://registream.org/api/v1/datasets/scb/variables/eng/latest/info | jq .

# Test update check
curl -X POST https://registream.org/api/v1/datasets/check_updates \
  -H "Content-Type: application/json" \
  -d '{"datasets":[{"domain":"scb","type":"variables","lang":"eng","version":"unknown","schema":"1.0"}]}'
```

---

## Support

- **Full API Reference:** [api_documentation.md](api_documentation.md)
- **Issues:** https://github.com/registream/registream/issues
- **Website:** https://registream.org

---

**Last Updated:** 2025-10-20
**Version:** 2.0.0
