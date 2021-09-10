"""
GANTRY Cyber-Physical Automation Runtime
High-Assurance Engine Pythonic Wrapper

Copyright (C) 2026 Aneesh Krishna. All rights reserved.
"""

import ctypes
from typing import Any, Dict, Optional, Union
from ._native import get_lib, GantryCycleStats
from .enums import SilLevel


class GantryEngineError(Exception):
    """Raised when native engine operations fail."""
    pass


class GantryEngine:
    """
    Pythonic interface to the Gantry deterministic cyclic runtime engine.
    Provides memory-mapped process image table access, safety interlocking,
    and microsecond jitter telemetry.
    """

    def __init__(self, name: str = "CONTROLLER_01", scan_period_us: int = 1000):
        self._lib = get_lib()
        self._name = name
        self._scan_period_us = scan_period_us
        self._handle = self._lib.gantry_engine_create(name.encode("utf-8"), scan_period_us)
        if not self._handle:
            raise GantryEngineError(f"Failed to create Gantry engine '{name}'")
        self._point_types: Dict[str, str] = {}  # tag -> 'digital' or 'analog'

    @property
    def name(self) -> str:
        return self._name

    @property
    def scan_period_us(self) -> int:
        return self._scan_period_us

    @property
    def handle(self) -> int:
        return self._handle

    def close(self) -> None:
        if self._handle:
            self._lib.gantry_engine_destroy(self._handle)
            self._handle = None

    def __enter__(self) -> "GantryEngine":
        return self

    def __exit__(self, exc_type: Any, exc_val: Any, exc_tb: Any) -> None:
        self.close()

    def __del__(self) -> None:
        self.close()

    def _check_handle(self) -> None:
        if not self._handle:
            raise GantryEngineError("GantryEngine has been closed or destroyed")

    def register_digital_input(
        self, tag: str, desc: str = "", active_high: bool = True, debounce_ms: int = 0
    ) -> None:
        self._check_handle()
        rc = self._lib.gantry_register_digital_input(
            self._handle,
            tag.encode("utf-8"),
            desc.encode("utf-8"),
            active_high,
            debounce_ms,
        )
        if rc != 0:
            raise GantryEngineError(f"Failed to register digital input '{tag}', code {rc}")
        self._point_types[tag] = "digital"

    def register_digital_output(
        self, tag: str, desc: str = "", fail_safe_val: bool = False
    ) -> None:
        self._check_handle()
        rc = self._lib.gantry_register_digital_output(
            self._handle,
            tag.encode("utf-8"),
            desc.encode("utf-8"),
            fail_safe_val,
        )
        if rc != 0:
            raise GantryEngineError(f"Failed to register digital output '{tag}', code {rc}")
        self._point_types[tag] = "digital"

    def register_analog_input(
        self,
        tag: str,
        desc: str = "",
        eu: str = "",
        raw_min: float = 0.0,
        raw_max: float = 100.0,
        eu_min: float = 0.0,
        eu_max: float = 100.0,
    ) -> None:
        self._check_handle()
        rc = self._lib.gantry_register_analog_input(
            self._handle,
            tag.encode("utf-8"),
            desc.encode("utf-8"),
            eu.encode("utf-8"),
            raw_min,
            raw_max,
            eu_min,
            eu_max,
        )
        if rc != 0:
            raise GantryEngineError(f"Failed to register analog input '{tag}', code {rc}")
        self._point_types[tag] = "analog"

    def register_analog_output(
        self,
        tag: str,
        desc: str = "",
        eu: str = "",
        raw_min: float = 0.0,
        raw_max: float = 100.0,
        eu_min: float = 0.0,
        eu_max: float = 100.0,
    ) -> None:
        self._check_handle()
        rc = self._lib.gantry_register_analog_output(
            self._handle,
            tag.encode("utf-8"),
            desc.encode("utf-8"),
            eu.encode("utf-8"),
            raw_min,
            raw_max,
            eu_min,
            eu_max,
        )
        if rc != 0:
            raise GantryEngineError(f"Failed to register analog output '{tag}', code {rc}")
        self._point_types[tag] = "analog"

    def read_digital(self, tag: str) -> bool:
        self._check_handle()
        out_val = ctypes.c_bool()
        rc = self._lib.gantry_read_digital(self._handle, tag.encode("utf-8"), ctypes.byref(out_val))
        if rc != 0:
            raise GantryEngineError(f"Failed to read digital tag '{tag}', code {rc}")
        return out_val.value

    def write_digital(self, tag: str, val: bool) -> None:
        self._check_handle()
        rc = self._lib.gantry_write_digital(self._handle, tag.encode("utf-8"), val)
        if rc != 0:
            raise GantryEngineError(f"Failed to write digital tag '{tag}', code {rc}")

    def read_analog(self, tag: str) -> float:
        self._check_handle()
        out_val = ctypes.c_double()
        rc = self._lib.gantry_read_analog(self._handle, tag.encode("utf-8"), ctypes.byref(out_val))
        if rc != 0:
            raise GantryEngineError(f"Failed to read analog tag '{tag}', code {rc}")
        return out_val.value

    def write_analog(self, tag: str, val: float) -> None:
        self._check_handle()
        rc = self._lib.gantry_write_analog(self._handle, tag.encode("utf-8"), float(val))
        if rc != 0:
            raise GantryEngineError(f"Failed to write analog tag '{tag}', code {rc}")

    def __getitem__(self, tag: str) -> Union[bool, float]:
        pt_type = self._point_types.get(tag)
        if pt_type == "digital":
            return self.read_digital(tag)
        elif pt_type == "analog":
            return self.read_analog(tag)

        # Tag not explicitly registered via Python; try analog then digital
        try:
            val = self.read_analog(tag)
            self._point_types[tag] = "analog"
            return val
        except GantryEngineError:
            val = self.read_digital(tag)
            self._point_types[tag] = "digital"
            return val

    def __setitem__(self, tag: str, val: Union[bool, int, float]) -> None:
        if isinstance(val, bool):
            self.write_digital(tag, val)
            self._point_types[tag] = "digital"
        else:
            self.write_analog(tag, float(val))
            self._point_types[tag] = "analog"

    def step_cycle(self) -> None:
        self._check_handle()
        rc = self._lib.gantry_step_cycle(self._handle)
        if rc != 0:
            raise GantryEngineError(f"Cyclic execution step failed, code {rc}")

    def get_stats(self) -> Dict[str, Union[int, float]]:
        self._check_handle()
        stats = GantryCycleStats()
        rc = self._lib.gantry_get_cycle_stats(self._handle, ctypes.byref(stats))
        if rc != 0:
            raise GantryEngineError(f"Failed to retrieve cycle statistics, code {rc}")
        return {
            "total_cycles": stats.total_cycles,
            "total_overruns": stats.total_overruns,
            "last_scan_us": stats.last_scan_us,
            "avg_scan_us": stats.avg_scan_us,
            "max_scan_us": stats.max_scan_us,
            "last_jitter_us": stats.last_jitter_us,
            "max_jitter_us": stats.max_jitter_us,
        }

    def add_interlock_rule(
        self,
        rule_id: str,
        cause_tag: str,
        effect_tag: str,
        effect_trip_val: bool = False,
        sil: SilLevel = SilLevel.SIL_3,
        trip_delay_ms: int = 0,
    ) -> None:
        self._check_handle()
        rc = self._lib.gantry_add_interlock_rule(
            self._handle,
            rule_id.encode("utf-8"),
            cause_tag.encode("utf-8"),
            effect_tag.encode("utf-8"),
            effect_trip_val,
            int(sil),
            trip_delay_ms,
        )
        if rc != 0:
            raise GantryEngineError(f"Failed to add interlock rule '{rule_id}', code {rc}")

    def trip_estop(self, operator_id: str = "OPERATOR", reason: str = "Emergency Stop Trip") -> None:
        self._check_handle()
        rc = self._lib.gantry_trip_estop(
            self._handle, operator_id.encode("utf-8"), reason.encode("utf-8")
        )
        if rc != 0:
            raise GantryEngineError(f"Failed to trip Emergency Stop, code {rc}")

    def reset_estop(self, operator_id: str = "OPERATOR") -> None:
        self._check_handle()
        rc = self._lib.gantry_reset_estop(self._handle, operator_id.encode("utf-8"))
        if rc != 0:
            raise GantryEngineError(f"Failed to reset Emergency Stop, code {rc}")

    @property
    def is_estop_active(self) -> bool:
        self._check_handle()
        return bool(self._lib.gantry_is_estop_active(self._handle))
