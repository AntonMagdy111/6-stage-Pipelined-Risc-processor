# 6-Stage Pipelined Von Neumann Processor

Phase-2 deliverable for the Computer Architecture project. Six-stage
pipeline (IF → ID → EX1 → EX2 → MEM → WB) with full hazard handling,
plus a 2-bit dynamic branch predictor with BTB (bonus).

## Quick start

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
# For tests that read IN.PORT, pass the value:
python3 isa_sim.py test/test_io.mem 0x1234
```

### 3. Run the VHDL in ModelSim

Copy the program you want to run to `sim/program.mem`:

```sh
cp test/test_arithmetic.mem sim/program.mem
```

Open ModelSim, change to `sim/`, then:

```
vsim -do run.do
```

The do-file compiles all sources, elaborates the top, and sets up a
clean wave window with PC, SP, CCR, R0..R7, IN.PORT, OUT.PORT.

## Layout

```
processor/
├── components/                    -- leaf entities
│   ├── cpu_pkg.vhd
│   ├── alu.vhd
│   ├── RegisterFile.vhd
│   ├── Memory.vhd
│   ├── controlUnit.vhd
│   ├── pc.vhd
│   ├── sp.vhd
│   ├── CCR.vhd
│   ├── forwardingUnit.vhd
│   ├── hazardDetectionUnit.vhd
│   ├── outPutReg.vhd
│   ├── branchPredictor.vhd        -- BONUS
│   └── Pipelined_Registers/
│       ├── IF_ID.vhd
│       ├── ID_EX1.vhd
│       ├── EX1_EX2.vhd
│       ├── EX2_MEM.vhd
│       └── MEM_WB.vhd
├── stages/                        -- per-stage glue
│   ├── fetchStage.vhd
│   ├── decodeStage.vhd
│   ├── execute1Stage.vhd
│   ├── execute2Stage.vhd
│   ├── memoryStage.vhd
│   └── writeBackStage.vhd
├── Processor.vhd                  -- top
├── tb_Processor.vhd               -- testbench
├── sim/run.do                     -- ModelSim script
├── assembler/assembler.cpp        -- C++17 two-pass assembler
├── isa_sim.py                     -- Python golden model
├── test/                          -- five test programs
└── docs/
    ├── REPORT.md                  -- full Phase-2 write-up
    └── SCHEMATIC.svg              -- datapath diagram
```

## Test programs

| File | Covers |
|---|---|
| `test_arithmetic.asm` | NOP, SETC, NOT, INC, MOV, SWAP, ADD, SUB, AND, IADD, LDM |
| `test_memory.asm` | LDM, LDD, STD, PUSH, POP |
| `test_branches.asm` | JZ, JN, JC, JMP, CALL, RET |
| `test_io.asm` | IN, OUT, SETC, NOP, HLT |
| `test_interrupts.asm` | INT, RTI |

All five pass under the Python golden model, covering all 26
instructions in the ISA.

See `docs/REPORT.md` for the full architectural write-up, hazard
handling explanation, and bonus details.
