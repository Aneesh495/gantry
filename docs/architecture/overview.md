# GANTRY System Architecture Overview

Gantry is a high-assurance cyber-physical automation runtime, deterministic cyclic executive, and formal safety interlock platform implemented primarily in Eiffel with ANSI C FFI bindings and a Python SDK (`pygantry`). Designed in accordance with IEC 61508 (Functional Safety) and IEC 61131-3 (Programmable Controllers), Gantry delivers sub-millisecond real-time deterministic execution, formal contract-verified telemetry, triple-modular redundant voting, and lossy compression history.

## High-Level Architectural Layout

```
+-------------------------------------------------------------------------+
|                        SUPERVISORY CONTROL LAYER                        |
|   +-----------------------+  +-------------------+  +---------------+   |
|   | Operator SCADA (Web)  |  | Python SDK (py)   |  | CLI (gantry)  |   |
|   +-----------------------+  +-------------------+  +---------------+   |
+-------------------------------------------------------------------------+
                                   | (C ABI / Shared Library libgantry)
+----------------------------------v--------------------------------------+
|                     INDUSTRIAL PROTOCOL GATEWAY                         |
|   +---------------+  +---------------+  +------------+  +-----------+   |
|   |  Modbus TCP   |  |    OPC UA     |  |  DNP3 FT3  |  |  MQTT-SN  |   |
|   +---------------+  +---------------+  +------------+  +-----------+   |
+-------------------------------------------------------------------------+
                                   | (Process Image Table %I / %Q / %M)
+----------------------------------v--------------------------------------+
|                   DETERMINISTIC CYCLIC EXECUTIVE                        |
|                                                                         |
|   Phase 1: Field Input Sampling & Anti-Aliasing Quality Tagging         |
|   Phase 2: Signal Debouncing & Engineering Zero-Span Scaling            |
|   Phase 3: IEC 61131-3 Structured Text Bytecode VM Execution            |
|   Phase 4: ISA-84 / IEC 61508 SIL-3/4 Cause & Effect Matrix (CEM)       |
|   Phase 5: 2oo3 Triple Modular Redundancy (TMR) Voter Execution         |
|   Phase 6: Fail-Safe Physical Output Latch & Deadline Watchdog Kick     |
+-------------------------------------------------------------------------+
       |                                                    |
+------v----------------------------------+  +--------------v-------------+
|    SOE HISTORIAN & SDT COMPRESSION      |  |   ISA-18.2 ALARM ENGINE    |
|   - Ring Buffer FIFO Queue              |  |   - Deadband & Hysteresis  |
|   - Swinging Door Trending Filter       |  |   - Rationalized States    |
|   - Microsecond Event Journal           |  |   - Priority Annunciator   |
+-----------------------------------------+  +----------------------------+
```

## Core Engineering Principles

### 1. Design by Contract (DbC)
Every operational routine, class invariant, and state transition within Gantry is formally bounded by Design by Contract preconditions (`require`), postconditions (`ensure`), and type invariants (`invariant`). The Eiffel runtime guarantees:
* All telemetry scaling routines verify `zero_span: raw_min < raw_max`.
* Memory-mapped image tables enforce mutual exclusion and freeze guarantees during active scan phases.
* Cyclic scan engines verify non-negative cycle durations and bounded jitter bounds.
* virtual machines enforce execution step limits to mathematically prevent infinite execution loops.

### 2. Deterministic Cyclic Execution
Industrial automation controllers must execute logic within strict, bounded time windows. Gantry separates logic execution into six distinct phases. The cyclic executive executes at a configurable target frequency (typically 100 Hz to 1000 Hz) with microsecond jitter tracking and an active hardware/software watchdog timer. If logic computation exceeds the deadline window, an overrun fault triggers fail-safe de-energization.

### 3. Separation of Safety from General Control
Following IEC 61508 SIL-3 and SIL-4 safety architectural patterns, safety interlocks operate independently from standard process control logic. Cause-and-Effect Matrix (CEM) rules and 2oo3 TMR voting logic are evaluated after general IEC 61131-3 logic routines, allowing safety systems to unconditionally override field outputs to de-energized, safe states when process limits are exceeded.

### 4. Zero Void-Safety Errors
The entire Eiffel codebase is compiled with complete void-safety enabled (`void_safety="all"`). Detachable references must be explicitly guarded with object tests (`attached`) prior to feature calls, eliminating null pointer exceptions across the entire automation engine.
