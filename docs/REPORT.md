# 6-Stage Pipelined Von Neumann RISC Processor — Architecture & Timing Report

## 1. Architectural Overview

This processor implements a 32-bit, 6-stage pipelined Von Neumann RISC architecture in VHDL-2008 with a custom 26-instruction ISA, unified 4096 × 32-bit memory, full strictly age-ordered data forwarding, 1-cycle load/pop/in-use hazard stalling, early zero-bubble unconditional jump/call steering, a 16-entry 2-bit saturating Branch Target Buffer (BTB), and full software/hardware interrupt handling with automatic flag preservation.

### Pipeline Stages (`IF -> ID -> EX1 -> EX2 -> MEM -> WB`)

| Stage | Primary Responsibilities | Key Entities |
|---|---|---|
| **IF** | Fetch 1-word or 2-word (opcode + 32-bit immediate) instructions; early zero-bubble target steering for `JMP`/`CALL`; 2-bit BTB lookup for conditional branches; clean fetch pause on `INTR`. | `fetchStage.vhd`, `pc.vhd`, `branchPredictor.vhd` |
| **ID** | Decode 16-bit IR; generate control bundle including explicit `uses_rs1`/`uses_rs2`; dual-port register-file read with `SWAP` port remapping and same-cycle WB write-through bypass; 1-cycle load/pop/in-use stall detection. | `decodeStage.vhd`, `controlUnit.vhd`, `RegisterFile.vhd`, `hazardDetectionUnit.vhd` |
| **EX1** | Strictly age-ordered 3-bit data forwarding (`EX1/EX2 > EX2/MEM > MEM/WB > RF`) for operands `A`, `B`, and `Store`; 32-bit ALU execution (`ADD`, `SUB`, `AND`, `NOT`, `INC`, `PASS`, `PASS_A`) and flag generation (`Z`, `N`, `C`). | `execute1Stage.vhd`, `forwardingUnit.vhd`, `alu.vhd` |
| **EX2** | Conditional branch direction & target verification against BTB; BTB update (conditional branches only); stack address computation (`SP` for push/call/int, `SP+1` for pop/ret/rti) & `SP` update; pass-through of `STD`/`SWAP`/`OUT` store data; `CCR` update + 4-deep shadow stack save/restore; architectural `HLT` commit. | `execute2Stage.vhd`, `sp.vhd`, `CCR.vhd` |
| **MEM** | Unified data memory read/write (`LDD`, `STD`, `PUSH`, `POP`, `CALL`, `RET`, `INT`, `RTI`); `IN.PORT` capture; `OUT.PORT` register latching; `SWAP` secondary writeback routing; `RET`/`RTI`/`INT`/`INTR` redirect (gating wrong-path `EX2` side effects). | `memoryStage.vhd`, `Memory.vhd`, `outPutReg.vhd` |
| **WB** | Dual-port synchronous register-file commit (Port 1: primary writeback; Port 2: `SWAP` secondary writeback). | `writeBackStage.vhd`, `RegisterFile.vhd` |

---

## 2. Clocking, Reset Hygiene, and Timing Analysis

### 2.1 Pure Single-Edge Synchronous Clocking
Every sequential element in the processor (`pc`, `fetchStage` FSM, all 5 pipeline registers, `RegisterFile`, `Memory`, `sp`, `CCR`, `outPutReg`, `branchPredictor`, `halt_latch`, `hw_int` control) triggers exclusively on `rising_edge(clk)`.

- **Eliminates half-cycle paths:** Previously, `RegisterFile` and `Memory` wrote on `falling_edge(clk)`, cutting setup margins in half ($T_{\text{clk}}/2$) on both `MEM/WB -> RF -> ID/EX1` and `EX2/MEM -> Memory -> MEM/WB` and making timing sensitive to clock duty-cycle distortion.
- **Zero-penalty single-edge hazards:**
  - **WB -> ID register dependency:** Resolved within the same clock cycle by combinational write-through bypass on both write ports of `RegisterFile` (Port 1 prioritized over Port 2 identically in both storage and bypass).
  - **MEM Store -> MEM Load (`PUSH -> POP`, `STD -> LDD`, `CALL -> RET`):** Because `Memory` writes on `rising_edge(clk)` at the same clock edge that advances the following load into `EX2/MEM`, the newly written word is immediately visible to the combinational data-read port in the very next cycle.

