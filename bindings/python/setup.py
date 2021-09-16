#!/usr/bin/env python3
"""
GANTRY Python SDK (pygantry) Setup Script
"""

from setuptools import setup, find_packages

setup(
    name="pygantry",
    version="1.0.0",
    description="Python SDK for Gantry High-Assurance Cyber-Physical Automation Runtime",
    author="Aneesh Krishna",
    packages=find_packages(),
    classifiers=[
        "Development Status :: 5 - Production/Stable",
        "Intended Audience :: Manufacturing",
        "Intended Audience :: Science/Research",
        "License :: OSI Approved :: MIT License",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Programming Language :: Python :: 3.12",
        "Programming Language :: Python :: 3.13",
        "Programming Language :: Python :: 3.14",
        "Topic :: Scientific/Engineering",
        "Topic :: System :: Hardware",
    ],
    python_requires=">=3.10",
)
