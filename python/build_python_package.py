#!/usr/bin/env python3

# --- SET PROJECT ROOT 
import os
import sys
import json
import shutil
import re
import subprocess
import importlib.util
import ast
from pathlib import Path

# Find the project root directory dynamically
root_dir = os.path.abspath(__file__)  # Start from the current file's directory

# Traverse upwards until the .project_root file is found or until reaching the system root
while not os.path.exists(os.path.join(os.path.dirname(root_dir), '.project_root')) and root_dir != '/':
    root_dir = os.path.dirname(root_dir)

# Make sure the .project_root file is found
root_dir = os.path.dirname(root_dir)  # Go up one more level to get the actual project root
assert os.path.exists(os.path.join(root_dir, '.project_root')), "The .project_root file was not found. Make sure it exists in your project root."

sys.path.append(root_dir)

# ---

def load_version_data():
    """Load version data from version.json"""
    version_file = os.path.join(root_dir, 'python/version.json')
    with open(version_file, 'r') as f:
        # Remove comments from JSON before parsing (if any)
        json_str = re.sub(r'//.*$', '', f.read(), flags=re.MULTILINE)
        version_data = json.loads(json_str)
    
    current_version = version_data['current_version']
    
    # Find the current version details
    version_details = None
    for v in version_data['versions']:
        if v['version'] == current_version:
            version_details = v
            break
    
    if not version_details:
        raise ValueError(f"Current version {current_version} not found in versions list")
    
    return current_version, version_details

def update_pyproject_version(version):
    """Update the version in pyproject.toml"""
    python_dir = os.path.join(root_dir, 'python')
    pyproject_path = os.path.join(python_dir, 'pyproject.toml')
    
    # Read the pyproject.toml file
    with open(pyproject_path, 'r') as f:
        content = f.read()
    
    # Replace the version with the current version
    updated_content = re.sub(
        r'version\s*=\s*"[^"]*"',
        f'version = "{version}"',
        content
    )
    
    # Write the updated content back to the file
    with open(pyproject_path, 'w') as f:
        f.write(updated_content)

def scan_for_imports():
    """Scan Python files in the src directory to find required packages"""
    python_dir = os.path.join(root_dir, 'python')
    src_dir = os.path.join(python_dir, 'src')
    
    # Dictionary to store all imports and their source files
    all_imports = {}
    
    # Standard library modules to ignore
    stdlib_modules = set([
        'ast', 'os', 'sys', 'json', 're', 'shutil', 'zipfile', 'platform',
        'functools', 'datetime', 'time', 'pathlib', 'collections', 'math',
        'random', 'copy', 'io', 'pickle', 'csv', 'urllib', 'email', 'http',
        'argparse', 'logging', 'configparser', 'hashlib', 'base64', 'tempfile',
        'glob', 'fnmatch', 'itertools', 'operator'
    ])
    
    # Internal package modules to ignore (modules within the registream package)
    internal_modules = set(['registream', 'label_fetcher', 'autolabel', 'lookup'])
    
    # Walk through all Python files
    for root, _, files in os.walk(src_dir):
        for file in files:
            if file.endswith('.py'):
                file_path = os.path.join(root, file)
                
                # Parse the file and extract imports
                with open(file_path, 'r', encoding='utf-8') as f:
                    try:
                        tree = ast.parse(f.read())
                        
                        for node in ast.walk(tree):
                            # Look for import statements
                            if isinstance(node, ast.Import):
                                for name in node.names:
                                    module_name = name.name.split('.')[0]
                                    if module_name not in stdlib_modules and module_name not in internal_modules:
                                        if module_name not in all_imports:
                                            all_imports[module_name] = []
                                        all_imports[module_name].append(file_path)
                            
                            # Look for from ... import statements
                            elif isinstance(node, ast.ImportFrom) and node.module:
                                module_name = node.module.split('.')[0]
                                if module_name not in stdlib_modules and module_name not in internal_modules:
                                    if module_name not in all_imports:
                                        all_imports[module_name] = []
                                    all_imports[module_name].append(file_path)
                    except SyntaxError:
                        print(f"Warning: Could not parse {file_path} due to syntax error")
    
    # Remove any relative imports (starting with '.')
    filtered_imports = {k: v for k, v in all_imports.items() if not k.startswith('.')}
    
    # Return the dictionary of imports
    return filtered_imports

