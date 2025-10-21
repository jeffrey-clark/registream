# RegiStream Python Development Guide

**Version:** 1.0.1
**Last Updated:** 2025-10-21

---

## Table of Contents

- [Building the Package](#building-the-package)
- [Local Testing](#local-testing)
- [PyPI Deployment](#pypi-deployment)

---

## Building the Package

### Build Script

RegiStream uses `build_python_package.py` to create distribution packages:

```bash
cd ~/Github/registream
python python/build_python_package.py
```

**What it does:**
- Reads version from `python/version.json`
- Creates `.tar.gz` source distribution
- Creates `.whl` wheel distribution
- Outputs to `exports/` directory

**Output:**
```
exports/
├── registream_1.0.1-python.tar.gz
└── registream-1.0.1-py3-none-any.whl
```

---

## Local Testing

### Test Before PyPI Deployment

Always test the package locally before deploying to PyPI:

**1. Build the package first:**
```bash
python python/build_python_package.py
```

**2. Uninstall current version:**
```bash
python -m pip uninstall -y registream
```

**3. Install from local build:**
```bash
python -m pip install /Users/jeffrey/Github/registream/exports/registream_1.0.1-python.tar.gz
```

**4. Test the installation:**
```python
import registream
print(registream.__version__)

# Test autolabel functionality
import pandas as pd
df = pd.read_csv('test_data.csv')
df.autolabel(domain='scb', lang='eng')
df.lab.head()
```

**5. Test lookup functionality:**
```python
from registream import lookup
lookup(['carb', 'yrkarbtyp'], domain='scb', lang='eng')
```

---

### Development Installation (Editable Mode)

For active development with immediate code changes:

```bash
cd ~/Github/registream/python
pip install -e .
```

**Benefits:**
- No need to reinstall after code changes
- Changes take effect immediately
- Useful for debugging and iteration

---

## PyPI Deployment

### Prerequisites

**Install build and upload tools:**
```bash
pip install build twine
```

**Configure PyPI credentials:**
```bash
# Create ~/.pypirc
[pypi]
username = __token__
password = pypi-YOUR_TOKEN_HERE
```

---

### Deployment Steps

**1. Update version number:**
```bash
# Edit python/version.json
{
  "current_version": "1.0.2",
  "versions": [...]
}
```

**2. Update pyproject.toml:**
```bash
# Edit python/pyproject.toml
[project]
version = "1.0.2"
```

**3. Build the package:**
```bash
python python/build_python_package.py
```

**4. Test locally (see above):**
```bash
pip uninstall -y registream
pip install exports/registream_1.0.2-python.tar.gz
# Run tests...
```

**5. Upload to PyPI:**
```bash
cd exports
twine upload registream-1.0.2-py3-none-any.whl registream_1.0.2-python.tar.gz
```

**6. Verify on PyPI:**
```bash
# Check https://pypi.org/project/registream/
pip install --upgrade registream
python -c "import registream; print(registream.__version__)"
```

---

## Package Structure

```
python/
├── build_python_package.py        # Build script
├── pyproject.toml                 # Package metadata
├── setup.py                       # Setup configuration
├── version.json                   # Version tracking
├── README.md                      # Package documentation
└── src/
    └── registream/
        ├── __init__.py
        ├── label_fetcher.py       # Core functionality
        └── ...
```

---

## Testing Checklist

Before deploying to PyPI:

- [ ] Update `version.json` with new version
- [ ] Update `pyproject.toml` version
- [ ] Run `build_python_package.py`
- [ ] Test local installation from `.tar.gz`
- [ ] Test `import registream`
- [ ] Test `df.autolabel()` functionality
- [ ] Test `lookup()` functionality
- [ ] Test both `scb` domain with `eng` and `swe` languages
- [ ] Check no import errors or warnings
- [ ] Verify `__version__` attribute
- [ ] Create GitHub release tag: `v{version}-python`
- [ ] Upload to PyPI with `twine`
- [ ] Test fresh install: `pip install --upgrade registream`

---

## Common Issues

### "Package not found" after local install

**Problem:** `pip install` succeeds but `import registream` fails

**Solution:**
```bash
# Check installation location
pip show registream

# Make sure you're in the right Python environment
which python
python -c "import sys; print(sys.path)"
```

### Version mismatch after update

**Problem:** Old version still showing after install

**Solution:**
```bash
# Force reinstall
pip uninstall -y registream
pip cache purge
pip install registream --no-cache-dir
```

### Build script fails

**Problem:** `build_python_package.py` errors

**Solution:**
```bash
# Install build dependencies
pip install build wheel setuptools

# Check version.json is valid JSON
python -m json.tool python/version.json
```

---

## Version Management

Python package versions are managed in two places:

1. **`python/version.json`** - Source of truth for changelog
2. **`python/pyproject.toml`** - Python package metadata

**Always keep them in sync!**

---

**See also:**
- [Python README](../../python/README.md) - User-facing documentation
- [Stata Development Guide](../stata/development.md) - Stata equivalent

---

**Last Updated:** 2025-10-21
