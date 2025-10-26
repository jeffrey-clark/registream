#!/usr/bin/env python3
"""
Stata Journal Submission Packaging Script
Usage: python package_submission.py [initial|final]
"""

import os
import sys
import shutil
from pathlib import Path
from datetime import datetime
import zipfile

def create_zip(source_dir, output_file):
    """Create a zip file from a directory"""
    with zipfile.ZipFile(output_file, 'w', zipfile.ZIP_DEFLATED) as zipf:
        # Get the base folder name (e.g., "autolabel_submission")
        base_name = os.path.basename(source_dir)
        for root, dirs, files in os.walk(source_dir):
            for file in files:
                file_path = os.path.join(root, file)
                # Create arcname relative to source_dir, prepend base folder name
                rel_path = os.path.relpath(file_path, source_dir)
                arcname = os.path.join(base_name, rel_path)
                zipf.write(file_path, arcname)
                print(f"  Added: {arcname}")

def check_file(filepath):
    """Check if file exists and print status"""
    if filepath.exists():
        print(f"✓ {filepath}")
        return True
    else:
        print(f"✗ MISSING: {filepath}")
        return False

def package_initial(project_dir, output_dir):
    """Create initial submission package"""
    print("\n=== Building Initial Submission Package ===\n")

    # Create temp directory
    temp_dir = output_dir / "temp_initial"
    submission_dir = temp_dir / "autolabel_submission"
    submission_dir.mkdir(parents=True, exist_ok=True)

    # Track missing files
    missing = []

    # Copy PDF (if exists)
    pdf_path = project_dir / "paper" / "main.pdf"
    if pdf_path.exists():
        shutil.copy(pdf_path, submission_dir / "autolabel_manuscript.pdf")
        print("✓ Copied PDF")
    else:
        print("⚠ Warning: main.pdf not found - you may need to compile LaTeX")
        missing.append("paper/main.pdf")

    # Copy code files
    print("\nCopying code files...")
    code_dir = submission_dir / "code"
    code_dir.mkdir(exist_ok=True)
    for pattern in ["*.ado", "*.sthlp"]:
        for f in (project_dir / "code").glob(pattern):
            shutil.copy(f, code_dir)
            print(f"  ✓ {f.name}")

    # Copy examples (*.do only - excludes any batch .log files from Stata)
    print("\nCopying example files...")
    examples_dir = submission_dir / "examples"
    examples_dir.mkdir(exist_ok=True)
    for f in (project_dir / "examples").glob("*.do"):
        shutil.copy(f, examples_dir)
        print(f"  ✓ {f.name}")

    # Copy logs (from logs/ directory only, not from examples/)
    print("\nCopying log files...")
    logs_dir = submission_dir / "logs"
    logs_dir.mkdir(exist_ok=True)
    for f in (project_dir / "logs").glob("*.log"):
        shutil.copy(f, logs_dir)
        print(f"  ✓ {f.name}")

    # Clean up any batch log files Stata created in examples/
    examples_logs = list((project_dir / "examples").glob("*.log"))
    if examples_logs:
        print(f"\nCleaning up {len(examples_logs)} batch log file(s) from examples/...")
        for log_file in examples_logs:
            log_file.unlink()
            print(f"  ✗ Removed {log_file.name}")

    # Copy data (excluding metadata .dta files - they're generated from CSV)
    print("\nCopying data files...")
    data_dest = submission_dir / "data"
    data_dest.mkdir(exist_ok=True)

    # Copy .dta data files (but NOT metadata .dta files)
    for dta_file in (project_dir / "data").glob("*.dta"):
        shutil.copy(dta_file, data_dest)
        print(f"  ✓ {dta_file.name}")

    # Copy autolabel_keys directory (CSV only, exclude .dta)
    keys_src = project_dir / "data" / "autolabel_keys"
    keys_dest = data_dest / "autolabel_keys"
    keys_dest.mkdir(exist_ok=True)
    for csv_file in keys_src.glob("*.csv"):
        shutil.copy(csv_file, keys_dest)
        print(f"  ✓ autolabel_keys/{csv_file.name}")

    # Copy readme
    shutil.copy(project_dir / "readme.txt", submission_dir)
    print("✓ Copied readme.txt")

    # Copy cover letter
    if (project_dir / "cover_letter.txt").exists():
        shutil.copy(project_dir / "cover_letter.txt", submission_dir)
        print("✓ Copied cover_letter.txt")
    else:
        print("⚠ Warning: cover_letter.txt not found")
        missing.append("cover_letter.txt")

    # Create zip file
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_file = output_dir / f"autolabel_initial_submission_{timestamp}.zip"

    print(f"\n=== Creating ZIP file ===")
    create_zip(submission_dir, output_file)

    # Cleanup temp
    shutil.rmtree(temp_dir)

    return output_file, missing

