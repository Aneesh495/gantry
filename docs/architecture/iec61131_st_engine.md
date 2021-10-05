# IEC 61131-3 Structured Text Execution Engine

Gantry includes a native parser, compiler, and stack virtual machine executing programs written in IEC 61131-3 Structured Text (ST), the standard high-level algorithmic language for industrial programmable controllers.

## Compiler Pipeline Architecture

```
  +-------------------------------------------------------------+
  |              Structured Text Source Code (.st)              |
  |  tank_press := 92.5; IF tank_press > 85.0 THEN ... END_IF;  |
  +------------------------------+------------------------------+
                                 |
  +------------------------------v------------------------------+
  |                    1. Lexical Tokenizer                     |
  |  DFA tokenizer scanning keywords, identifiers, literals     |
  +------------------------------+------------------------------+
                                 |
  +------------------------------v------------------------------+
  |                   2. Pratt Syntax Parser                    |
  |  Operator precedence parsing & AST statement generation     |
  +------------------------------+------------------------------+
                                 |
  +------------------------------v------------------------------+
  |                   3. Bytecode Code Generator                |
  |  Linear instruction set emitter with jump address patching  |
  +------------------------------+------------------------------+
                                 |
  +------------------------------v------------------------------+
  |                 4. Stack Virtual Machine (VM)               |
  |  Deterministic execution engine coupled to image table      |
  +-------------------------------------------------------------+
```

## Abstract Syntax Tree (AST) Hierarchy

The AST model consists of distinct node types:
* **Statements (`GANTRY_ST_STMT_NODE`)**:
  - `Assignment`: Variable assignment (`variable := expression`).
  - `If Statement`: Branching conditional with optional `ELSIF` and `ELSE` branches.
  - `While Loop`: Bounded conditional repetition.
  - `For Loop`: Iteration over integer bounds.
* **Expressions (`GANTRY_ST_EXPR_NODE`)**:
  - Binary arithmetic operators (`+`, `-`, `*`, `/`, `MOD`, `^`).
  - Comparison operators (`=`, `<>`, `<`, `<=`, `>`, `>=`).
  - Logical boolean operators (`AND`, `OR`, `NOT`, `XOR`).
  - Identifier references and literal constants.

## Virtual Machine Bytecode Instruction Set

The VM executes a compact, 16-bit opcode instruction set:

| Opcode | Mnemonic | Operand Type | Description |
|---|---|---|---|
| 0x01 | `NOP` | None | No operation |
| 0x02 | `PUSH_INT` | `INTEGER_64` | Push 64-bit signed integer onto operand stack |
| 0x03 | `PUSH_REAL`| `REAL_64` | Push 64-bit IEEE 754 floating point number |
| 0x04 | `PUSH_BOOL`| `BOOLEAN` | Push boolean flag |
| 0x05 | `LOAD_VAR` | `STRING` | Read point value from process image table |
| 0x06 | `STORE_VAR`| `STRING` | Write top-of-stack value to process image table |
| 0x07 | `ADD` | None | Pop top two items, push sum |
| 0x08 | `SUB` | None | Pop top two items, push difference |
| 0x09 | `MUL` | None | Pop top two items, push product |
| 0x0A | `DIV` | None | Pop top two items, push quotient |
| 0x0B | `MOD` | None | Pop top two items, push modulo |
| 0x0C | `AND` | None | Pop top two items, push logical AND |
| 0x0D | `OR` | None | Pop top two items, push logical OR |
| 0x0E | `NOT` | None | Invert top boolean item |
| 0x0F | `EQ` | None | Compare equality |
| 0x10 | `NEQ` | None | Compare inequality |
| 0x11 | `LT` | None | Less than comparison |
| 0x12 | `LTE` | None | Less than or equal comparison |
| 0x13 | `GT` | None | Greater than comparison |
| 0x14 | `GTE` | None | Greater than or equal comparison |
| 0x15 | `JMP` | `INTEGER` | Unconditional jump to bytecode instruction offset |
| 0x16 | `JZ` | `INTEGER` | Jump to offset if top of stack is False / zero |
| 0x17 | `JNZ` | `INTEGER` | Jump to offset if top of stack is True / non-zero |
| 0xFF | `HALT` | None | Terminate execution for current cyclic scan |

## Standard Function Blocks (IEC 61131-3)

Gantry implements the standard suite of reusable function blocks:
* **Timers**:
  - `TON`: On-delay timer. Delays output activation until input has remained True for preset duration `PT`.
  - `TOF`: Off-delay timer. Maintains output True for duration `PT` after input falls to False.
  - `TP`: Pulse timer. Generates a fixed-duration output pulse regardless of input duration.
* **Edge Detectors**:
  - `R_TRIG`: Rising-edge detector. Emits single-cycle True pulse on False-to-True transitions.
  - `F_TRIG`: Falling-edge detector. Emits single-cycle True pulse on True-to-False transitions.
* **Counters**:
  - `CTU`: Up-counter with limit detection.
  - `CTD`: Down-counter with underflow protection.
  - `CTUD`: Bidirectional up/down counter.
* **Bistable Elements**:
  - `SR`: Set-dominant flip-flop latch.
  - `RS`: Reset-dominant flip-flop latch.
* **Control**:
  - `PID`: Continuous Proportional-Integral-Derivative controller with anti-windup clamping, derivative filtering, and manual override tracking.