### 2.2 Synthesizable Reset Strategy
- `pc.vhd` and `fetchStage.vhd` use **synchronous reset** (`if rising_edge(clk) then if rst = '1' then pc_r <= unsigned(reset_vec);`) so loading the non-constant memory vector `M[0]` synthesizes into standard D-flip-flop mux logic rather than asynchronous set/clear latches (`LDC`).
- All constant-reset registers (`IF_ID`, `ID_EX1`, `EX1_EX2`, `EX2_MEM`, `MEM_WB`, `RegisterFile`, `sp`, `CCR`, `outPutReg`, `branchPredictor`) reset cleanly to constants, and `Memory` guards writes with `rst = '0'`.

### 2.3 Per-Stage Critical Path Breakdown

| Stage | Dominant Combinational Path | Notes / Optimization Opportunity for High-$f_{\max}$ FPGA |
|---|---|---|
| **IF** | `pc_r -> Memory(i_addr -> i_data) -> pre-decode / pc_sel mux -> pc_r` | Combinational ROM/RAM read + next-PC mux. For GHz/BRAM targets, register `i_data` (1-cycle fetch latency) with a skid buffer. |
| **ID** | `IF/ID -> controlUnit -> hazardDetectionUnit -> stall -> IF/ID.en & ID/EX1.flush` and `IF/ID -> RF read/bypass -> ID/EX1` | Shallow logic; gating with `ifid_valid` & `uses_rs1/rs2` keeps hazard logic compact (~4 LUT levels). |
| **EX1** | `EX2/MEM -> Memory(d_addr -> d_out) -> memoryStage(wb_data) -> execute1Stage(7:1 fwd mux) -> 32-bit ALU -> z_flag -> EX1/EX2` | **Primary critical path** because `MEM -> EX1` forwarding traverses combinational data RAM read + 32-bit ripple carry. Trade-off: yields 1-cycle load-use latency (and 0-cycle penalty after 2-word instructions). For maximum $f_{\max}$ on synchronous BRAM, omit `d_out` from `EX2/MEM -> EX1` bypass (returning to 2-cycle load-use with registered BRAM output). |
| **EX2** | `EX1/EX2 -> branch/target comparator -> mispredict -> flush_front -> IF/ID/EX1/PC` | 32-bit target comparator + fanout of `flush_front`. |
| **MEM** | `EX2/MEM -> Memory(d_out / vec_data) -> ret_target -> redirect_pc -> pc_r` | Only active on `RET`/`RTI`/`INT`. |
| **WB** | `MEM/WB -> writeBackStage -> RegisterFile` | Very short path (1 AND gate + RF address decode). |

---

## 3. Hazard Detection & Strictly Age-Ordered Forwarding

### 3.1 Explicit Source-Register Usage (`uses_rs1`, `uses_rs2`)
Unused register fields in the 16-bit instruction format are zero-filled (`"000"` = `R0`). Gating hazard checks with `ifid_valid`, `uses_rs1` (port 1 / `src_a`), and `uses_rs2` (port 2 / `src_b` & `store`) eliminates all spurious stalls on `R0` and pipeline bubbles while accurately catching `STD` store-data (`rs2`) and `SWAP` (`Rdst`) load-use hazards:

- **`uses_rs1 = '1'`:** `SWAP` (`rs2` mapped to port 1), `ADD`, `SUB`, `AND`, `IADD`, `LDD`, `STD`
- **`uses_rs2 = '1'`:** `NOT`, `INC`, `MOV`, `SWAP` (`rdst` mapped to port 2), `ADD`, `SUB`, `AND`, `OUT`, `PUSH`, `STD`
- **Stall condition (1 cycle max):** Fires iff `ifid_valid = '1'` AND `id_ex1_valid = '1'` AND (`LDD`/`POP`/`IN` in `ID/EX1`) AND (`(uses_rs1 and rd = src_a)` OR `(uses_rs2 and rd = src_b)`).

### 3.2 Unified 3-Bit Forwarding Priority
A single 3-bit age-ordered selector (`sel_a`, `sel_b`, `sel_store`) prevents stale `SWAP` secondary writes in `MEM`/`WB` from overriding newer instructions in `EX1/EX2` or `EX2/MEM`:

