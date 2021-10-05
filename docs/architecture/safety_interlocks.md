# Safety Interlocks, TMR Voting & Cause-and-Effect Matrix

Gantry implements formal safety architecture patterned after IEC 61508 and ISA-84 / IEC 61511 standards, ensuring that life-critical and asset-critical equipment is safeguarded against hazardous mechanical or thermal conditions.

## Cause-and-Effect Matrix (CEM)

The Cause-and-Effect Matrix (`GANTRY_CAUSE_EFFECT_MATRIX`) correlates discrete initiating events (causes) to deterministic safety shut-down actions (effects).

```
+-------------------------------------------------------------------------------+
|                       CAUSE AND EFFECT SHUTDOWN MATRIX                        |
+-------------------+---------------------+------------------+-----------+------+
| CAUSE TAG         | THRESHOLD CONDITION | EFFECT ACTUATOR  | SAFE VAL  | SIL  |
+-------------------+---------------------+------------------+-----------+------+
| CRANE_SWAY_HIGH   | abs(sway) > 15.0 deg| TROLLEY_MOTOR_EN | FALSE     | SIL-3|
| CRANE_LIMIT_WEST  | West LS Contact Open| TROLLEY_DIR_WEST | FALSE     | SIL-3|
| REACTOR_OVERPRESS | Pressure >= 85.0 bar| EMERGENCY_VENT   | TRUE      | SIL-4|
| REACTOR_OVERTEMP  | Temp >= 110.0 degC  | FEED_PUMP_ENABLE | FALSE     | SIL-3|
| RAIL_TC2_OCCUPIED | Fouling Section Occ | POINT_MACHINE_EN | FALSE     | SIL-4|
+-------------------+---------------------+------------------+-----------+------+
```

### Safety Integrity Levels (SIL)
Rules are categorized according to IEC 61508 target safety integrity levels:
* **SIL-1**: Low risk mitigation (Probability of Failure on Demand: 10^-2 to 10^-1).
* **SIL-2**: Moderate operational protection (PFD: 10^-3 to 10^-2).
* **SIL-3**: High-consequence industrial machinery protection (PFD: 10^-4 to 10^-3).
* **SIL-4**: Highest-consequence catastrophic prevention (PFD: 10^-5 to 10^-4).

## 2oo3 Triple Modular Redundancy (TMR) Voting

In mission-critical sensor architectures, single sensor failures can cause spurious plant trips or unrevealed dangerous failures. `GANTRY_TMR_VOTER` implements 2-out-of-3 (2oo3) majority voting:

### Discrete Voting
Given three independent sensor channels ($A$, $B$, $C$), the voted safe output is evaluated as:
$$V = (A \land B) \lor (B \land C) \lor (A \land C)$$

### Analog Voting & Discrepancy Detection
For continuous analog instruments (e.g. triple pressure transmitters on a high-pressure vessel):
1. **Median Selection**: When all three channels are healthy, the median value is propagated as the representative process measurement.
2. **Channel Discrepancy Isolation**: If one channel deviates from the other two by more than the configured tolerance band:
   * The anomalous channel is flagged with `discrepancy_detected`.
   * The voter falls back to an average of the two agreeable channels.
   * A diagnostic maintenance alarm is annunciated.

## Interlock Directed Dependency Graph & Cycle Detection

Complex safety systems often involve cascading interlocks where the output of one safety shutdown triggers initiating inputs for secondary subsystems. If mutual dependencies exist between safety rules, cyclic deadlocks can paralyze safety execution.

`GANTRY_INTERLOCK_GRAPH` maintains a formal directed graph of interlock dependencies:
* Nodes represent process tags and interlock rules.
* Directed edges represent causal propagation.
* A cycle detection routine executes Tarjan's or Depth-First Search (DFS) three-color traversal (WHITE, GREY, BLACK) to mathematically prove the absence of circular deadlock loops before runtime activation.

## Continuous Safety Envelopes

`GANTRY_SAFETY_ENVELOPE` validates continuous kinematic and dynamic state vectors:
* Positional travel boundaries (e.g. carriage travel clamp at 0.5m and 79.5m).
* Maximum velocity rate limits (e.g. winch maximum lowering speed <= 3.0 m/s).
* Mutual exclusion zones (e.g. preventing container trolley travel when spreader twistlocks are partially unlocked).

## Latching Emergency Stop (E-Stop)

`GANTRY_EMERGENCY_STOP` enforces the strict standard requirement that physical Emergency Stop trips must latch mechanically and logically:
* **Trip Action**: Any E-Stop initiator immediately latches the engine into fail-safe de-energization.
* **Non-Volatile Lock**: Clearing the physical sensor does NOT clear the E-Stop state.
* **Supervised Reset**: The E-Stop can only be cleared through an explicit reset command verifying that all field contacts are closed and operator authorization has been authenticated.
