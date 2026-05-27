# Dual-Core TinyRV Processor on FPGA

A dual-core TinyRV processor system implemented in Verilog for FPGA deployment. The project began as a single-core multicycle TinyRV processor and was extended into a dual-core shared-memory system with arbitration, per-core stalling, FPGA debug visibility, and TinyRV programs demonstrating race conditions and Peterson-lock mutual exclusion.

## Overview

This project implements a TinyRV processor system in Verilog. The design supports a multicycle processor datapath with instruction fetch, decode, execute, memory, and writeback behavior controlled by a finite-state machine.

The advanced version extends the processor into a **dual-core system**. Each core has its own program counter, instruction memory, register file, decode/control path, ALU, and multicycle control FSM. Both cores share a common data memory through request/grant arbitration logic.

The design demonstrates several core computer architecture concepts:

- multicycle processor design
- instruction decoding
- register-file design
- ALU operation
- program counter update logic
- branch and jump handling
- load/store memory access
- shared-memory multiprocessing
- memory arbitration
- per-core stalling
- race conditions
- mutual exclusion using Peterson's algorithm
- FPGA-based debugging and hardware visibility

---

## Project Highlights

- Implemented a multicycle TinyRV processor in Verilog
- Extended the design into a dual-core processor system
- Used private instruction memories for each core
- Used shared data memory across both cores
- Implemented request/grant arbitration for simultaneous memory requests
- Added per-core stalling when a core loses arbitration
- Wrote TinyRV programs demonstrating both unlocked race behavior and Peterson-lock synchronization
- Added FPGA debug modes for inspecting processor state
- Added board-level indicators for memory requests, grants, simultaneous requests, selected core, and memory-test mode
- Synthesized the design for a Cyclone V FPGA target

---

## Architecture

At a high level, the system contains two TinyRV cores connected to a shared data memory.

```text
                  +----------------------+
                  |  Instruction Memory 0 |
                  +----------+-----------+
                             |
                             v
                    +----------------+
                    |  TinyRV Core 0 |
                    | PC / RF / ALU  |
                    +-------+--------+
                            |
                            | memory request
                            v
                    +----------------+
                    | Memory Arbiter |
                    +-------+--------+
                            |
                            v
                    +----------------+
                    | Shared Data    |
                    | Memory         |
                    +----------------+
                            ^
                            |
                            | memory request
                    +-------+--------+
                    |  TinyRV Core 1 |
                    | PC / RF / ALU  |
                    +-------+--------+
                             ^
                             |
                  +----------+-----------+
                  |  Instruction Memory 1 |
                  +----------------------+
```

Each core executes its own instruction stream. The cores operate concurrently, but only one core can access shared data memory at a time. If both cores request memory during the same cycle, the arbiter grants access to one core and stalls the other until memory is available.

---

## Core Datapath

Each TinyRV core contains the major components of a simple multicycle processor:

```text
Instruction Memory
        |
        v
Instruction Register
        |
        v
Decode / Immediate Generation
        |
        v
Register File ---> ALU ---> Data Memory
        ^                      |
        |                      v
        +------ Writeback <----+
```

Major per-core components include:

| Component | Description |
|---|---|
| Program Counter | Tracks the current instruction address for each core |
| Instruction Memory | Stores the TinyRV program for each core |
| Instruction Register | Holds the fetched instruction |
| Decoder | Extracts opcode, register fields, function bits, and immediates |
| Control Unit | Generates control signals for each instruction type |
| Register File | Contains 32 general-purpose registers |
| ALU | Performs arithmetic, logic, shift, comparison, and address calculations |
| Data Memory Interface | Handles load/store requests to shared memory |
| Writeback Logic | Selects ALU, memory, PC+4, or immediate results for register writeback |

---

## Multicycle FSM

Each core uses a multicycle finite-state machine to execute instructions across multiple states instead of completing each instruction in a single cycle.

```text
FETCH_ADDR
    |
    v
FETCH_LATCH
    |
    v
DECODE
    |
    v
EXECUTE
    |
    v
MEMORY
    |
    v
WRITEBACK
    |
    v
FETCH_ADDR
```

