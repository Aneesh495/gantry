"""
GANTRY Cyber-Physical Automation Runtime
Swinging Door Trending (SDT) Compression Engine

Copyright (C) 2026 Aneesh Krishna. All rights reserved.
"""

import ctypes
from typing import List, Tuple
from ._native import get_lib
from .core import GantryEngineError


class SDTCompressor:
    """
    Industrial Swinging Door Trending (SDT) compression filter.
    Compresses high-frequency telemetry time series streams while guaranteeing
    bounded reconstruction error <= compression_deviation.
    """

    def __init__(self, deviation: float = 0.1):
        if deviation <= 0.0:
            raise ValueError("compression_deviation must be positive")
        self.deviation = float(deviation)
        self._lib = get_lib()

    def compress(
        self, timestamps: List[float], values: List[float]
    ) -> Tuple[List[float], List[float]]:
        """
        Compresses time-series vectors using the native SDT C kernel.
        Returns (compressed_timestamps, compressed_values).
        """
        if len(timestamps) != len(values):
            raise ValueError("timestamps and values must have identical lengths")

        n = len(timestamps)
        if n == 0:
            return [], []

        c_ts = (ctypes.c_double * n)(*timestamps)
        c_val = (ctypes.c_double * n)(*values)
        out_ts = (ctypes.c_double * n)()
        out_val = (ctypes.c_double * n)()
        out_count = ctypes.c_size_t(0)

        rc = self._lib.gantry_sdt_compress(
            c_ts,
            c_val,
            n,
            self.deviation,
            out_ts,
            out_val,
            ctypes.byref(out_count),
        )
        if rc != 0:
            raise GantryEngineError(f"SDT compression kernel failed with code {rc}")

        k = out_count.value
        return list(out_ts[:k]), list(out_val[:k])

    @staticmethod
    def compression_ratio(raw_count: int, compressed_count: int) -> float:
        if raw_count == 0:
            return 0.0
        return (1.0 - (compressed_count / raw_count)) * 100.0