| Code | Priority (Age) | Source |
|---|---|---|
| `"001"` | 1 (youngest) | `EX1/EX2` primary (`ex12_imm` for `LDM`, else `ex12_alu_res`) |
| `"010"` | 1 | `EX1/EX2` `SWAP` secondary (`ex12_store`) |
| `"011"` | 2 | `EX2/MEM` primary (`mem_wb_data`: ALU / IMM / MEM / IN) |
| `"100"` | 2 | `EX2/MEM` `SWAP` secondary (`mem_swap_data`) |
| `"101"` | 3 (oldest) | `MEM/WB` primary (`mw_data`) |
| `"110"` | 3 | `MEM/WB` `SWAP` secondary (`mw_swap_data`) |
| `"000"` | — | Register file value latched in `ID/EX1` (always used for `B` when `use_imm = '1'`) |

---

## 4. Control Flow, Branch Prediction, `HLT`, and Interrupts

1. **Zero-Bubble Unconditional `JMP` & `CALL`:** When `fetchStage` finishes fetching the 2nd word (`imm_pending = '1'`) of `JMP` or `CALL`, it immediately steers `PC <= i_data` and marks `pred_taken = '1', pred_target = i_data`. Cold `JMP`/`CALL` instructions incur **0 flush bubbles** and consume **0 BTB entries**.
2. **16-Entry 2-Bit BTB:** Dedicated exclusively to conditional branches (`JZ`, `JN`, `JC`). `EX2` verifies both direction (`taken xor pred_taken_in`) and target address (`pred_target_in /= target`). Taken `JZ`/`JN`/`JC` clear their tested flag (`Z`/`N`/`C`) per ISA semantics.
3. **Wrong-Path Isolation on `RET`/`RTI`/`INT`:** When `mem_ret_redirect = '1'`, `Processor.vhd` flushes `IF_ID`, `ID_EX1`, `EX1_EX2`, `EX2_MEM`, and `MEM_WB`, and gates `EX2`'s `SP`, `CCR` (`upd_zn`, `upd_c`, `set_c`, `save_ccr`, `restore_ccr`), `bp_upd_en`, `ex2_misp`, and `ex2_halt` so instructions immediately following `RET`/`RTI`/`INT` cannot corrupt architectural state.
4. **Architectural `HLT`:** Commits only in `EX2` when `mem_ret_redirect = '0'`, flushes younger instructions, sets `halt_latch <= '1'`, and freezes `PC` at `addr(HLT) + 1` (without polluting the BTB).
5. **Hardware (`INTR`) & Software (`INT 0/1`) Interrupts:**
   - Rising-edge latched into `hw_int_pending`; `pause_fetch` finishes any in-progress 2-word fetch and pauses new fetches until the pipeline drains completely (`pipe_empty = '1'`).
   - Synthetic `CTRL_HW_INT` injects cleanly into `ID/EX1`, pushes exact `PC` onto `M[SP]`, decrements `SP`, and redirects to `M[1]` (`M[2+idx]` for software `INT idx`).
   - `CCR.vhd` automatically pushes/pops flags on a 4-deep hardware shadow stack on `INT`/`INTR` and `RTI` (preserving `SP` stack depth and supporting nested interrupts).

---

## 5. Verification Summary

- **Compiler Check (`vcom -2008`):** 26/26 VHDL files compile with **0 errors, 0 warnings**.
- **Custom Test Suite (`sim/run_all_100_tests.do`):** **100 / 100 PASS** (plus explicit `OUT.PORT` checks on `076`, `080`, `18_io_sequence`).
- **Core & Professor Suite (13 programs):** **13 / 13 PASS** — verified bit-for-bit against `isa_sim.py` on `R0..R7`, `SP`, `PC`, `CCR`, `OUT.PORT`, and full `OUT` history.
- **Adversarial Edge-Case Regression Suite (15 programs):** **15 / 15 PASS** — covering single-edge `STD->LDD`/`PUSH->POP`/`WB->ID`, `OUT` from all producer types, zero spurious `R0` stalls, `LDD/POP/IN -> STD/SWAP`, `SWAP` overwrite priority, zero-bubble cold `JMP`/`CALL`, `HLT` PC preservation & wrong-path `HLT`/`CCR` after `RET`, nested `INT 0 -> INT 1 -> RTI -> RTI` CCR stack restoration, and live multi-cycle + single-cycle hardware `intr` mid-loop.