def check_pyproject_dependencies(required_imports):
    """Check if all required imports are listed in pyproject.toml dependencies"""
    # Ensure tomli is available
    try:
        import tomli
    except ImportError:
        print("Warning: tomli module not available. Installing...")
        # If tomli is not available, try to install it
        subprocess.run([sys.executable, "-m", "pip", "install", "tomli"], check=True)
        import tomli
    
    python_dir = os.path.join(root_dir, 'python')
    pyproject_path = os.path.join(python_dir, 'pyproject.toml')
    
    try:
        with open(pyproject_path, 'rb') as f:
            pyproject_data = tomli.load(f)
    except Exception as e:
        print(f"Warning: Error reading pyproject.toml: {e}")
        return
    
    # Get the dependencies list
    try:
        dependencies = pyproject_data.get('project', {}).get('dependencies', [])
    except Exception as e:
        print(f"Warning: Error parsing dependencies from pyproject.toml: {e}")
        return
    
    # Check each required import against dependencies
    missing_deps = []
    for imp in required_imports:
        # Check if the dependency is included
        if not any(dep.lower().startswith(imp.lower()) for dep in dependencies):
            missing_deps.append(imp)
    
    if missing_deps:
        print("⚠️ Warning: The following imports were found but are not listed in pyproject.toml:")
        for dep in missing_deps:
            files = ", ".join([os.path.relpath(f, root_dir) for f in required_imports[dep][:3]])
            if len(required_imports[dep]) > 3:
                files += f", and {len(required_imports[dep]) - 3} more files"
            print(f"  - {dep} (used in {files})")
        print("Consider adding them to the dependencies list in pyproject.toml")
    else:
        print("✅ All detected dependencies are listed in pyproject.toml")

def prepare_package_files():
    """Prepare all necessary files for the package, copying from root if needed"""
    python_dir = os.path.join(root_dir, 'python')
    
    # List of files to check/copy from root if not in python dir
    required_files = {
        'LICENSE': os.path.join(root_dir, 'LICENSE'),
    }
    
    # Copy files from root if they don't exist in python dir
    for file, source in required_files.items():
        target = os.path.join(python_dir, file)
        if not os.path.exists(target) and os.path.exists(source):
            print(f"Copying {file} from root directory...")
            shutil.copy2(source, target)
    
    # Check for other required files that should be created manually
    other_required = ['pyproject.toml', 'README.md']
    missing_files = []
    
    for file in other_required:
        if not os.path.exists(os.path.join(python_dir, file)):
            missing_files.append(file)
    
    if missing_files:
        raise FileNotFoundError(f"Missing required files: {', '.join(missing_files)}")

def build_python_package():
    """Build the Python package using the modern build approach"""
    python_dir = os.path.join(root_dir, 'python')
    
    # Change to the python directory
    os.chdir(python_dir)
    
    # Clean previous builds
    if os.path.exists('dist'):
        shutil.rmtree('dist')
    if os.path.exists('build'):
        shutil.rmtree('build')
    if os.path.exists('registream.egg-info'):
        shutil.rmtree('registream.egg-info')
    
    # Build source distribution and wheel using modern tools
    print("Building Python package...")
    try:
        # Try using the new pyproject-build tool if available
        subprocess.run([sys.executable, "-m", "build", "--sdist", "--wheel", "."], check=True)
    except (subprocess.SubprocessError, FileNotFoundError):
        print("Warning: 'build' module not available, falling back to setuptools")
        # Fall back to setuptools
        if os.path.exists('setup.py'):
            subprocess.run([sys.executable, "setup.py", "sdist", "bdist_wheel"], check=True)
        else:
            # Try to use pip as a fallback
            subprocess.run([sys.executable, "-m", "pip", "install", "build"], check=True)
            subprocess.run([sys.executable, "-m", "build", "--sdist", "--wheel", "."], check=True)
    
    return os.path.join(python_dir, 'dist')

