# RegiStream

**RegiStream: Streamline Your Register Data Workflow**

## Project Overview

RegiStream is a multi-platform toolkit for working with register data in **Stata, R, and Python**.  
It provides a **consistent framework** to help researchers efficiently process, label, and analyze register data.



## Version Log

| Version  | Stata Status | R Status  | Python Status  | Key Features |
|----------|-------------|-----------|---------------|--------------|
| **1.0.0** | ✅ Released | ⏳ Planned | ✅ Released | `autolabel` and `label` functionality (Schema 0.5) |
| **1.0.1** | ✅ Released  | ❌ Not yet | ✅ Released  | URL migration to registream.org, CSV apostrophe fix (Schema 0.5) |
| **2.0.0** | ✅ Released  | ❌ Not yet | ❌ Not yet  | Major infrastructure upgrade: new registream command, usage tracking system, config system, test suite |


- ✅ = Released
- ⏳ = Planned
- ❌ = Not yet implemented

## Package Updates

### Automatic Update Notifications (Stata v2.0.0+)

RegiStream automatically checks for package updates once every 24 hours in the background:

- **Non-intrusive**: Runs silently before commands, doesn't block execution
- **Smart caching**: Only checks once per day to minimize API calls
- **Persistent notifications**: Update alerts show after each command until you update
- **Semantic versioning**: Only notifies when a newer version is truly available

**Example notification:**
```
------------------------------------------------------------
A new version of RegiStream is available!
  Current version:  1.0.1
  Latest version:   2.0.0

To update, run: registream update
------------------------------------------------------------
```

### Checking for Updates Manually

```stata
* Check if update is available
registream update

* Or using autolabel alias
autolabel update
```

If an update is available, you'll be prompted to install it. The command runs:
```stata
net install registream, from(https://registream.org/stata) replace
```

### Disabling Auto-Update Checks

If you prefer not to receive automatic update notifications:

```stata
registream config, auto_update_check(false)
```

Re-enable later with:

```stata
registream config, auto_update_check(true)
```

### For Offline Users

Auto-update checks respect your `internet_access` setting:

```stata
* Disable all internet access (also disables update checks)
registream config, internet_access(false)
```

## Metadata Schema 1.0 (Current)

RegiStream v2.0.0 introduces support for Metadata Schema 1.0, a clean and consistent format with improved naming and dual-format value labels.

### Variables CSV (6 columns)
```
variable_name, variable_label, variable_definition, variable_unit, variable_type, value_label_id
```

**Columns:**
- `variable_name`: Variable identifier (e.g., `kon`, `jurform`, `inkomst`)
- `variable_label`: Short descriptive label (e.g., "Sex", "Legal form", "Income")
- `variable_definition`: Detailed explanation
- `variable_unit`: Unit of measurement (e.g., "SEK", "kg", "%")
- `variable_type`: Canonical type (`categorical`, `continuous`, `text`, `date`, `binary`)
- `value_label_id`: Link to value labels (if applicable)

### Value Labels CSV (6 columns)
```
value_label_id, variable_name, value_labels_json, value_labels_stata, conflict, harmonized_automatically
```

