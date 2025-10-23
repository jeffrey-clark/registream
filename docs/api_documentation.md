# RegiStream API Documentation

**Version:** 2.0.0
**Last Updated:** 2025-10-20
**Status:** Production Ready

---

## Table of Contents

1. [Overview](#overview)
2. [Base URL](#base-url)
3. [API v1 Endpoints](#api-v1-endpoints)
4. [Legacy Routes](#legacy-routes)
5. [Response Formats](#response-formats)
6. [Error Handling](#error-handling)
7. [Cache Strategy](#cache-strategy)

---

## Overview

RegiStream provides a REST API for accessing Swedish registry metadata including variable labels and value labels from Statistics Sweden (SCB) and other data providers.

**Currently Hosted on API:**
- **Domain:** `scb` (Statistics Sweden / Statistiska centralbyrån)
- **Languages:** `eng` (English), `swe` (Swedish)
- **Types:** `variables` (variable labels), `value_labels` (categorical value labels)

**Note:** While the API currently hosts only SCB datasets, RegiStream clients (Stata, Python, R) support any domain/language combination via custom local datasets. Users can create custom datasets by placing CSV files in `~/.registream/autolabel_keys/` following the naming pattern: `<domain>_<variables|value_labels>_<lang>.csv`

**Key Features:**
- Smart version management (latest, versioned, legacy)
- Bulk update checking (JSON & CSV formats)
- Intelligent error messages with suggestions
- Flexible storage backends (local, Google Drive, S3, etc.)
- 100% backward compatible with v1.0.1 Stata package

**For client implementation examples**, see [client_guide.md](client_guide.md).

---

## Base URL

**Production:** `https://registream.org`
**Local Development:** `http://localhost:5000`

---

## API v1 Endpoints

### Dataset Downloads

#### Download Latest Version

```
GET /api/v1/datasets/{domain}/{type}/{lang}
```

**Parameters:**
- `domain` - Dataset domain (e.g., `scb` for Statistics Sweden)
- `type` - File type: `variables`, `value_labels`, or `values` (alias)
- `lang` - Language code (e.g., `eng` for English, `swe` for Swedish)

**Note:** Currently hosted: `scb` domain with `eng` and `swe` languages only.

**Returns:** ZIP file

**Example:**
```bash
curl -O https://registream.org/api/v1/datasets/scb/variables/eng
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

#### Download Specific Version

```
GET /api/v1/datasets/{domain}/{type}/{lang}/{version}
```

**Parameters:**
- `version` - Version number (e.g., `20251018`), `latest`, or `legacy`

**Examples:**
```bash
# Latest version
curl -O https://registream.org/api/v1/datasets/scb/variables/eng/latest

# Specific version
curl -O https://registream.org/api/v1/datasets/scb/variables/eng/20251018

# Legacy schema 0.5
curl -O https://registream.org/api/v1/datasets/scb/variables/eng/legacy
```

---

### Dataset Information

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

**Returns:** JSON with domain details

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
```

**Returns:** JSON with version information (no file download)

**Response:**
```json
{
  "version": "20251014",
  "schema": "1.0",
  "domain": "scb",
  "type": "variables",
  "language": "eng",
  "filename": "scb_variables_eng_v20251014.zip",
  "download_url": "/api/v1/datasets/scb/variables/eng/latest"
}
```

**Use Case:** Check what version you would get before downloading.

---

### Version Checking

#### Check Updates (JSON Format)

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
    }
  ],
  "checked": 1,
  "updates_available": 0
}
```

---

#### Check Updates (CSV Format)

```
POST /api/v1/datasets/check_updates?format=csv
Content-Type: text/csv
```

**Request Body (CSV):**
```csv
domain,type,lang,version,schema
scb,variables,eng,20251014,1.0
scb,values,eng,unknown,1.0
```

**Response (CSV):**
```csv
domain,type,lang,current_version,latest_version,update_available,available_for_download,message
scb,variables,eng,20251014,20251014,0,1,Already on latest version.
scb,value_labels,eng,unknown,20251014,1,1,Dataset found with version 20251014. Re-download to get proper metadata.
```

**Response Headers:**
```
Content-Type: text/csv
Content-Disposition: attachment; filename=update_check.csv
X-Total-Checked: 2
X-Updates-Available: 1
```

**Note:** Booleans are represented as integers (`0` = false, `1` = true) for easy Stata processing.

---

#### Check Updates (Bulk) - GET Format ⭐ NEW

```
GET /api/v1/datasets/check_updates?datasets={dataset_list}
```

**Purpose:** Check for updates via URL parameters (simpler, cacheable, optimized for Stata)

**Parameter Format:**
- Multiple datasets: `domain;type;lang;version|domain;type;lang;version`
- Pipe (`|`) separates datasets
- Semicolon (`;`) separates fields within each dataset

**Returns:** CSV format (always)

**Example:**
```bash
curl "https://registream.org/api/v1/datasets/check_updates?datasets=scb;variables;eng;20251014|scb;value_labels;eng;unknown"
```

**Response (CSV):**
```csv
domain,type,lang,current_version,latest_version,update_available,available_for_download,message
scb,variables,eng,20251014,20251014,0,1,Already on latest version.
scb,value_labels,eng,unknown,20251014,1,1,Dataset found with version 20251014. Re-download to get proper metadata.
```

**Stata Example:**
```stata
* Build URL with datasets
local datasets "scb;variables;eng;20251014|scb;value_labels;eng;20251014"
local url "https://registream.org/api/v1/datasets/check_updates?datasets=`datasets'"

* Single GET request - no POST body needed!
tempfile resp
copy "`url'" "`resp'", replace

* Import and check
import delimited using "`resp'", clear
list if update_available == 1
```

**Benefits:**
- ⚡ Simpler than POST (no request body)
- 🔄 Cacheable (GET requests)
- 📝 Easier to construct in Stata
- 🚀 Better performance

---

### Version Management

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

**Response:**
```json
{
  "domain": "scb",
  "latest_version": "20251018"
}
```

---

### Stata Package Heartbeat ⭐ NEW

```
GET /api/v1/stata/heartbeat
```

**Purpose:** Consolidated telemetry + update check in a single request (performance optimization)

**Combines:**
- Telemetry logging (silent)
- Package version checking

**Query Parameters:**
- `version` - Current Stata package version (e.g., "2.0.0") - **REQUIRED** (always included in v2.0.0+)
- `user_id` - Anonymous user identifier (optional, only when telemetry enabled)
- `command` - Command executed (e.g., "autolabel lookup scb", "registream update") (optional, only when telemetry enabled)
- `platform` - Platform name (default: "stata") (optional, only when telemetry enabled)
- `os` - Operating system (MacOSX, Windows, Unix) (optional, only when telemetry enabled)
- `platform_version` - Stata version (e.g., "18.0") (optional, only when telemetry enabled)
- `timestamp` - ISO timestamp (optional, only when telemetry enabled)

**Returns:** JSON with version update information

**Example:**
```bash
curl "https://registream.org/api/v1/stata/heartbeat?version=2.0.0&user_id=abc123&command=autolabel%20lookup%20scb&os=MacOSX&platform_version=18.0&timestamp=2025-10-23T12:00:00Z"
```

**Response:**
```json
{
  "status": "ok",
  "update_available": true,
  "latest_version": "2.0.1",
  "current_version": "2.0.0"
}
```

**Features:**
- ⚡ Single HTTP request instead of two separate calls
- 🔇 Telemetry logging is silent (never breaks the response)
- 📊 Records usage analytics in MongoDB
- ⚙️ Works with minimal parameters (graceful degradation)

**Used By:** Stata package v2.0.0+ for efficient update checking

**Replaces:** Dual calls to `POST /api/v1/telemetry` + `GET /api/v1/stata/version`

**Stata Example:**
```stata
* Single request for telemetry + version check
local url "https://registream.org/api/v1/stata/heartbeat"
local params "version=2.0.0&user_id=`user_id'&command=check&os=`os'&platform_version=`c(stata_version)'&timestamp=`timestamp'"

tempfile resp
copy "`url'?`params'" "`resp'", replace

* Parse response for update_available
file open fh using "`resp'", read
file read fh json_response
file close fh
```

**Important Notes:**
- `version` parameter is **REQUIRED** and always included in v2.0.0+ (fixed in v2.0.0 hotfix)
- Other parameters only sent when telemetry is enabled (`telemetry_enabled=true`)
- Update checks cached for 24 hours (uses `last_update_check` timestamp)
- Telemetry sent on every command (no caching)

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
- Stata package (via `/stata/heartbeat` in v2.0.0+)
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

**Note:** For Stata package v2.0.0+, use `/api/v1/stata/heartbeat` instead for better performance (combines telemetry + version check).

---

## Legacy Routes

These routes maintain 100% backward compatibility with Stata v1.0.1.

### Direct File Downloads

```
GET /data/{filename}
```

**Examples:**
```bash
# Latest version
curl -O https://registream.org/data/scb_variables_eng_latest.zip

# Versioned file
curl -O https://registream.org/data/scb_variables_eng_v20251018.zip

# Legacy frozen file (schema 0.5)
curl -O https://registream.org/data/scb_variables_eng.zip
```

**Cache Headers:**
- `_latest.zip` → `max-age=86400` (24 hours)
- `_v20251018.zip` → `max-age=31536000, immutable` (1 year)
- Legacy files → `max-age=31536000, immutable` (1 year)

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

---

### Smart Download Resolver

```
GET /download/{domain}/{type}/{lang}
GET /download/{domain}/{type}/{lang}/{version}
```

Smart resolver that redirects to actual storage location based on `datasets.yaml` configuration.

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
- `/api/v1/datasets/check_updates` (default)
- `/api/v1/versions/...`
- `/api/github/...`

### CSV Endpoints

Return `text/csv`:
- `/api/v1/datasets/check_updates?format=csv`

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

When using `?format=csv`, errors are also returned in CSV format:

```csv
error,message
invalid_request,Request body is empty
```

---

## Cache Strategy

| File Type | Cache Duration | Header | Reasoning |
|-----------|----------------|--------|-----------|
| `_latest.zip` | 24 hours | `max-age=86400` | Check daily for updates |
| `_v20251018.zip` | 1 year | `max-age=31536000, immutable` | Versioned files never change |
| Legacy files | 1 year | `max-age=31536000, immutable` | Frozen, no longer updated |
| `versions.json` | No cache | `no-cache, must-revalidate` | Always fetch fresh metadata |
| API info endpoints | No cache | `no-cache, must-revalidate` | Always current |
| GitHub stats | 1 hour | `max-age=3600` | Updated every 6 hours |

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

## Supported File Types

- `variables` - Variable metadata (name, label, type, etc.)
- `value_labels` - Value label metadata (variable, value, label)
- `values` - Alias for `value_labels`

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

**Client Implementation Guide:** [client_guide.md](client_guide.md)
**Issues:** https://github.com/registream/registream/issues
**Website:** https://registream.org

---

**Last Updated:** 2025-10-20
**Version:** 2.0.0