### State Descriptions

| State | Purpose |
|---|---|
| `FETCH_ADDR` | Sends the current PC to instruction memory |
| `FETCH_LATCH` | Latches the fetched instruction |
| `DECODE` | Decodes instruction fields and generates immediates/control signals |
| `EXECUTE` | Performs ALU operations, branch comparisons, and address calculations |
| `MEMORY` | Performs load/store memory access when needed |
| `WRITEBACK` | Writes the selected result back to the register file |

This multicycle structure makes the control flow explicit and easier to debug on FPGA.

---

## Dual-Core Extension

The advanced version of the processor instantiates two processor cores.

Each core has:

- independent program counter
- independent instruction memory
- independent instruction register
- independent register file
- independent decode/control logic
- independent ALU
- independent multicycle FSM
- independent memory request signals

The cores share:

- data memory
- memory arbitration logic
- FPGA debug/output infrastructure

This allows two TinyRV programs to execute concurrently while coordinating access to shared state.

---

## Shared Data Memory

Both cores access one shared data memory. This allows the two programs to communicate through shared variables.

Shared memory is used for:

- shared counters
- synchronization flags
- turn variables for Peterson's algorithm
- done/status flags
- memory-based debug/test values

Because both cores can request memory, arbitration is required to prevent conflicting accesses.

---

## Memory Arbitration

The shared-memory arbiter controls which core can access data memory.

### Basic Behavior

- If only Core 0 requests memory, Core 0 receives the grant.
- If only Core 1 requests memory, Core 1 receives the grant.
- If both cores request memory at the same time, the arbiter grants one core and stalls the other.
- The losing core remains in its memory state until it receives a grant.

```text
Core 0 Request ----+
                  |
                  v
             +---------+
             | Arbiter |
             +---------+
                  ^
                  |
Core 1 Request ----+

Outputs:
- Core 0 Grant
- Core 1 Grant
- Core 0 Stall
- Core 1 Stall
```

The arbiter is what allows both cores to safely share one data memory without both writing or reading through the memory interface at the same time.

---

## Parallel Program Tests

The dual-core design includes test programs that demonstrate concurrent execution and shared-memory behavior.

### Test 1: Unlocked Race Condition

In the unlocked version, both cores increment a shared counter without synchronization.

This demonstrates a classic race condition:

```text
Core 0 reads counter
Core 1 reads counter
Core 0 increments local copy
Core 1 increments local copy
Core 0 writes counter
Core 1 writes counter
```

Because both cores can read the same old value before either writes back, one update can be lost.

This test is useful because it shows that the design is actually executing concurrent programs that interact through shared memory.

### Test 2: Peterson-Lock Synchronization

The synchronized version uses Peterson's mutual exclusion algorithm to protect the shared counter update.

The shared variables include:

| Variable | Purpose |
|---|---|
| `flag0` | Indicates Core 0 wants to enter the critical section |
| `flag1` | Indicates Core 1 wants to enter the critical section |
| `turn` | Gives priority to one core when both want access |
| `counter` | Shared counter updated by both cores |
| `done0` | Indicates Core 0 has completed |
| `done1` | Indicates Core 1 has completed |
| `start` | Optional start/control variable |

The expected behavior is that both cores increment the shared counter without losing updates.

If each core increments the counter 10 times, the expected final counter value is:

```text
10 increments from Core 0 + 10 increments from Core 1 = 20 total
```

---

## Supported Instruction Types

The processor supports a meaningful TinyRV / RISC-V-style instruction subset.

| Category | Instructions |
|---|---|
| Arithmetic | `add`, `sub`, `addi`, `mul` |
| Logic | `and`, `or`, `xor`, `andi`, `ori`, `xori` |
| Shifts | `sll`, `srl`, `sra`, `slli`, `srli`, `srai` |
| Comparisons | `slt`, `sltu`, `slti`, `sltiu` |
| Memory | `lw`, `sw` |
| Branches | `beq`, `bne`, `blt`, `bge`, `bltu`, `bgeu` |
| Jumps | `jal`, `jalr` |
| Upper Immediate | `lui`, `auipc` |

