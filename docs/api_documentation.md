# RegiStream API Documentation

**Version:** 1.2
**Last Updated:** 2025-11-01
**Status:** Production Ready ✅

---

## Table of Contents

1. [Overview](#overview)
2. [Base URL](#base-url)
3. [API v1 Endpoints](#api-v1-endpoints)
4. [Legacy Routes](#legacy-routes)
5. [Response Formats](#response-formats)
6. [Error Handling](#error-handling)
7. [Cache Strategy](#cache-strategy)
8. [Examples](#examples)

---

## Overview

RegiStream provides a REST API for accessing Swedish registry metadata including variable labels and value labels from Statistics Sweden (SCB) and other data providers.

**Key Features:**
- ✅ Smart version management (latest, versioned, legacy)
- ✅ Bulk update checking (JSON, CSV & Stata formats)
- ✅ Stata-optimized `format=stata` parameter for reliable parsing
- ✅ Intelligent error messages with suggestions
- ✅ Flexible storage backends (local, Google Drive, S3, etc.)
- ✅ 100% backward compatible with v1.0.1 Stata package

**⚡ Performance Optimizations (v1.1):**
- **`GET /api/v1/stata/heartbeat`** - Combined telemetry + version check (1 request instead of 2)
- **`GET /api/v1/datasets/check_updates?datasets=...`** - URL params instead of POST body (simpler, cacheable)
- **`POST /api/v1/telemetry`** - Universal telemetry logging for all platforms

---

## Base URL

**Production:** `https://registream.org`
**Local Development:** `http://localhost:5000`

---

## API v1 Endpoints

### Dataset Downloads

Download dataset files (ZIP format containing CSV data).

#### Download Latest Version

```
GET /api/v1/datasets/{domain}/{type}/{lang}
```

**Parameters:**
- `domain` - Dataset domain (e.g., `scb`)
- `type` - File type: `variables`, `value_labels`, or `values` (alias)
- `lang` - Language code (e.g., `eng`, `swe`)

**Returns:** ZIP file

**Example:**
```bash
curl -O https://registream.org/api/v1/datasets/scb/variables/eng
```

---

#### Download Specific Version

```
GET /api/v1/datasets/{domain}/{type}/{lang}/{version}
```

**Parameters:**
- `version` - Version number (e.g., `20251018`), `latest`, or `legacy`

**Returns:** ZIP file

**Examples:**
```bash
# Latest version
curl -O https://registream.org/api/v1/datasets/scb/variables/eng/latest

# Specific version
curl -O https://registream.org/api/v1/datasets/scb/variables/eng/20251018

# Legacy schema 0.5
curl -O https://registream.org/api/v1/datasets/scb/variables/eng/legacy
```

**Response Headers:**
```
Content-Type: application/zip
X-Dataset-Domain: scb
X-Dataset-Type: variables
X-Dataset-Language: eng
X-Dataset-Version: 20251018
X-Dataset-Requested-Version: latest
Cache-Control: public, max-age=86400
```

---

### Dataset Information

Get metadata about available datasets without downloading.

#### List All Datasets

```
GET /api/v1/datasets
```

**Returns:** JSON

**Example Response:**
```json
{
  "datasets": [
    {
      "domain": "scb",
      "name": "Statistics Sweden",
      "provider": "Statistics Sweden (Statistiska centralbyrån)",
      "available_languages": ["eng", "swe"],
      "available_types": ["variables", "value_labels"]
    }
  ],
  "total": 1
}
```

---

#### Get Dataset Info

```
GET /api/v1/datasets/{domain}
```

**Returns:** JSON

**Example:**
```bash
curl https://registream.org/api/v1/datasets/scb | jq .
```

**Response:**
```json
{
  "domain": "scb",
  "name": "Statistics Sweden",
  "provider": "Statistics Sweden (Statistiska centralbyrån)",
  "available_languages": ["eng", "swe"],
  "available_types": ["variables", "value_labels"],
  "schema_version": "1.0"
}
```

---

#### Get Latest Version Info (No Download)

```
GET /api/v1/datasets/{domain}/{type}/{lang}/latest/info
GET /api/v1/datasets/{domain}/{type}/{lang}/latest/info?format=stata
```

**Query Parameters:**
- `format` (optional) - Response format: `json` (default) or `stata`

**Returns:** Version information in requested format

**Example (JSON):**
```bash
curl https://registream.org/api/v1/datasets/scb/variables/eng/latest/info
```

**Response (JSON):**
```json
{
  "version": "20251101",
  "schema": "1.0",
  "domain": "scb",
  "type": "variables",
  "lang": "eng",
  "status": "ok",
  "language": "eng",
  "filename": "scb_variables_eng_v20251101.zip",
  "download_url": "/api/v1/datasets/scb/variables/eng/latest"
}
```

**Example (Stata format):**
```bash
curl "https://registream.org/api/v1/datasets/scb/variables/eng/latest/info?format=stata"
```

**Response (Stata format):**
```
version=20251101
schema=1.0
domain=scb
type=variables
lang=eng
status=ok
```

**Content-Type:** `text/plain; charset=utf-8` (Stata format)

**Use Case:** Check what version you would get before downloading. Use `format=stata` for reliable parsing in Stata without regex.

---

### Version Checking

Check for dataset updates without downloading files.

#### Check Updates (Bulk) - GET Format ⭐ NEW

```
GET /api/v1/datasets/check_updates?datasets={dataset_list}
GET /api/v1/datasets/check_updates?datasets={dataset_list}&format=stata
```

**Purpose:** Check for updates via URL parameters (simpler, cacheable, optimized for Stata)

**Query Parameters:**
- `datasets` (required) - Dataset list (see formats below)
- `format` (optional) - Response format: `csv` (default for GET) or `stata`

**Parameter Formats (two supported):**

**New format (recommended):**
- Format: `domain:type:lang:version;domain:type:lang:version`
- Colon (`:`) separates fields within each dataset
- Semicolon (`;`) separates datasets
- Example: `scb:variables:eng:20251014;scb:value_labels:eng:20251014`

**Old format (backward compatible):**
- Format: `domain;type;lang;version|domain;type;lang;version`
- Semicolon (`;`) separates fields within each dataset
- Pipe (`|`) separates datasets
- Example: `scb;variables;eng;20251014|scb;value_labels;eng;unknown`

**Returns:** CSV format with headers

**Example (new format):**
```bash
curl "https://registream.org/api/v1/datasets/check_updates?datasets=scb:variables:eng:20251014;scb:value_labels:eng:20251014&format=stata"
```

**Example (old format):**
```bash
curl "https://registream.org/api/v1/datasets/check_updates?datasets=scb;variables;eng;20251014|scb;value_labels;eng;unknown"
```

**Response (CSV):**
```csv
domain,type,lang,current_version,latest_version,update_available,available_for_download,message
scb,variables,eng,20251014,20251101,1,1,Update available: 20251014 → 20251101
scb,value_labels,eng,unknown,20251101,1,1,Dataset found with version 20251101. Re-download to get proper metadata.
```

**Content-Type:** `text/csv; charset=utf-8` (when `format=stata`)

**Stata Example (new format):**
```stata
* Build URL with datasets (new colon-separated format)
local datasets "scb:variables:eng:20251014;scb:value_labels:eng:20251014"
local url "https://registream.org/api/v1/datasets/check_updates?datasets=`datasets'&format=stata"

* Single GET request - no POST body needed!
tempfile resp
shell curl -s "`url'" > "`resp'"

* Import and check
import delimited using "`resp'", clear
list if update_available == 1
```

**Benefits:**
- ⚡ Simpler than POST (no request body)
- 🔄 Cacheable (GET requests)
- 📝 Easier to construct in Stata
- 🚀 Better performance
- ✅ Reliable parsing with `format=stata`

---

#### Check Updates (Bulk) - JSON Format

```
POST /api/v1/datasets/check_updates
Content-Type: application/json
```

**Request Body:**
```json
{
  "datasets": [
    {
      "domain": "scb",
      "type": "variables",
      "lang": "eng",
      "version": "20251014",
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
      "current_version": "20251014",
      "latest_version": "20251014",
      "available_for_download": true,
      "update_available": false,
      "message": "Already on latest version."
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
  "updates_available": 1
}
```

**cURL Example:**
```bash
curl -X POST https://registream.org/api/v1/datasets/check_updates \
  -H "Content-Type: application/json" \
  -d '{
    "datasets": [
      {
        "domain": "scb",
        "type": "variables",
        "lang": "eng",
        "version": "unknown",
        "schema": "1.0"
      }
    ]
  }'
```

---

#### Check Updates (Bulk) - CSV Format ⭐

```
POST /api/v1/datasets/check_updates?format=csv
Content-Type: text/csv
```

**Request Body (CSV):**
```csv
domain,type,lang,version,schema
scb,variables,eng,20251014,1.0
scb,values,eng,unknown,1.0
who,variables,eng,unknown,1.0
```

**Response (CSV):**
```csv
domain,type,lang,current_version,latest_version,update_available,available_for_download,message
scb,variables,eng,20251014,20251014,0,1,Already on latest version.
scb,value_labels,eng,unknown,20251014,1,1,Dataset found with version 20251014. Re-download to get proper metadata.
who,variables,eng,unknown,,0,0,Custom dataset not available in catalog.
```

**Response Headers:**
```
Content-Type: text/csv
Content-Disposition: attachment; filename=update_check.csv
X-Total-Checked: 3
X-Updates-Available: 1
```

**Note:** Booleans are represented as integers (`0` = false, `1` = true) for easy Stata processing.

**Stata Example:**
```stata
* Create CSV request
tempfile req resp
file open fh using "`req'", write replace
file write fh "domain,type,lang,version,schema" _n
file write fh "scb,variables,eng,unknown,1.0" _n
file close fh

* Send request
shell curl -s -X POST --data-binary @"`req'" \
    "https://registream.org/api/v1/datasets/check_updates?format=csv" > "`resp'"

* Import and process
import delimited using "`resp'", clear
if update_available[1] == 1 {
    display "Update available: " message[1]
}
```

---

### Version Management

Get version information and manifests.

#### Get Versions Manifest

```
GET /api/v1/versions
```

**Returns:** `versions.json` file if exists

---

#### Get Domain Versions

```
GET /api/v1/versions/{domain}
```

**Returns:** JSON with version information for domain

---

#### Get Latest Version Number

```
GET /api/v1/versions/{domain}/latest
```

**Example:**
```bash
curl https://registream.org/api/v1/versions/scb/latest
```

**Response:**
```json
{
  "domain": "scb",
  "latest_version": "20251018"
}
```

---

#### Get Stata Package Version

```
GET /api/v1/stata/version
GET /api/v1/stata/version?format=stata
```

**Query Parameters:**
- `format` (optional) - Response format: `json` (default) or `stata`

**Returns:** Current Stata package version number

**Example (JSON):**
```bash
curl https://registream.org/api/v1/stata/version
```

**Response (JSON):**
```json
{
  "version": "2.0.1"
}
```

**Example (Stata format):**
```bash
curl "https://registream.org/api/v1/stata/version?format=stata"
```

**Response (Stata format):**
```
version=2.0.1
```

**Content-Type:** `text/plain; charset=utf-8` (Stata format)

**Purpose:** Allows Stata package to check if a newer version is available

**Used By:** `_rs_updates check_package` command in Stata

**Source:** Auto-detected by scanning `data/registream/stata/registream_X.X.X-stata/` directories. Returns highest semantic version found.

**Cache:** 1 hour

**Why this endpoint structure?**
- ✅ Clear separation - Explicit that this is the Stata package version
- ✅ Scalability - Easy to add `/api/v1/python/version`, `/api/v1/r/version` later
- ✅ RESTful - Resource-oriented endpoint structure
- ✅ Filtering - Easier to filter logs, route requests, apply rate limits per package type

---

#### Stata Package Heartbeat ⭐ CRITICAL

```
GET /api/v1/stata/heartbeat
GET /api/v1/stata/heartbeat?format=stata
```

**Purpose:** Consolidated telemetry + update check in a single request (performance optimization)

**Combines:**
- Telemetry logging (silent)
- Package version checking

**Query Parameters:**
- `version` (optional) - Current Stata package version (e.g., "2.0.0")
- `format` (optional) - Response format: `json` (default) or `stata`
- `user_id` (optional) - Anonymous user identifier
- `command` (optional) - Command executed (e.g., "install", "update", "check")
- `platform` (optional) - Platform name (default: "stata")
- `os` (optional) - Operating system (MacOSX, Windows, Unix)
- `platform_version` (optional) - Stata version (e.g., "18.0")
- `timestamp` (optional) - ISO timestamp

**Returns:** Version update information in requested format

**Example (JSON):**
```bash
curl "https://registream.org/api/v1/stata/heartbeat?version=2.0.0&user_id=abc123&command=check&os=MacOSX&platform_version=18.0&timestamp=2025-11-01T12:00:00Z"
```

**Response (JSON):**
```json
{
  "update_available": true,
  "current_version": "2.0.0",
  "latest_version": "2.0.1",
  "status": "ok"
}
```

**Example (Stata format):**
```bash
curl "https://registream.org/api/v1/stata/heartbeat?version=2.0.0&format=stata"
```

**Response (Stata format):**
```
update_available=true
current_version=2.0.0
latest_version=2.0.1
status=ok
```

**Content-Type:** `text/plain; charset=utf-8` (Stata format)

**Features:**
- ⚡ Single HTTP request instead of two separate calls
- 🔇 Telemetry logging is silent (never breaks the response)
- 📊 Records usage analytics in MongoDB
- ⚙️ Works with minimal parameters (graceful degradation)
- ✅ Stata format enables reliable parsing without regex

**Used By:** Stata package v2.0.1+ for efficient update checking

**Replaces:** Dual calls to `POST /api/v1/telemetry` + `GET /api/v1/stata/version`

**Stata Example (Stata format):**
```stata
* Single request for telemetry + version check
local url "https://registream.org/api/v1/stata/heartbeat"
local params "version=2.0.0&user_id=`user_id'&command=check&os=`os'&platform_version=`c(stata_version)'&timestamp=`timestamp'&format=stata"

tempfile resp
shell curl -s "`url'?`params'" > "`resp'"

* Parse key=value format (no regex needed!)
tempname fh
file open `fh' using "`resp'", read text
while r(eof) == 0 {
    file read `fh' line

    * Parse update_available
    if regexm("`line'", "^update_available=(.+)$") {
        local update_available = trim(regexs(1))
    }

    * Parse latest_version
    if regexm("`line'", "^latest_version=(.+)$") {
        local latest_version = trim(regexs(1))
    }
}
file close `fh'

* Check for updates
if "`update_available'" == "true" {
    display "Update available: `latest_version'"
}
```

---

### Telemetry

#### Log Telemetry Event

```
POST /api/v1/telemetry
```

**Purpose:** Log usage analytics from RegiStream packages (all platforms)

**Content-Type:** `application/json`

**Request Body:**
```json
{
  "timestamp": "20 Oct 2025 17:38:19Z",
  "user_id": "1234567890",
  "platform": "stata",
  "version": "2.0.0",
  "command_string": "autolabel variables kon, domain(scb) lang(eng)",
  "os": "MacOSX",
  "platform_version": "18.0"
}
```

**Required Fields:**
- `timestamp` - Client timestamp (ISO or custom format)
- `user_id` - Anonymous user identifier
- `platform` - Platform name (`stata`, `python`, `r`)
- `version` - Package version
- `command_string` - Command executed
- `os` - Operating system (`MacOSX`, `Windows`, `Unix`)
- `platform_version` - Platform version (e.g., Stata version, Python version)

**Response (Success):**
```json
{
  "status": "ok"
}
```

**Response (Error):**
```json
{
  "status": "error",
  "message": "Missing required fields: user_id, version"
}
```

**Server-side Additions:**
- `server_timestamp` - When server received the event
- `user_agent` - HTTP User-Agent header
- `ip_address` - Client IP address

**Storage:** MongoDB `telemetry` collection

**Error Handling:** Returns 200 OK even on errors (telemetry failures should be silent)

**Used By:**
- Stata package (via `/stata/heartbeat` in v2.0.1+)
- Python package (direct POST)
- R package (future)
- Web analytics dashboards

**Python Example:**
```python
import requests

requests.post('https://registream.org/api/v1/telemetry', json={
    'timestamp': '2025-10-23T12:00:00Z',
    'user_id': 'user123',
    'platform': 'python',
    'version': '1.0.0',
    'command_string': 'load_dataset("scb", "variables")',
    'os': 'Unix',
    'platform_version': '3.11.0'
})
```

**Note:** For Stata package v2.0.1+, use `/api/v1/stata/heartbeat` instead for better performance (combines telemetry + version check).

---

## Legacy Routes

These routes maintain 100% backward compatibility with Stata v1.0.1.

### Direct File Downloads

```
GET /data/{filename}
```

**Examples:**
```bash
# Versioned file (recommended)
curl -O https://registream.org/data/scb_variables_eng_v20251018.zip

# Legacy frozen file (schema 0.5)
curl -O https://registream.org/data/scb_variables_eng.zip

# Note: _latest.zip files are optional - use /api/v1/datasets/{domain}/{type}/{lang}/latest instead
# The API auto-detects the latest version from available _vYYYYMMDD.zip files
```

**Cache Headers:**
- `_latest.zip` → `Cache-Control: public, max-age=86400` (24 hours) - if present (optional)
- `_v20251018.zip` → `Cache-Control: public, max-age=31536000, immutable` (1 year)
- Legacy files → `Cache-Control: public, max-age=31536000, immutable` (1 year)

---

### Stata Package Downloads

```
GET /install/stata/{version}/{filename}
GET /install/stata/{filename}
```

Download individual Stata package files (.ado, .sthlp, etc.)

---

```
GET /get_zip/stata/{version}
GET /get_zip/stata
```

Download complete Stata package as ZIP file.

**Example:**
```bash
curl -O https://registream.org/get_zip/stata/latest
```

---

### Smart Download Resolver

```
GET /download/{domain}/{type}/{lang}
GET /download/{domain}/{type}/{lang}/{version}
```

Smart resolver that redirects to actual storage location based on `datasets.yaml` configuration.

**Examples:**
```bash
curl -L https://registream.org/download/scb/variables/eng
curl -L https://registream.org/download/scb/variables/eng/20251018
```

**Returns:** HTTP 302 redirect to actual file location (local, Google Drive, S3, etc.)

---

### Additional Legacy Endpoints

#### Get Dataset Configuration (YAML-based)

```
GET /api/v1/datasets/{domain}/versions
```

List all versions from `datasets.yaml` configuration.

---

#### GitHub Statistics

```
GET /api/github/stats
```

**Returns:**
```json
{
  "stars": 42,
  "updated_at": "2025-10-18T10:30:00Z",
  "repository": "registream/registream"
}
```

---

```
GET /api/github/stars
```

**Returns:**
```json
{
  "stars": 42
}
```

**Cache:** 1 hour

---

## Response Formats

### JSON Endpoints

Return `application/json`:
- `/api/v1/datasets` (info endpoints)
- `/api/v1/datasets/{domain}/...` (without format parameter)
- `/api/v1/datasets/{domain}/{type}/{lang}/latest/info` (default)
- `/api/v1/datasets/check_updates` (POST, default)
- `/api/v1/stata/version` (default)
- `/api/v1/stata/heartbeat` (default)
- `/api/v1/versions/...`
- `/api/github/...`

### Stata Format Endpoints ⭐ NEW

Return `text/plain; charset=utf-8` (key=value format):
- `/api/v1/stata/version?format=stata`
- `/api/v1/stata/heartbeat?format=stata`
- `/api/v1/datasets/{domain}/{type}/{lang}/latest/info?format=stata`

**Format:** Simple key-value pairs, one per line
```
key1=value1
key2=value2
```

**Benefits:**
- ✅ Reliable parsing in Stata (no JSON parser needed)
- ✅ Simple regex patterns work consistently
- ✅ No escaped characters or nested structures
- ✅ Lightweight and fast

### CSV Endpoints

Return `text/csv` or `text/csv; charset=utf-8`:
- `/api/v1/datasets/check_updates?format=csv` (POST)
- `/api/v1/datasets/check_updates?format=stata` (GET or POST)
- `/api/v1/datasets/check_updates` (GET, default is CSV)

**Note:** Both `format=csv` and `format=stata` return CSV for batch operations (multiple records)

### ZIP Endpoints

Return `application/zip`:
- `/api/v1/datasets/{domain}/{type}/{lang}[/{version}]`
- `/data/{filename}`
- `/get_zip/stata/{version}`

### Other Formats

- Stata package files: various MIME types (.ado, .sthlp)
- HTTP redirects: 302 status codes

---

## Error Handling

### Smart Error Messages

All API v1 endpoints return helpful error messages with suggestions.

#### Invalid Domain

**Request:**
```bash
curl https://registream.org/api/v1/datasets/who/variables/eng
```

**Response (404):**
```json
{
  "error": "domain_not_found",
  "message": "Dataset 'who' not found. Available domains: scb",
  "requested_domain": "who",
  "available_domains": ["scb"]
}
```

---

#### Invalid Language

**Request:**
```bash
curl https://registream.org/api/v1/datasets/scb/variables/fre
```

**Response (404):**
```json
{
  "error": "language_not_found",
  "message": "Language 'fre' not available. Did you mean 'eng'? Available languages: eng, swe",
  "requested_language": "fre",
  "available_languages": ["eng", "swe"],
  "suggestion": "eng"
}
```

---

#### Invalid Version

**Request:**
```bash
curl https://registream.org/api/v1/datasets/scb/variables/eng/99999999
```

**Response (404):**
```json
{
  "error": "version_not_found",
  "message": "Version '99999999' not found. Did you mean 'latest'? Closest versions: latest, 20251018, 20251014. All available: latest, 20251018, 20251014, legacy",
  "requested_version": "99999999",
  "requested_file": "scb_variables_eng_v99999999.zip",
  "available_versions": ["latest", "20251018", "20251014", "legacy"],
  "suggestion": "latest",
  "closest_versions": ["latest", "20251018", "20251014"]
}
```

---

#### Invalid File Type

**Request:**
```bash
curl https://registream.org/api/v1/datasets/scb/metadata/eng
```

**Response (400):**
```json
{
  "error": "invalid_file_type",
  "message": "Invalid file type 'metadata'. Available types: variables, value_labels, values",
  "requested_type": "metadata",
  "available_types": ["variables", "value_labels", "values"]
}
```

---

### CSV Format Errors

When using `?format=csv` or `?format=stata`, errors are also returned in CSV format:

```csv
error,message
invalid_request,Request body is empty
```

or

```csv
error,message
server_error,An unexpected error occurred
```

---

### Stata Format Errors

When using `?format=stata` on single-record endpoints, errors are returned in key-value format:

**Example:**
```bash
curl "https://registream.org/api/v1/datasets/scb/variables/xyz/latest/info?format=stata"
```

**Response (404):**
```
status=error
error=language_not_found
message=Language 'xyz' not available. Available languages: eng, swe
requested_language=xyz
available_languages=eng,swe
```

**Content-Type:** `text/plain; charset=utf-8`

**Features:**
- HTTP status codes preserved (404, 400, 500)
- All error fields included (machine-readable)
- Arrays flattened to comma-separated values
- Easy to parse in Stata

---

## Cache Strategy

Optimal caching for performance and freshness.

| File Type | Cache Duration | Header | Reasoning |
|-----------|----------------|--------|-----------|
| `_latest.zip` | 24 hours | `max-age=86400` | Check daily for updates (optional, use API v1 instead) |
| `_v20251018.zip` | 1 year | `max-age=31536000, immutable` | Versioned files never change |
| Legacy files | 1 year | `max-age=31536000, immutable` | Frozen, no longer updated |
| `versions.json` | No cache | `no-cache, must-revalidate` | Always fetch fresh metadata |
| API info endpoints | No cache | `no-cache, must-revalidate` | Always current |
| GitHub stats | 1 hour | `max-age=3600` | Updated every 6 hours |

---

## Examples

### Python

#### List Available Datasets

```python
import requests

response = requests.get('https://registream.org/api/v1/datasets')
datasets = response.json()['datasets']

for ds in datasets:
    print(f"{ds['domain']}: {', '.join(ds['available_languages'])}")
```

---

#### Download Latest Dataset

```python
import requests

url = 'https://registream.org/api/v1/datasets/scb/variables/eng'
response = requests.get(url)

with open('scb_variables.zip', 'wb') as f:
    f.write(response.content)

# Check metadata from headers
print(f"Version: {response.headers.get('X-Dataset-Version')}")
print(f"Domain: {response.headers.get('X-Dataset-Domain')}")
```

---

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
print(f"Checked: {result['checked']}")
print(f"Updates available: {result['updates_available']}")

for update in result['updates']:
    if update['update_available']:
        print(f"Update available: {update['message']}")
```

---

### R

#### List Available Datasets

```r
library(httr)
library(jsonlite)

response <- GET("https://registream.org/api/v1/datasets")
data <- fromJSON(content(response, "text"))

print(data$datasets)
```

---

#### Download and Extract

```r
library(httr)

url <- "https://registream.org/api/v1/datasets/scb/variables/eng"
GET(url, write_disk("scb_variables.zip", overwrite = TRUE))

# Extract
unzip("scb_variables.zip")

# Read CSV
variables <- read.csv("scb_variables_eng.csv")
head(variables)
```

---

### Stata

#### Download Dataset

```stata
* Download latest version
copy "https://registream.org/api/v1/datasets/scb/variables/eng/latest" ///
    "scb_variables.zip", replace

* Unzip and import
unzipfile "scb_variables.zip"
import delimited using "scb_variables_eng.csv", clear
```

---

#### Check Updates (CSV Format)

```stata
* Create request
tempfile req resp
file open fh using "`req'", write replace
file write fh "domain,type,lang,version,schema" _n
file write fh "scb,variables,eng,20251010,1.0" _n
file close fh

* API call
shell curl -s -X POST --data-binary @"`req'" \
    "https://registream.org/api/v1/datasets/check_updates?format=csv" > "`resp'"

* Import results
import delimited using "`resp'", clear

* Check for updates
count if update_available == 1
if r(N) > 0 {
    list domain type current_version latest_version message ///
        if update_available == 1, noobs clean
}
```

---

#### Check Version Before Downloading

```stata
* Check what version we'd get
tempfile info
shell curl -s "https://registream.org/api/v1/datasets/scb/variables/eng/latest/info" > "`info'"

* Parse JSON (simplified - use full JSON parser in production)
file open fh using "`info'", read
file read fh line
di "`line'"
file close fh
```

---

### cURL

#### Download File

```bash
# Download latest
curl -O https://registream.org/api/v1/datasets/scb/variables/eng

# Download specific version
curl -O https://registream.org/api/v1/datasets/scb/variables/eng/20251018

# Download with verbose headers
curl -v -O https://registream.org/api/v1/datasets/scb/variables/eng
```

---

#### Check Updates (JSON)

```bash
curl -X POST https://registream.org/api/v1/datasets/check_updates \
  -H "Content-Type: application/json" \
  -d '{
    "datasets": [
      {
        "domain": "scb",
        "type": "variables",
        "lang": "eng",
        "version": "unknown",
        "schema": "1.0"
      }
    ]
  }' | jq .
```

---

#### Check Updates (CSV)

```bash
# Create CSV request
cat > request.csv << EOF
domain,type,lang,version,schema
scb,variables,eng,unknown,1.0
scb,values,eng,20251014,1.0
EOF

# Send request
curl -X POST --data-binary @request.csv \
  "https://registream.org/api/v1/datasets/check_updates?format=csv"
```

---

## Supported File Types

### Variables
- `variables` - Variable metadata (name, label, type, etc.)

### Value Labels
- `value_labels` - Value label metadata (variable, value, label)
- `values` - Alias for `value_labels` (both work identically)

---

## Supported Languages

### Statistics Sweden (SCB)
- `eng` - English
- `swe` - Swedish

---

## Supported Versions

### Special Version Keywords

- `latest` - Most recent dated version (e.g., resolves to `20251018`)
- `legacy` - Schema 0.5 frozen version (backward compatibility)

### Dated Versions

Format: `YYYYMMDD` (e.g., `20251018`, `20251014`)

---

## Storage Backends

RegiStream supports flexible storage backends via `datasets.yaml` configuration:

- **local** - Server filesystem
- **gdrive** - Google Drive
- **dropbox** - Dropbox shared links
- **s3** - Amazon S3
- **url** - Any direct URL

Files can be moved between storage providers without changing API URLs or client code.

---

## Rate Limiting

Currently no rate limiting is enforced. Please be respectful:
- Don't spam the API with rapid requests
- Cache responses appropriately
- Use bulk endpoints where available

---

## Support

**Documentation:** This file
**Issues:** https://github.com/registream/registream/issues
**Website:** https://registream.org

---

## Changelog

### 2025-11-01 (v1.2) ⭐ Stata Format Support
- **Added** `format=stata` parameter to all key endpoints for reliable Stata parsing
- **Fixed** `/api/v1/stata/heartbeat` - Now supports Stata format (was broken, no update notifications)
- **Fixed** `/api/v1/datasets/.../latest/info` - Now supports Stata format (affects integrity checks)
- **Added** New semicolon-separated format for check_updates: `scb:variables:eng:20251014;scb:values:eng:20251014`
- **Added** Stata format error responses (key-value format)
- **Implemented** Helper functions: `format_stata_keyvalue()` and `format_stata_csv()`
- **Updated** Content-Type headers: `text/plain; charset=utf-8` for key-value, `text/csv; charset=utf-8` for CSV
- **Backward Compatible** - All JSON responses unchanged, old parameter formats still work

### 2025-10-23 (v1.1) ⭐ Performance Optimizations
- **Added** `GET /api/v1/stata/heartbeat` - Consolidated telemetry + version check in one request
- **Added** `GET /api/v1/datasets/check_updates?datasets=...` - URL parameter support for easier Stata integration
- **Implemented** `POST /api/v1/telemetry` - Full telemetry logging with MongoDB storage
- **Updated** Documentation with complete examples for all new endpoints

### 2025-10-19 (v1.0.1)
- Added CSV format support for check_updates endpoint
- Added `/latest/info` endpoint for metadata without download
- Improved error messages with fuzzy matching suggestions

### 2025-10-18 (v1.0)
- Initial API v1.0 release
- Smart version resolution
- Flexible storage backends
- Full backward compatibility with v1.0.1

---

**Implemented by:** Jeffrey Clark
**License:** See repository
**Status:** Production Ready ✅
