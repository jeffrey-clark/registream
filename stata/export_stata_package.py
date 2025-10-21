#!/usr/bin/env python3

# --- SET PROJECT ROOT 
import os
import sys
import json
import shutil
import zipfile
import datetime
import re
from pathlib import Path

# Find the project root directory dynamically
root_dir = os.path.abspath(__file__)  # Start from the current file's directory

# Traverse upwards until the .project_root file is found or until reaching the system root
while not os.path.exists(os.path.join(root_dir, '.project_root')) and root_dir != '/':
    root_dir = os.path.dirname(root_dir)

# Make sure the .project_root file is found
assert root_dir != '/', "The .project_root file was not found. Make sure it exists in your project root."

sys.path.append(root_dir)

# ---



def load_version_data():
    """Load version data from version.json"""
    version_file = os.path.join(root_dir, 'stata/version.json')
    with open(version_file, 'r') as f:
        # Remove comments from JSON before parsing
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

def create_sthlp_date(release_date_str):
    """Convert YYYY-MM-DD to DDmmmYYYY format for Stata help files"""
    date_obj = datetime.datetime.strptime(release_date_str, "%Y-%m-%d")
    # Format: 27sep2024 (day, 3-letter month, year)
    return date_obj.strftime("%d%b%Y").lower()

def copy_and_update_files():
    """Copy files from code directory to exports/temp and update placeholders"""
    # Create temp directory for processing
    exports_dir = os.path.join(root_dir, 'exports')
    temp_dir = os.path.join(exports_dir, 'temp')
    
    # Remove temp dir if it exists
    if os.path.exists(temp_dir):
        shutil.rmtree(temp_dir)
    
    # Create temp directory structure
    os.makedirs(temp_dir, exist_ok=True)
    
    # Copy all files from code directory to temp
    code_dir = os.path.join(root_dir, 'stata/src')
    for file_path in Path(code_dir).glob('**/*'):
        if file_path.is_file():
            # Skip dev files (they are gitignored and should not be exported)
            if file_path.name in ['_rs_dev_config.ado', '_rs_get_dev_version.ado']:
                continue

            # Create relative path
            rel_path = file_path.relative_to(code_dir)
            dest_path = os.path.join(temp_dir, rel_path)
            
            # Create directories if needed
            os.makedirs(os.path.dirname(dest_path), exist_ok=True)
            
            # Copy the file
            shutil.copy2(file_path, dest_path)
            
            # Update placeholders in text files
            if file_path.suffix in ['.ado', '.sthlp', '.pkg', '.toc']:
                with open(dest_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                # Replace placeholders
                content = content.replace('{{VERSION}}', version)
                content = content.replace('{{STHLP_DATE}}', sthlp_date)
                content = content.replace('{{DATE}}', release_date)
                
                with open(dest_path, 'w', encoding='utf-8') as f:
                    f.write(content)
    
    return temp_dir

def create_zip_file(source_dir):
    """Create a zip file from the source directory"""
    exports_dir = os.path.join(root_dir, 'exports')
    zip_filename = f"registream_{version}-stata.zip"
    zip_path = os.path.join(exports_dir, zip_filename)
    
    # Create the folder name for extraction
    folder_name = f"registream_{version}-stata"
    
    # Remove existing zip if it exists
    if os.path.exists(zip_path):
        os.remove(zip_path)
    
    # Create the zip file
    with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
        for root, _, files in os.walk(source_dir):
            for file in files:
                # Skip macOS system files
                if file == '.DS_Store' or '__MACOSX' in root:
                    continue
                
                file_path = os.path.join(root, file)
                # Calculate path relative to the temp directory
                rel_path = os.path.relpath(file_path, source_dir)
                # Add file to zip with the path folder_name/file instead of stata/file
                zipf.write(file_path, os.path.join(folder_name, rel_path))
    
    return zip_path

def cleanup(temp_dir):
    """Remove temporary directory"""
    if os.path.exists(temp_dir):
        shutil.rmtree(temp_dir)

if __name__ == "__main__":
    # Load version data
    version, version_details = load_version_data()
    release_date = version_details['release_date']
    sthlp_date = create_sthlp_date(release_date)
    
    print(f"Processing version: {version}")
    print(f"Release date: {release_date}")
    print(f"Stata help date: {sthlp_date}")
    
    # Copy and update files
    temp_dir = copy_and_update_files()
    
    # Create zip file
    zip_path = create_zip_file(temp_dir)
    
    # Cleanup
    cleanup(temp_dir)
    
    print(f"✅ Package created: {zip_path}")
    print("📢 Next steps:")
    print(f"  1. Upload this file to the website server")
    print(f"  2. Tag the release: git tag v{version}")
    print(f"  3. Push the tag: git push origin v{version}")