The exact supported instruction set depends on the current version of the control and decode logic.

---

## FPGA Debug Features

The project includes several debug modes to make processor behavior visible on the FPGA board.

Debug features include:

- selected-core display
- per-core PC display
- per-core instruction display
- register inspection
- shared-memory test mode
- memory request LEDs
- memory grant LEDs
- simultaneous-request indicator
- selected program mode indicator
- seven-segment display output

These features make it easier to verify that both cores are executing and that arbitration is behaving correctly.

---

## Debug Modes

The design exposes internal processor state through board switches, LEDs, and seven-segment displays.

Example debug capabilities:

| Debug Feature | Purpose |
|---|---|
| Core selection | Choose whether to inspect Core 0 or Core 1 |
| Register selection | Select which register value to display |
| PC display | Show the current program counter |
| Instruction display | Show the current instruction |
| Request LEDs | Show whether each core is requesting data memory |
| Grant LEDs | Show which core currently has memory access |
| Simultaneous-request LED | Indicates both cores requested memory at once |
| Memory tester mode | Pauses core execution and allows shared data memory validation |

---

## Module Guide

The project is organized around modular Verilog components.

| Module | Description |
|---|---|
| `tinyrv_parallel.v` | Top-level dual-core processor system |
| `core.v` | Parameterized TinyRV processor core |
| `alu.v` | Arithmetic logic unit |
| `control.v` | Instruction control signal generation |
| `decode.v` | Instruction field and immediate decoding |
| `regfile.v` | 32-register file |
| `pc.v` | Program counter logic |
| `imemory.v` | Instruction memory |
| `dmemory.v` | Shared data memory |
| `seven_segment.v` | Seven-segment display driver |
| `memory_tester.v` | Shared-memory debug/test mode |
| `alu_testbench.v` | ALU simulation testbench |

File names may differ depending on the current repository organization.


---

## How to Build

This project is intended for FPGA synthesis using Intel Quartus.

### Requirements

- Intel Quartus Prime
- Cyclone V FPGA board or compatible target
- Verilog simulator for testbenches
- TinyRV memory initialization files

### FPGA Build Steps

1. Open the Quartus project.
2. Confirm that all Verilog source files are included.
3. Confirm that instruction-memory `.mif` files are included.
4. Select the correct FPGA device.
5. Compile the design.
6. Program the FPGA.
7. Use board switches to select program/debug mode.
8. Use LEDs and seven-segment displays to inspect execution.

---

---

## Verification Strategy

The current project uses program-based validation and FPGA debug visibility.

Validation includes:

- ALU operation testing
- instruction execution tests
- memory load/store tests
- branch and jump tests
- register-file behavior tests
- shared-memory access tests
- unlocked race-condition test
- Peterson-lock mutual exclusion test
- board-level memory tester mode 

--- 

## Known Limitations

- The processor is multicycle, not pipelined.
- The dual-core system uses simple shared-memory arbitration, not cache coherence.
- There is no operating system support.
- There are no interrupts or exceptions.
- There is no full memory hierarchy.
- The current design should not be described as a commercial-grade RISC-V implementation.
- Timing optimization is still in progress.
- Processor-level verification is currently program/debug based rather than fully automated.

---

## What I Learned

Through this project, I gained experience with:

- RTL design in Verilog
- processor datapath design
- multicycle control FSMs
- instruction decoding
- register-file implementation
- ALU design
- branch and jump control
- load/store memory behavior
- shared-memory multiprocessing
- arbitration logic
- processor stalling
- race conditions
- mutual exclusion
- Peterson's synchronization algorithm
- FPGA synthesis and bring-up
- board-level hardware debugging
- hardware/software interaction at the ISA level

## Author

**Leah Parparov**  
Computer Engineering Student  
Miami University

GitHub: [github.com/lparp06](https://github.com/lparp06)
