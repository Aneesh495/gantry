# Deterministic Cyclic Executive & Process Image Architecture

The Gantry runtime relies on a deterministic cyclic executive coordinated by `GANTRY_SCAN_ENGINE`, managing process memory, signal quality classification, microsecond jitter tracking, and fail-safe watchdog monitoring.

## 6-Phase Execution Pipeline

```
  +-------------------------------------------------------------+
  |              1. Field Input Sampling (%I)                   |
  |  Reads raw field sensors via industrial bus protocols       |
  +------------------------------+------------------------------+
                                 |
  +------------------------------v------------------------------+
  |         2. Debouncing, Zero-Span Scaling, & Quality         |
  |  Applies IEC 61850 quality flags and continuous scaling     |
  +------------------------------+------------------------------+
                                 |
  +------------------------------v------------------------------+
  |         3. IEC 61131-3 Structured Text Execution            |
  |  Executes control algorithms on stack virtual machine       |
  +------------------------------+------------------------------+
                                 |
  +------------------------------v------------------------------+
  |         4. Safety Interlock & Cause-and-Effect Matrix       |
  |  Enforces SIL-3/4 shut-down rules and envelope invariants   |
  +------------------------------+------------------------------+
                                 |
  +------------------------------v------------------------------+
  |         5. 2oo3 Triple Modular Redundancy (TMR) Voter       |
  |  Resolves sensor discrepancy and isolates field channel faults|
  +------------------------------+------------------------------+
                                 |
  +------------------------------v------------------------------+
  |              6. Fail-Safe Output Commit (%Q)                |
  |  Transfers output memory to field buses and kicks watchdog  |
  +-------------------------------------------------------------+
```

## Process Image Memory Architecture

Gantry implements isolated, memory-mapped process image partitions modeled after IEC 61131-3:
* **Digital Inputs (`%IX`)**: Field binary contact states, pushbuttons, and limit switches with microsecond timestamping and configurable debouncing filters.
* **Digital Outputs (`%QX`)**: Discrete field actuator coils, solenoid valves, and motor starter contactors.
* **Analog Inputs (`%IW`)**: High-resolution continuous sensor channels (thermocouples, 4-20mA pressure transmitters, encoders) with engineering zero-span linear conversion.
* **Analog Outputs (`%QW`)**: Continuous control commands (4-20mA valve positioners, VFD frequency commands).
* **Internal Memory (`%MX`, `%MD`)**: Volatile internal registers, scratch flags, and control loop variables.

## Microsecond Jitter and Overrun Tracking

Hard real-time deterministic executives must strictly bound timing variations. `GANTRY_CYCLIC_STATS` computes:
* **Last Scan Duration**: Execution latency of the most recent 6-phase scan in microseconds.
* **Average Scan Duration**: Continuous moving average of cycle computation time.
* **Peak Scan Duration**: Maximum recorded execution time across all cycles.
* **Scan Jitter**: Absolute delta between actual execution duration and configured target period:
  `jitter_us = abs(scan_duration_us - target_period_us)`
* **Overrun Counter**: Cumulative count of scan executions that exceeded the target deadline.

## Fail-Safe Watchdog Protection

An active hardware/software watchdog (`GANTRY_WATCHDOG`) enforces fail-safe shutdown:
* The watchdog must be refreshed ("kicked") on every successfully completed cycle.
* If a software deadlock, endless loop, or hardware delay prevents execution before `watchdog_timeout_ms`, the watchdog trips.
* Upon a trip condition, `GANTRY_SCAN_ENGINE` automatically enters a faulted state, forcing all digital and analog outputs to their configured fail-safe safe values (e.g. de-energizing contactors, opening relief valves, and disabling drive enables).