def copy_to_exports(dist_dir, version):
    """Copy and rename the built distributions to the exports folder"""
    exports_dir = os.path.join(root_dir, 'exports')
    os.makedirs(exports_dir, exist_ok=True)
    
    # Find the distribution files
    sdist_file = None
    wheel_file = None
    
    for file in os.listdir(dist_dir):
        if file.endswith('.tar.gz'):
            sdist_file = os.path.join(dist_dir, file)
        elif file.endswith('.whl'):
            wheel_file = os.path.join(dist_dir, file)
    
    if not sdist_file:
        raise FileNotFoundError("Source distribution not found")
    
    # Copy and rename the source distribution
    export_sdist_path = os.path.join(exports_dir, f"registream_{version}-python.tar.gz")
    shutil.copy2(sdist_file, export_sdist_path)
    
    # Copy the wheel if it exists
    if wheel_file:
        export_wheel_path = os.path.join(exports_dir, f"registream_{version}-python.whl")
        shutil.copy2(wheel_file, export_wheel_path)
    
    return export_sdist_path, export_wheel_path if wheel_file else None

def cleanup(dist_dir):
    """Clean up build artifacts"""
    python_dir = os.path.join(root_dir, 'python')
    
    # Clean up build directories
    for directory in ['build', 'registream.egg-info', 'registream.egg', '.eggs']:
        dir_path = os.path.join(python_dir, directory)
        if os.path.exists(dir_path):
            print(f"Cleaning up {directory}...")
            shutil.rmtree(dir_path)
    
    # Clean up egg-info in src directory
    src_egg_info = os.path.join(python_dir, 'src/registream.egg-info')
    if os.path.exists(src_egg_info):
        print(f"Cleaning up src/registream.egg-info...")
        shutil.rmtree(src_egg_info)
    
    # Clean up dist directory (after we've copied the files to exports)
    if os.path.exists(dist_dir):
        print(f"Cleaning up dist directory...")
        shutil.rmtree(dist_dir)
    
    # Remove copied LICENSE file to avoid duplication
    license_file = os.path.join(python_dir, 'LICENSE')
    if os.path.exists(license_file) and os.path.exists(os.path.join(root_dir, 'LICENSE')):
        os.remove(license_file)

if __name__ == "__main__":
    # Load version data
    version, version_details = load_version_data()
    release_date = version_details['release_date']
    
    print(f"Processing version: {version}")
    print(f"Release date: {release_date}")
    
    # Update pyproject.toml with current version
    print(f"Updating pyproject.toml with version {version}...")
    update_pyproject_version(version)
    
    # Scan for imports and check dependencies
    print("\nChecking dependencies...")
    required_imports = scan_for_imports()
    check_pyproject_dependencies(required_imports)
    print()  # Empty line for readability
    
    # Prepare all necessary files
    prepare_package_files()
    
    # Build the Python package
    dist_dir = build_python_package()
    
    # Copy to exports folder
    sdist_path, wheel_path = copy_to_exports(dist_dir, version)
    
    # Cleanup
    cleanup(dist_dir)
    
    print(f"✅ Package created: {sdist_path}")
    if wheel_path:
        print(f"✅ Wheel created: {wheel_path}")
    print("📢 Next steps:")
    print(f"  1. Upload this file to the website server")
    print(f"  2. Tag the release: git tag v{version}")
    print(f"  3. Push the tag: git push origin v{version}")
    print(f"  4. Upload to PyPI: python -m twine upload {sdist_path} {wheel_path if wheel_path else ''}")
