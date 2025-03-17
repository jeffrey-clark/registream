#!/usr/bin/env python3

import os
import sys
import subprocess
import json
import re
import requests
from pathlib import Path

# Find the project root directory dynamically
root_dir = os.path.abspath(__file__)  # Start from the current file's directory

# Traverse upwards until the .project_root file is found or until reaching the system root
while not os.path.exists(os.path.join(os.path.dirname(root_dir), '.project_root')) and root_dir != '/':
    root_dir = os.path.dirname(root_dir)

# Make sure the .project_root file is found
root_dir = os.path.dirname(root_dir)  # Go up one more level to get the actual project root
assert os.path.exists(os.path.join(root_dir, '.project_root')), "The .project_root file was not found. Make sure it exists in your project root."

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

def check_if_version_exists_on_pypi(package_name, version):
    """Check if the package version already exists on PyPI"""
    try:
        response = requests.get(f"https://pypi.org/pypi/{package_name}/json")
        if response.status_code == 200:
            data = response.json()
            releases = data.get('releases', {})
            return version in releases
        else:
            # If 404, then package doesn't exist yet, so version doesn't exist
            return False
    except Exception as e:
        print(f"Warning: Error checking PyPI version: {e}")
        # If we can't check, assume it doesn't exist and let twine handle any errors
        return False

def load_pypi_config():
    """Load PyPI configuration from local config file"""
    config_path = os.path.join(root_dir, 'python/config/pypi_config.json')
    try:
        with open(config_path, 'r') as f:
            return json.load(f)
    except Exception as e:
        print(f"Warning: Could not load PyPI config: {e}")
        print("Make sure you have created python/config/pypi_config.json with your tokens.")
        return None

def upload_to_pypi(version, export_path):
    """Upload the package to PyPI"""
    # First check if we have properly named files in the python/dist directory
    python_dist_dir = os.path.join(root_dir, 'python/dist')
    sdist_path = os.path.join(python_dist_dir, f"registream-{version}.tar.gz")
    wheel_path = os.path.join(python_dist_dir, f"registream-{version}-py3-none-any.whl")
    
    # If not found in python/dist, fall back to the export path
    if not os.path.exists(sdist_path) or not os.path.exists(wheel_path):
        print(f"Standard distribution files not found in {python_dist_dir}, checking export path...")
        # Use the provided export path or fallback to default
        if export_path:
            sdist_path = os.path.join(export_path, f"registream_{version}-python.tar.gz")
            wheel_path = os.path.join(export_path, f"registream_{version}-python.whl")
        else:
            exports_dir = os.path.join(root_dir, 'exports')
            sdist_path = os.path.join(exports_dir, f"registream_{version}-python.tar.gz")
            wheel_path = os.path.join(exports_dir, f"registream_{version}-python.whl")
    
    # Check if files exist
    if not os.path.exists(sdist_path):
        print(f"Error: Source distribution not found at {sdist_path}")
        sys.exit(1)
    if not os.path.exists(wheel_path):
        print(f"Warning: Wheel not found at {wheel_path}, continuing with just the source distribution")
        wheel_path = None
    
    # Load PyPI configuration
    config = load_pypi_config()
    
    # Get repository URL and token
    repo_url = "https://upload.pypi.org/legacy/"
    repo_name = "PyPI"
    token = config.get('pypi', {}).get('token') if config else None
    
    # Build upload command
    cmd = [sys.executable, "-m", "twine", "upload", "--repository-url", repo_url]
    
    # Add authentication if token is available
    if token and token != "YOUR_PYPI_TOKEN_HERE":
        cmd.extend(["--username", "__token__", "--password", token])
    
    # Add files to upload
    cmd.append(sdist_path)
    if wheel_path:
        cmd.append(wheel_path)
    
    print(f"Uploading to {repo_name}...")
    print(f"Using files: {sdist_path} and {wheel_path if wheel_path else 'No wheel'}")
    
    # Run the upload command
    try:
        result = subprocess.run(cmd, check=True)
        if result.returncode == 0:
            print(f"✅ Successfully uploaded registream {version} to {repo_name}")
            print("📢 Users can now install your package with:")
            print(f"    pip install registream=={version}")
            print("    or simply:")
            print(f"    pip install registream")
        else:
            print(f"❌ Failed to upload to {repo_name}")
    except subprocess.CalledProcessError as e:
        print(f"❌ Error uploading to {repo_name}: {e}")
        sys.exit(1)

if __name__ == "__main__":
    # Set parameters directly here
    force_upload = True  # Set to True to override existing versions
    export_path = os.path.join(root_dir, 'exports')  # Path to your export files
    
    # Get the current version
    version, version_details = load_version_data()
    
    # Check if this version already exists on PyPI
    package_name = "registream"
    
    if not force_upload and check_if_version_exists_on_pypi(package_name, version):
        print(f"❌ Version {version} already exists on PyPI.")
        print("To upload anyway, set force_upload = True in the script.")
        sys.exit(1)
    
    # Show what will be uploaded
    print(f"Ready to upload registream version {version} to PyPI")
    
    # Check both locations for package files
    python_dist_dir = os.path.join(root_dir, 'python/dist')
    if os.path.exists(python_dist_dir) and os.path.exists(os.path.join(python_dist_dir, f"registream-{version}.tar.gz")):
        print(f"Found standard distribution files in: {python_dist_dir}")
    else:
        print(f"Looking for package files in: {export_path}")
    
    # Ask for confirmation
    confirmation = input("Do you want to proceed with the upload? (yes/no): ").strip().lower()
    if confirmation not in ['yes', 'y']:
        print("Upload cancelled.")
        sys.exit(0)
    
    # Upload to PyPI
    upload_to_pypi(version, export_path)
    
    print("🎉 Process completed successfully!") 