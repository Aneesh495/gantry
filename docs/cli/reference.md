# GANTRY Command Line Interface Reference

The `gantry` porcelain executable provides operators, engineers, and automated test runners with commands to inspect the runtime, simulate cyber-physical plants, compile IEC 61131-3 Structured Text programs, and execute high-assurance verification passes.

## Synopsis

```bash
gantry <command> [options]
```

## Global Commands

### `version`
Displays runtime build information, target architectures, standards compliance, and Design by Contract configuration.

```bash
gantry version
# Output:
# Version:            1.0.0 (Production Release)
# Language:           Eiffel (ISO/ECMA-367 Standard)
# Safety Standard:    IEC 61508 SIL-3 / SIL-4 Deterministic Architecture
# PLC Standard:       IEC 61131-3 Structured Text Stack Virtual Machine
# Alarms:             ISA-18.2 / ANSI Lifecycle State Machine
# Historian:          Swinging Door Trending (SDT) Lossy Compression
# Protocols:          Modbus TCP/IP, OPC UA, DNP3 FT3, MQTT-SN
# FFI:                ANSI C shared library (libgantry) & Python SDK
```

### `help`
Prints the top-level command reference and usage examples.

```bash
gantry help
```

---

## Subcommands

### `run [crane|reactor|rail]`
Initializes the deterministic cyclic executive and attaches the specified cyber-physical plant simulation model, stepping through real-time scan cycles and streaming telemetry to the console.

#### Options:
* `crane` (default): Automated ship-to-shore (STS) container gantry crane with nonlinear pendulum sway dynamics and boundary limit switches.
* `reactor`: Continuous stirred-tank chemical reactor (CSTR) with exothermic runaway kinetics, cooling jacket flow, and emergency burst disc rupture.
* `rail`: Railway turnout interlocking with track circuit occupancy (TC1 to TC4), motorized points machine, and automatic block signals.

```bash
# Run container crane plant simulation:
gantry run crane

# Run chemical reactor plant simulation:
gantry run reactor

# Run railway turnout interlocking simulation:
gantry run rail
```

### `compile`
Tokenizes, parses, and compiles an IEC 61131-3 Structured Text script into bytecode instructions, prints the disassembled opcode listing, and executes the compiled program on the stack virtual machine with full process image table bindings.

```bash
gantry compile
# Outputs:
# --- SOURCE CODE ---
# tank_press := 92.5;
# IF tank_press > 85.0 THEN
#   inlet_valve := FALSE;
# ELSE
#   inlet_valve := TRUE;
# END_IF;
#
# --- DISASSEMBLED BYTECODE ---
# [0] PUSH_REAL 92.5
# [1] STORE_VAR tank_press
# [2] LOAD_VAR tank_press
# [3] PUSH_REAL 85
# [4] GT
# [5] JZ -> 10
# [6] PUSH_BOOL False
# [7] STORE_VAR inlet_valve
# [8] JMP -> 12
# [9] PUSH_BOOL True
# [10] STORE_VAR inlet_valve
# [11] HALT
```

### `sdt`
Executes a high-throughput demonstration of the Swinging Door Trending (SDT) lossy compression algorithm, feeding 100 continuous sensor points with steady plateaus and linear ramps, and reporting the resulting bandwidth compression ratio.

```bash
gantry sdt
# Outputs:
# Total raw input samples:       100
# Total retained archive points: 2
# Bandwidth compression ratio:   98%
```

### `test`
Instructs the operator how to execute the comprehensive 7-subsystem verification suite across Core, PLC, Safety, Protocols, Historian, Alarms, and Simulation models.

```bash
gantry test
```
