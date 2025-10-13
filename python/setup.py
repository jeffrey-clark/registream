from setuptools import setup, find_packages
import json
import os

# Read version from version.json
with open(os.path.join(os.path.dirname(__file__), 'version.json'), 'r') as f:
    version_data = json.load(f)
    version = version_data['current_version']

# Read README.md for long description
with open(os.path.join(os.path.dirname(__file__), 'README.md'), 'r') as f:
    long_description = f.read()

setup(
    name="registream",
    version=version,
    description="Streamline your registry data workflow",
    author="Jeffrey Clark & Jie Wen",
    url="https://registream.org",
    package_dir={"": "src"},
    packages=find_packages(where="src"),
    install_requires=[
        "pandas>=1.0.0",
        "tqdm>=4.0.0",
        "requests>=2.0.0",
        "matplotlib>=3.0.0",
        "seaborn>=0.11.0",
    ],
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: Science/Research",
        "License :: OSI Approved :: BSD License",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.7",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
    ],
    python_requires=">=3.7",
    license="BSD-3-Clause",
    long_description=long_description,
    long_description_content_type="text/markdown",
)
