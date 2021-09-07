"""
GANTRY Cyber-Physical Automation Runtime
Python SDK Enumerations and Bitflags

Copyright (C) 2026 Aneesh Krishna. All rights reserved.
"""

from enum import Enum, IntEnum, IntFlag


class SilLevel(IntEnum):
    """Safety Integrity Levels according to IEC 61508."""
    SIL_0 = 0
    SIL_1 = 1
    SIL_2 = 2
    SIL_3 = 3
    SIL_4 = 4


class QualityFlags(IntFlag):
    """Signal quality flags aligned with IEC 61850."""
    GOOD = 0x0000
    INVALID = 0x0001
    OVERFLOW = 0x0002
    OUT_OF_BOUNDS = 0x0004
    BAD_REFERENCE = 0x0008
    OSCILLATORY = 0x0010
    TEST = 0x0020
    OPERATOR_OVERRIDE = 0x0040


class PlantType(str, Enum):
    """Supported cyber-physical plant simulation models."""
    CRANE = "crane"
    REACTOR = "reactor"
    RAIL = "rail"
