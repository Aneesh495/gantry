"""
GANTRY: High-Assurance Cyber-Physical Automation Runtime
Python SDK (pygantry)

Copyright (C) 2026 Aneesh Krishna. All rights reserved.
"""

from .enums import SilLevel, QualityFlags, PlantType
from .core import GantryEngine, GantryEngineError
from .historian import SDTCompressor
from .plant_sim import GantryPlant

__version__ = "1.0.0"
__author__ = "Aneesh Krishna"

__all__ = [
    "__version__",
    "GantryEngine",
    "GantryEngineError",
    "GantryPlant",
    "SDTCompressor",
    "SilLevel",
    "QualityFlags",
    "PlantType",
]
