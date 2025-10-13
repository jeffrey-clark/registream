# RegiStream

**RegiStream: Streamline Your Register Data Workflow**

## Project Overview

RegiStream is a multi-platform toolkit for working with register data in **Stata, R, and Python**.  
It provides a **consistent framework** to help researchers efficiently process, label, and analyze register data.



## Version Log

| Version  | Stata Status | R Status  | Python Status  | Key Features |
|----------|-------------|-----------|---------------|--------------|
| **1.0.0** | ✅ Released | ⏳ Planned | ✅ Released | `autolabel` and `label` functionality |
| **1.0.1** | ✅ Released  | ❌ Not yet | ✅ Released  | URL migration to registream.org, CSV apostrophe fix (Stata) |
| **1.0.2** | ⏳ Planned  | ❌ Not yet | ⏳ Planned  | Auto-update methods, data versioning system |


- ✅ = Released  
- ⏳ = Planned  
- ❌ = Not yet implemented  



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

For more detailed information, see the documentation in the `docs/` directory:

- [Development Guidelines](docs/development.md)
- [Release Process](docs/release_process.md)
- Language-specific documentation:
  - [Stata](docs/language-specific/stata.md)
  - [R](docs/language-specific/r.md)
  - [Python](docs/language-specific/python.md)
