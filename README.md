# 6-Stage Pipelined Von Neumann RISC Processor

Six-stage pipelined 32-bit Von Neumann RISC processor (`IF -> ID -> EX1 -> EX2 -> MEM -> WB`) written in VHDL-2008 with a custom 26-instruction ISA, pure single-edge rising-clock timing, full age-ordered data forwarding, 1-cycle load/pop/in-use hazard stalling, zero-bubble `JMP`/`CALL` steering, a 16-entry 2-bit BTB conditional branch predictor, and hardware/software interrupts with automatic `CCR` shadow-stack save/restore.

## Key Architectural Features
- **Pure single-edge synchronous design (`rising_edge(clk)`):** Eliminates half-cycle falling-edge timing paths in `RegisterFile` (with dual-port WB write-through bypass) and `Memory`, plus synthesizable synchronous reset in `pc.vhd` / `fetchStage.vhd`.
- **1-cycle load/pop/in-use stalls with zero spurious stalls:** `controlUnit` emits explicit `uses_rs1` / `uses_rs2` flags and `hazardDetectionUnit` gates on `ifid_valid`, eliminating false `R0` stalls on bubbles and non-reading instructions while properly catching `STD` store-data and `SWAP` `Rdst` hazards.
- **Strictly age-ordered 3-bit forwarding:** Unified forwarding selector (`EX1/EX2 > EX2/MEM > MEM/WB > RF`) covering ALU, `LDM`, `LDD`, `POP`, `IN`, and both `SWAP` writeback ports.
- **Zero-bubble `JMP`/`CALL` + 16-entry 2-bit BTB:** Unconditional `JMP`/`CALL` steer `PC` immediately in `IF` on word 2 (0 flush bubbles), reserving all 16 BTB entries for conditional branches (`JZ`, `JN`, `JC`) with both direction and target verification in `EX2`.
- **Full `OUT.PORT`, `HLT`, and `INT`/`INTR`/`RTI` support:** `OUT` passes forwarded data cleanly through `EX2 -> MEM -> outPutReg`; `HLT` commits in `EX2` and freezes `PC` at `HLT + 1`; hardware `INTR` cleanly drains the pipeline, saves `CCR` on a 4-deep shadow stack, pushes exact return `PC`, and jumps to `M[1]`.

## Quick Start

### 1. Assemble a test program

```sh
cd assembler
g++ -std=c++17 -O2 -Wall assembler.cpp -o assembler
cd ..
./assembler/assembler test/test_arithmetic.asm test/test_arithmetic.mem
```

### 2. Validate against the Python golden model

```sh
python3 isa_sim.py test/test_arithmetic.mem
# For tests that read IN.PORT, pass the input sequence:
python3 isa_sim.py test/test_io.mem 0x1234
```

### 3. Run the VHDL in ModelSim

Copy the test program to `sim/program.mem`, open ModelSim in `sim/`, and run:

```tcl
do run.do
```

To execute the full 100-test custom regression suite in ModelSim:

```tcl
do run_all_100_tests.do
```

`tb_Processor.vhd` and `sim/tb_Processor_100.vhd` also support optional self-checks for `OUT.PORT`, `PC`, and `CCR` via generics (`-gCHECK_OUT=true -gEXP_OUT=16#...`, `-gCHECK_PC=true`, `-gCHECK_CCR=true`).

## Repository Layout

```
6-stage-Pipelined-Risc-processor/
├── components/                    -- leaf hardware entities
│   ├── cpu_pkg.vhd                -- ISA opcodes, ctrl_bundle, safe_int
│   ├── alu.vhd                    -- 32-bit ALU + Z/N/C flags
│   ├── RegisterFile.vhd           -- 8x32 dual-write rising-edge RF + bypass
│   ├── Memory.vhd                 -- 4096x32 unified memory (rising-edge write)
│   ├── controlUnit.vhd            -- combinational decoder (with uses_rs1/rs2)
│   ├── pc.vhd                     -- synchronous-reset Program Counter
│   ├── sp.vhd                     -- Stack Pointer (resets to 4095)
│   ├── CCR.vhd                    -- Z/N/C flags + 4-deep interrupt shadow stack
│   ├── forwardingUnit.vhd         -- unified 3-bit age-ordered forwarding unit
│   ├── hazardDetectionUnit.vhd    -- 1-cycle load/pop/in-use hazard detector
│   ├── outPutReg.vhd              -- OUT.PORT output latch
│   ├── branchPredictor.vhd        -- 16-entry 2-bit saturating BTB
│   └── Pipelined_Registers/       -- IF_ID, ID_EX1, EX1_EX2, EX2_MEM, MEM_WB
├── stages/                        -- 6 pipeline stages (IF, ID, EX1, EX2, MEM, WB)
├── Processor.vhd                  -- top-level CPU
├── tb_Processor.vhd               -- self-checking testbench (R0-R7, SP, OUT, PC, CCR)
├── sim/                           -- ModelSim scripts (run.do, run_all_100_tests.do, ...)
├── assembler/assembler.cpp        -- C++17 two-pass assembler
├── isa_sim.py                     -- Python golden ISA simulator
├── test/                          -- core tests, professor tests, and 100 custom tests
└── docs/
    └── REPORT.md                  -- full architectural & timing write-up
```

## Test Coverage

| Suite | Count | Coverage |
|---|---|---|
| Core tests (`test_*.asm`) | 7 | Arithmetic, memory, branches, I/O (`IN`/`OUT`), `INT`/`RTI`, RAW hazards, edge cases |
| Professor tests (`prof_*.asm`) | 6 | Full grading suite (`OneOperand`, `TwoOperand`, `Memory`, `Branch`, `Test1`, `Test2`) |
| Custom suite (`test/custom_tests_100/`) | 100 | Exhaustive per-instruction, forwarding, branch-predictor, stack, I/O, and `HLT` coverage |

See [docs/REPORT.md](docs/REPORT.md) for the complete microarchitectural analysis, timing breakdown, and verification summary.
