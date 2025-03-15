from setuptools import setup, find_packages
import json
import os

# Read version from version.json
with open(os.path.join(os.path.dirname(__file__), 'version.json'), 'r') as f:
    version_data = json.load(f)
    version = version_data['current_version']

setup(
    name="registream",
    version=version,
    description="Streamline your registry data workflow",
    author="RegiStream Team",
    author_email="info@registream.com",
    url="https://registream.com",
    package_dir={"registream": "src"},
    packages=["registream"],
    install_requires=[
        "pandas>=1.0.0",
        "tqdm>=4.0.0",
        "requests>=2.0.0",
    ],
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: Science/Research",
        "License :: OSI Approved :: MIT License",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.7",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
    ],
    python_requires=">=3.7",
)