def package_final(project_dir, output_dir):
    """Create final submission package (post-acceptance)"""
    print("\n=== Building Final Submission Package ===\n")

    # Create temp directory
    temp_dir = output_dir / "temp_final"
    submission_dir = temp_dir / "autolabel_submission"
    submission_dir.mkdir(parents=True, exist_ok=True)

    missing = []

    # Copy ALL LaTeX source files
    print("Copying LaTeX source files...")
    paper_dir = submission_dir / "paper"
    paper_dir.mkdir(exist_ok=True)
    for pattern in ["*.tex", "*.bib", "*.log", "*.sty", "*.cls", "*.bst", "*.eps", "*.pdf"]:
        for f in (project_dir / "paper").glob(pattern):
            shutil.copy(f, paper_dir)
            print(f"  ✓ {f.name}")

    # Copy final software files
    print("\nCopying final software files...")
    code_dir = submission_dir / "code"
    code_dir.mkdir(exist_ok=True)
    for pattern in ["*.ado", "*.sthlp"]:
        for f in (project_dir / "code").glob(pattern):
            shutil.copy(f, code_dir)
            print(f"  ✓ {f.name}")

    # Copy examples (*.do only - excludes any batch .log files from Stata)
    print("\nCopying example files...")
    examples_dir = submission_dir / "examples"
    examples_dir.mkdir(exist_ok=True)
    for f in (project_dir / "examples").glob("*.do"):
        shutil.copy(f, examples_dir)
        print(f"  ✓ {f.name}")

    # Copy logs (from logs/ directory only, not from examples/)
    print("\nCopying log files...")
    logs_dir = submission_dir / "logs"
    logs_dir.mkdir(exist_ok=True)
    for f in (project_dir / "logs").glob("*.log"):
        shutil.copy(f, logs_dir)
        print(f"  ✓ {f.name}")

    # Clean up any batch log files Stata created in examples/
    examples_logs = list((project_dir / "examples").glob("*.log"))
    if examples_logs:
        print(f"\nCleaning up {len(examples_logs)} batch log file(s) from examples/...")
        for log_file in examples_logs:
            log_file.unlink()
            print(f"  ✗ Removed {log_file.name}")

    # Copy data (excluding metadata .dta files - they're generated from CSV)
    print("\nCopying data files...")
    data_dest = submission_dir / "data"
    data_dest.mkdir(exist_ok=True)

    # Copy .dta data files (but NOT metadata .dta files)
    for dta_file in (project_dir / "data").glob("*.dta"):
        shutil.copy(dta_file, data_dest)
        print(f"  ✓ {dta_file.name}")

    # Copy autolabel_keys directory (CSV only, exclude .dta)
    keys_src = project_dir / "data" / "autolabel_keys"
    keys_dest = data_dest / "autolabel_keys"
    keys_dest.mkdir(exist_ok=True)
    for csv_file in keys_src.glob("*.csv"):
        shutil.copy(csv_file, keys_dest)
        print(f"  ✓ autolabel_keys/{csv_file.name}")

    # Copy readme
    shutil.copy(project_dir / "readme.txt", submission_dir)
    print("✓ Copied readme.txt")

    # Check for signed agreement
    agreement_path = project_dir / "contributor_agreement_signed.pdf"
    if agreement_path.exists():
        shutil.copy(agreement_path, submission_dir)
        print("✓ Copied signed Contributor Agreement")
    else:
        print("✗ MISSING: contributor_agreement_signed.pdf")
        print("  You MUST include the signed Contributor Assignment Agreement!")
        missing.append("contributor_agreement_signed.pdf")

    # Create zippy file (.zip renamed to .zippy per SJ instructions)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_file = output_dir / f"autolabel_final_submission_{timestamp}.zippy"

    print(f"\n=== Creating ZIPPY file ===")
    zip_file = output_dir / f"autolabel_final_submission_{timestamp}.zip"
    create_zip(submission_dir, zip_file)

    # Rename to .zippy
    shutil.move(zip_file, output_file)

    # Cleanup temp
    shutil.rmtree(temp_dir)

    return output_file, missing

def main():
    # Get submission type
    submission_type = sys.argv[1] if len(sys.argv) > 1 else "initial"

    if submission_type not in ["initial", "final"]:
        print("Error: Submission type must be 'initial' or 'final'")
        print("Usage: python package_submission.py [initial|final]")
        sys.exit(1)

    # Setup paths
    project_dir = Path(__file__).parent
    output_dir = project_dir / "submission_packages"
    output_dir.mkdir(exist_ok=True)

    print("=" * 60)
    print("Stata Journal Submission Packager")
    print("=" * 60)
    print(f"Type: {submission_type}")
    print(f"Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

    # Check key files exist
    print("\n=== Checking Required Files ===\n")

    key_files = [
        "paper/main.tex",
        "paper/autolabel.tex",
        "paper/autolabel.bib",
        "code/autolabel.ado",
        "code/_autolabel_utils.ado",
        "code/autolabel.sthlp",
        "examples/examples.do",
        "logs/examples.log",
        "readme.txt",
        "cover_letter.txt"
    ]

    all_exist = all(check_file(project_dir / f) for f in key_files)

    if not all_exist:
        response = input("\n⚠ Some files missing. Continue anyway? (y/n): ")
        if response.lower() != 'y':
            print("Aborted.")
            sys.exit(1)

    # Package
    if submission_type == "initial":
        output_file, missing = package_initial(project_dir, output_dir)

        print("\n" + "=" * 60)
        print("✓ Initial Submission Package Created")
        print("=" * 60)
        print(f"\nLocation: {output_file}")
        print(f"Size: {output_file.stat().st_size / 1024:.1f} KB")

        print("\n📋 Next Steps:")
        print("1. Verify paper/main.pdf exists and is current")
        print("2. Review readme.txt is complete")
        print("3. Review cover_letter.txt is complete")
        print("4. Send to: editors@stata-journal.com")

    else:
        output_file, missing = package_final(project_dir, output_dir)

        print("\n" + "=" * 60)
        print("✓ Final Submission Package Created")
        print("=" * 60)
        print(f"\nLocation: {output_file}")
        print(f"Size: {output_file.stat().st_size / 1024:.1f} KB")

        print("\n📋 Next Steps:")
        print("1. Verify contributor_agreement_signed.pdf is included")
        print("2. Send to: editors@stata-journal.com")
        print("3. Email should confirm this is the final accepted version")

    if missing:
        print(f"\n⚠ Warning: {len(missing)} file(s) missing:")
        for f in missing:
            print(f"  - {f}")

if __name__ == "__main__":
    main()