**Columns:**
- `value_label_id`: Unique identifier for label set
- `variable_name`: Variable this label set applies to
- `value_labels_json`: Proper JSON format (for Python, R, APIs)
- `value_labels_stata`: Space-separated quoted pairs (for Stata's `word()` function)
- `conflict`: Harmonization conflict flag (0/1)
- `harmonized_automatically`: Auto-harmonization flag (0/1)

**Example:**
```csv
2,kon,"{""K"": ""Woman"", ""M"": ""Man""}","""K"" ""Woman"" ""M"" ""Man""",1,1
```

### Key Improvements in Schema 1.0

1. **Self-documenting names**: All columns explicitly named (no ambiguity)
2. **No Stata conflicts**: `variable_name` instead of `variable` (avoids keyword issues)
3. **Dual label formats**:
   - `value_labels_json`: Standard JSON for modern tools
   - `value_labels_stata`: Optimized for Stata (no parsing needed)
4. **Zero-padded chunks**: Files split into chunks like `_0000.csv`, `_0001.csv` for proper sorting
5. **Semicolon delimiters**: Safer for CSV with embedded commas in JSON

### Version Numbering

**RegiStream Software:** v2.0.0 (current)
**Metadata Schema:** v1.0 (current)
**Metadata Content:** v20250114 (date-based, updates frequently)

For complete schema documentation, see [docs/SCHEMA.md](docs/SCHEMA.md)  



## Project Structure

```
registream/
├── .project_root                   # Project root marker
├── README.md                       # Main project documentation
├── LICENSE                         # Project license
├── docs/                           # Documentation
│   ├── development.md              # Development guidelines
│   ├── release_process.md          # Release process documentation
│   └── language-specific/          # Language-specific documentation
│       ├── stata.md                # Stata-specific documentation
│       ├── r.md                    # R-specific documentation
│       └── python.md               # Python-specific documentation
├── stata/                          # Stata implementation
│   ├── src/                        # Stata source code
│   ├── version.json                # Version information for Stata
│   └── export_stata_package.py     # Script to create Stata package
├── r/                              # R implementation
│   ├── src/                        # R source code
│   ├── version.json                # Version information for R
│   └── export_r_package.R          # Script to create R package
├── python/                         # Python implementation
│   ├── src/                        # Python source code
│   ├── version.json                # Version information for Python
│   └── export_python_package.py    # Script to create Python package
└── exports/                        # Generated packages for distribution
```

## Version Management

Each language implementation has its own `version.json` file that follows this structure:

```json
{
  "current_version": "1.0.0",
  "versions": [
    {
      "version": "1.0.0",
      "release_date": "YYYY-MM-DD",
      "notes": "Release notes"
    }
  ]
}
```

## Development Workflow

1. **Development**: Make changes to the code in the respective language folder
2. **Version Update**: Update the `version.json` file with new version information
3. **Package Creation**: Run the export script for the respective language
4. **Distribution**: The package maintainer uploads the generated package to the appropriate repository

## Release Process

When a new version is ready for release:

1. Update the `version.json` file in the appropriate language folder
2. Run the export script (e.g., `export_stata_zip.py` for Stata)
3. The script will:
   - Create a package with the correct version number
   - Replace placeholders in the code with version information
   - Generate a zip file in the `exports/` directory
4. The repository maintainer (Jeffrey Clark) will:
   - Upload the package to the website or repository
   - Create a git tag for the release
   - Push the tag to the repository

## Documentation

### For Users

- [CHANGELOG.md](CHANGELOG.md) - Version history and release notes
- [IMPORTANT_LIMITATIONS.md](IMPORTANT_LIMITATIONS.md) - Critical usage constraints

### For Developers

**General:**
- [docs/CLIENT_GUIDE.md](docs/CLIENT_GUIDE.md) - Building API clients (Stata, Python, R)
- [docs/API_DOCUMENTATION.md](docs/API_DOCUMENTATION.md) - Complete API reference
- [docs/SCHEMA.md](docs/SCHEMA.md) - Metadata schema specification
- [docs/METADATA_SYSTEM.md](docs/METADATA_SYSTEM.md) - Metadata architecture
- [docs/usage_tracking.md](docs/usage_tracking.md) - Usage tracking system documentation

**Stata-specific:**
- [docs/stata/DEVELOPMENT.md](docs/stata/DEVELOPMENT.md) - Stata dev setup, version management, local testing
- [docs/stata/STATA_ARCHITECTURE.md](docs/stata/STATA_ARCHITECTURE.md) - Stata client internal architecture

### For Testers

- [stata/tests/README.md](stata/tests/README.md) - Test suite documentation
