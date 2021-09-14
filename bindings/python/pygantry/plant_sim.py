"""
GANTRY Cyber-Physical Automation Runtime
Cyber-Physical Simulation Plant Binding

Copyright (C) 2026 Aneesh Krishna. All rights reserved.
"""

from typing import Any, Callable, Optional, Union
from ._native import get_lib
from .core import GantryEngine, GantryEngineError
from .enums import PlantType


class GantryPlant:
    """
    Continuous physical plant simulation model coupled to the Gantry process image.
    Supports container crane pendulum sway, CSTR exothermic reaction, and railway turnout.
    """

    def __init__(self, plant_type: Union[PlantType, str], engine: GantryEngine):
        self._lib = get_lib()
        self._engine = engine
        type_str = plant_type.value if isinstance(plant_type, PlantType) else str(plant_type)
        self._type = type_str

        self._handle = self._lib.gantry_plant_create(
            type_str.encode("utf-8"), engine.handle
        )
        if not self._handle:
            raise GantryEngineError(f"Failed to create simulation plant '{type_str}'")

    @property
    def plant_type(self) -> str:
        return self._type

    @property
    def engine(self) -> GantryEngine:
        return self._engine

    def step(self, dt_sec: float) -> None:
        """Advance plant differential equations by dt_sec and synchronize I/O."""
        if not self._handle:
            raise GantryEngineError("Plant has been destroyed")
        rc = self._lib.gantry_plant_step(self._handle, float(dt_sec), self._engine.handle)
        if rc != 0:
            raise GantryEngineError(f"Plant step failed with code {rc}")

    def run(
        self,
        duration_sec: float,
        dt_sec: float = 0.05,
        step_callback: Optional[Callable[[float, GantryEngine], None]] = None,
    ) -> None:
        """Runs the simulation loop for a set duration, stepping both plant and cyclic engine."""
        t = 0.0
        while t < duration_sec:
            self.step(dt_sec)
            self._engine.step_cycle()
            if step_callback:
                step_callback(t, self._engine)
            t += dt_sec

    def close(self) -> None:
        if self._handle:
            self._lib.gantry_plant_destroy(self._handle)
            self._handle = None

    def __enter__(self) -> "GantryPlant":
        return self

    def __exit__(self, exc_type: Any, exc_val: Any, exc_tb: Any) -> None:
        self.close()

    def __del__(self) -> None:
        self.close()
