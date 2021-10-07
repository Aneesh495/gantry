# pygantry: Python SDK Developer Guide

`pygantry` is the official Python SDK for the Gantry cyber-physical automation runtime. It provides Pythonic bindings to Gantry's deterministic cyclic executive, safety interlocking matrix, Swinging Door Trending (SDT) lossy compression, and physical plant simulation models via ctypes and `libgantry.dylib`.

## Installation

`pygantry` requires Python 3.10+ and the compiled `libgantry` native library.

```bash
# Build native C shared library
make lib

# Install pygantry in editable development mode
pip install -e bindings/python
```

---

## Quickstart Guide

### 1. Engine Initialization & I/O Points
`GantryEngine` manages cyclic execution and the process image table. It supports pythonic dictionary syntax for point reads and writes:

```python
from pygantry import GantryEngine

with GantryEngine(name="MAIN_PLC", scan_period_us=1000) as engine:
    # Register digital points
    engine.register_digital_input("DI_RUN_PB", desc="Start Pushbutton", active_high=True)
    engine.register_digital_output("DO_CONVEYOR_RUN", desc="Conveyor Contactor", fail_safe_val=False)

    # Register analog points
    engine.register_analog_input("AI_LINE_PRESSURE", desc="Header Pressure", eu="bar", raw_min=0, raw_max=100)
    engine.register_analog_output("AO_VFD_SPEED_CMD", desc="Motor Speed", eu="Hz", raw_min=0, raw_max=60)

    # Write and read values via item access syntax
    engine["DO_CONVEYOR_RUN"] = True
    engine["AO_VFD_SPEED_CMD"] = 48.5

    # Step deterministic cycle
    engine.step_cycle()

    # Query cyclic telemetry stats
    stats = engine.get_stats()
    print(f"Total Cycles: {stats['total_cycles']}, Avg Scan: {stats['avg_scan_us']:.2f} us")
```

---

### 2. SIL-3 / SIL-4 Safety Interlocking
Add deterministic Cause-and-Effect Matrix (CEM) rules to unconditionally enforce fail-safe states:

```python
from pygantry import GantryEngine, SilLevel

with GantryEngine("SAFETY_PLC") as engine:
    engine.register_digital_input("OVERPRESSURE_SWITCH", "High Pressure Switch")
    engine.register_digital_output("INLET_FEED_VALVE", "Reactant Valve", fail_safe_val=False)

    # Configure SIL-3 interlock rule:
    # If OVERPRESSURE_SWITCH trips True, force INLET_FEED_VALVE False (closed)
    engine.add_interlock_rule(
        rule_id="RULE_ESD_01",
        cause_tag="OVERPRESSURE_SWITCH",
        effect_tag="INLET_FEED_VALVE",
        effect_trip_val=False,
        sil=SilLevel.SIL_3,
    )

    engine["INLET_FEED_VALVE"] = True
    engine.step_cycle()
    assert engine["INLET_FEED_VALVE"] is True

    # Cause trip condition
    engine["OVERPRESSURE_SWITCH"] = True
    engine.step_cycle()
    assert engine["INLET_FEED_VALVE"] is False  # Safe fail-safe override enforced!
```

---

### 3. Swinging Door Trending (SDT) Compression
Compress continuous time-series streams with mathematically bounded error:

```python
from pygantry import SDTCompressor
import math

compressor = SDTCompressor(deviation=0.15)

timestamps = [float(i) * 0.1 for i in range(200)]
values = [50.0 + 0.05 * math.sin(i) for i in range(200)]  # Flat sensor noise

compressed_ts, compressed_vals = compressor.compress(timestamps, values)
ratio = SDTCompressor.compression_ratio(len(timestamps), len(compressed_ts))

print(f"Compressed {len(timestamps)} samples to {len(compressed_ts)} points ({ratio:.1f}% bandwidth reduction)")
```

---

### 4. Continuous Physical Plant Simulations
Coupling realistic continuous ODE physics to discrete process controls:

```python
from pygantry import GantryEngine, GantryPlant, PlantType

with GantryEngine("CRANE_CONTROLLER") as engine:
    with GantryPlant(PlantType.CRANE, engine) as crane:
        # Command forward thrust and hoist cable lowering
        engine["CRANE_TROLLEY_FORCE_CMD"] = 45.0  # 45 kN
        engine["CRANE_HOIST_VEL_CMD"] = 0.5       # 0.5 m/s

        # Run 50 simulation steps at dt = 0.05s
        crane.run(duration_sec=2.5, dt_sec=0.05)

        print(f"Trolley Position: {engine['CRANE_TROLLEY_POS']:.2f} m")
        print(f"Sway Angle:       {engine['CRANE_SWAY_ANGLE']:.2f} deg")
```
