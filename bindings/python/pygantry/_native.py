"""
GANTRY Cyber-Physical Automation Runtime
C Foreign Function Interface (ctypes) Native Loader and Signatures

Copyright (C) 2026 Aneesh Krishna. All rights reserved.
"""

import ctypes
import os
import sys
from pathlib import Path


class GantryCycleStats(ctypes.Structure):
    _fields_ = [
        ("total_cycles", ctypes.c_uint64),
        ("total_overruns", ctypes.c_uint64),
        ("last_scan_us", ctypes.c_double),
        ("avg_scan_us", ctypes.c_double),
        ("max_scan_us", ctypes.c_double),
        ("last_jitter_us", ctypes.c_double),
        ("max_jitter_us", ctypes.c_double),
    ]


def _find_library() -> Path:
    lib_names = ["libgantry.dylib", "libgantry.so", "gantry.dll"]
    current_dir = Path(__file__).resolve().parent

    candidates = [
        current_dir,
        current_dir.parent.parent.parent / "build",
        current_dir.parent.parent / "build",
        Path("/usr/local/lib"),
        Path("/usr/lib"),
    ]

    for c in candidates:
        for name in lib_names:
            p = c / name
            if p.is_file():
                return p

    # Fallback to current working directory build/
    p = Path("build/libgantry.dylib")
    if p.is_file():
        return p.resolve()

    raise FileNotFoundError(
        "Could not locate libgantry shared library. Run 'make lib' or build with clang first."
    )


def _load_native_library() -> ctypes.CDLL:
    lib_path = _find_library()
    dll = ctypes.CDLL(str(lib_path))

    # Engine lifecycle
    dll.gantry_engine_create.argtypes = [ctypes.c_char_p, ctypes.c_uint32]
    dll.gantry_engine_create.restype = ctypes.c_void_p

    dll.gantry_engine_destroy.argtypes = [ctypes.c_void_p]
    dll.gantry_engine_destroy.restype = None

    # Point registration
    dll.gantry_register_digital_input.argtypes = [
        ctypes.c_void_p, ctypes.c_char_p, ctypes.c_char_p, ctypes.c_bool, ctypes.c_uint32
    ]
    dll.gantry_register_digital_input.restype = ctypes.c_int

    dll.gantry_register_digital_output.argtypes = [
        ctypes.c_void_p, ctypes.c_char_p, ctypes.c_char_p, ctypes.c_bool
    ]
    dll.gantry_register_digital_output.restype = ctypes.c_int

    dll.gantry_register_analog_input.argtypes = [
        ctypes.c_void_p, ctypes.c_char_p, ctypes.c_char_p, ctypes.c_char_p,
        ctypes.c_double, ctypes.c_double, ctypes.c_double, ctypes.c_double
    ]
    dll.gantry_register_analog_input.restype = ctypes.c_int

    dll.gantry_register_analog_output.argtypes = [
        ctypes.c_void_p, ctypes.c_char_p, ctypes.c_char_p, ctypes.c_char_p,
        ctypes.c_double, ctypes.c_double, ctypes.c_double, ctypes.c_double
    ]
    dll.gantry_register_analog_output.restype = ctypes.c_int

    # Process image access
    dll.gantry_read_digital.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.POINTER(ctypes.c_bool)]
    dll.gantry_read_digital.restype = ctypes.c_int

    dll.gantry_write_digital.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_bool]
    dll.gantry_write_digital.restype = ctypes.c_int

    dll.gantry_read_analog.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.POINTER(ctypes.c_double)]
    dll.gantry_read_analog.restype = ctypes.c_int

    dll.gantry_write_analog.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_double]
    dll.gantry_write_analog.restype = ctypes.c_int

    # Cyclic scan
    dll.gantry_step_cycle.argtypes = [ctypes.c_void_p]
    dll.gantry_step_cycle.restype = ctypes.c_int

    dll.gantry_get_cycle_stats.argtypes = [ctypes.c_void_p, ctypes.POINTER(GantryCycleStats)]
    dll.gantry_get_cycle_stats.restype = ctypes.c_int

    # Safety
    dll.gantry_add_interlock_rule.argtypes = [
        ctypes.c_void_p, ctypes.c_char_p, ctypes.c_char_p, ctypes.c_char_p,
        ctypes.c_bool, ctypes.c_int, ctypes.c_uint32
    ]
    dll.gantry_add_interlock_rule.restype = ctypes.c_int

    dll.gantry_trip_estop.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_char_p]
    dll.gantry_trip_estop.restype = ctypes.c_int

    dll.gantry_reset_estop.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
    dll.gantry_reset_estop.restype = ctypes.c_int

    dll.gantry_is_estop_active.argtypes = [ctypes.c_void_p]
    dll.gantry_is_estop_active.restype = ctypes.c_bool

    # SDT Compression
    dll.gantry_sdt_compress.argtypes = [
        ctypes.POINTER(ctypes.c_double),
        ctypes.POINTER(ctypes.c_double),
        ctypes.c_size_t,
        ctypes.c_double,
        ctypes.POINTER(ctypes.c_double),
        ctypes.POINTER(ctypes.c_double),
        ctypes.POINTER(ctypes.c_size_t),
    ]
    dll.gantry_sdt_compress.restype = ctypes.c_int

    # Plant simulations
    dll.gantry_plant_create.argtypes = [ctypes.c_char_p, ctypes.c_void_p]
    dll.gantry_plant_create.restype = ctypes.c_void_p

    dll.gantry_plant_step.argtypes = [ctypes.c_void_p, ctypes.c_double, ctypes.c_void_p]
    dll.gantry_plant_step.restype = ctypes.c_int

    dll.gantry_plant_destroy.argtypes = [ctypes.c_void_p]
    dll.gantry_plant_destroy.restype = None

    return dll


_lib = None

def get_lib() -> ctypes.CDLL:
    global _lib
    if _lib is None:
        _lib = _load_native_library()
    return _lib
