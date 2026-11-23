#!/usr/bin/env python3
# ==========================================================================
# Project : 6-Stage Pipelined 32-Bit Von Neumann RISC Processor
# Author  : Anton Magdy (@AntonMagdy111) - https://github.com/AntonMagdy111
# Repo    : https://github.com/AntonMagdy111/6-stage-Pipelined-Risc-processor
# License : Apache-2.0 (see LICENSE and NOTICE for mandatory attribution)
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 Anton Magdy. All rights reserved.
# ==========================================================================
"""
verification/corner_case_suite.py
Adversarial Microarchitectural & Tooling Corner-Case Verification Suite.

Validates 16 extreme corner-case scenarios (Von Neumann self-modifying BTB
hazards, branch target patching, zero-NOP dynamic interrupt vectors, 0-body
CALL->RET, 6-deep nested INT/RTI CCR stack, 0-stall WB->MEM bypass chains,
self-SWAP & SWAP forwarding chains, SP wrap-around, 32-bit ALU boundary flags,
self-looping JZ, wrong-path minefields, negative hex immediates/offsets,
8-value back-to-back IN bursts, BTB tag-aliasing thrash, multi-edge hardware
INTR bursts on exact dispatch cycles, and INTR vs in-flight HLT) plus 8
negative assembler syntax/bounds rejection tests.
"""
import os
import shutil
import subprocess
import sys
import tempfile

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_DIR   = os.path.abspath(os.path.join(SCRIPT_DIR, ".."))
SIM_DIR    = os.path.join(REPO_DIR, "sim")
sys.path.insert(0, REPO_DIR)
import isa_sim


def find_gpp():
    candidates = [
        shutil.which("g++"),
        r"D:\questa_fse\gcc-7.4.0-mingw64vc16\bin\g++.exe",
    ]
    for c in candidates:
        if c and os.path.isfile(c):
            return c
    raise RuntimeError("g++ compiler not found")


CORNER_TESTS = [
    # 1. Von Neumann self-modifying code overwriting trained BTB entries with 1-word ADD & 2-word LDM
    (
        "cc01_von_neumann_btb_overwrite_1w_2w",
        [],
        r"""
        .org 0x10
            LDM  R0, #0
            LDM  R1, #10
            LDM  R2, #20
            LDM  R3, #3          ; 3 training iterations -> BTB strongly taken ("11")
        TRAIN_LOOP:
            SUB  R6, R0, R0      ; Z = 1
            JMP  0x40
        AFTER_BR1:
            SETC                 ; C = 1
            JMP  0x50
        AFTER_BR2:
            IADD R3, R3, #-1
            JZ   PATCH_PHASE
            JMP  TRAIN_LOOP

        PATCH_PHASE:
            ; Encode ADD R4, R1, R2: op=00111(7), rdst=4, rs1=1, rs2=2 -> (7<<11)|(4<<8)|(1<<5)|(2<<2) = 0x3C28
            LDM  R6, #0x00003C28
            STD  R6, 0x40(R0)    ; Overwrite trained JZ at 0x40 with 1-word ADD R4, R1, R2!
            ; Encode LDM R5, #0xCAFE1234: op=10000(16), rdst=5 -> (16<<11)|(5<<8) = 0x8500
            LDM  R6, #0x00008500
            STD  R6, 0x50(R0)    ; Overwrite trained JC at 0x50 with 2-word LDM R5, #imm!
            LDM  R6, #0xCAFE1234
            STD  R6, 0x51(R0)
            JMP  0x40            ; Must NOT jump via stale BTB on ADD or LDM!

        TRAP_OLD_TARGET:
            LDM  R7, #0xDEADDEAD
            OUT  R7
            HLT

        .org 0x40
            JZ   AFTER_BR1       ; During training: jumps to AFTER_BR1; later patched to ADD R4,R1,R2
            JMP  0x50            ; Reached only after 0x40 is patched to 1-word ADD!

        .org 0x50
            JC   AFTER_BR2       ; During training: jumps to AFTER_BR2; later patched to LDM R5,#0xCAFE1234
            OUT  R4              ; Expect 30 (0x1E)
            OUT  R5              ; Expect 0xCAFE1234
            HLT
        """,
    ),

    # 2. Von Neumann self-modifying patch of a trained conditional branch's target immediate
    (
        "cc02_von_neumann_branch_target_patch",
        [],
        r"""
        .org 0x10
            LDM  R0, #0
            LDM  R3, #3
        TRAIN_T1:
            SUB  R1, R0, R0      ; Z = 1
            JMP  0x60
        T_OLD:
            IADD R3, R3, #-1
            JZ   DO_PATCH
            JMP  TRAIN_T1

        DO_PATCH:
            ; Replace T_OLD jump body with a trap to prove EX2 flushes wrong-target prediction!
            LDM  R6, #0x00000800 ; HLT opcode (0b00001 << 11 = 0x0800) if T_OLD wasn't flushed!
            STD  R6, T_OLD(R0)
            ; Patch immediate word of JZ at 0x61 from T_OLD -> T_NEW
            LDM  R6, #T_NEW
            STD  R6, 0x61(R0)
            LDM  R4, #2
        RUN_NEW:
            SUB  R1, R0, R0      ; Z = 1
            JMP  0x60
        T_NEW:
            IADD R2, R2, #0x111
            IADD R4, R4, #-1
            JZ   DONE_2
            JMP  RUN_NEW
        DONE_2:
            OUT  R2              ; Expect 0x222
            HLT

        .org 0x60
            JZ   T_OLD
            HLT
        """,
    ),

    # 3. Zero-NOP dynamic software interrupt vector table installation (STD M[2]/M[3] -> immediate INT 0/1)
    (
        "cc03_dynamic_int_vectors_zero_nop",
        [],
        r"""
        .org 0x10
            LDM  R0, #0
            LDM  R1, #ISR0
            LDM  R2, #ISR1
            STD  R1, 2(R0)       ; Write M[2] in MEM on cycle N
            INT  0               ; Read vec_data = M[2] in MEM on cycle N+1 (0 NOPs!)
            STD  R2, 3(R0)       ; Write M[3] in MEM on cycle M
            INT  1               ; Read vec_data = M[3] in MEM on cycle M+1 (0 NOPs!)
            OUT  R5
            HLT

        ISR0:
            LDM  R5, #0x12340000
            RTI
        ISR1:
            IADD R5, R5, #0x5678
            RTI
        """,
    ),

    # 4. Zero-instruction subroutine (CALL -> immediate RET) + 8-deep recursive CALL/RET
    (
        "cc04_zero_body_call_ret_and_deep_recursion",
        [],
        r"""
        .org 0x10
            LDM  R1, #0x100
            CALL EMPTY_SUB       ; CALL pushes return PC on exact edge RET pops it!
            IADD R1, R1, #1
            CALL EMPTY_SUB
            LDM  R2, #8          ; 8-deep nested CALL
            CALL DEEP_REC
            OUT  R1              ; 0x101 + 8*0x10 = 0x181
            HLT

        EMPTY_SUB:
            RET

        DEEP_REC:
            IADD R1, R1, #0x10
            IADD R2, R2, #-1
            JZ   REC_BASE
            CALL DEEP_REC
        REC_BASE:
            RET
        """,
    ),

    # 5. 6-deep nested software interrupts verifying 8-deep CCR shadow stack restoration
    (
        "cc05_nested_int_6deep_ccr_preservation",
        [],
        r"""
        .org 2
            .word ISR_NEST
            .word ISR_LEAF

        .org 0x10
            LDM  R0, #5          ; Nesting counter: 5 INT 0s + 1 INT 1 = 6 nested INTs!
            LDM  R7, #0
            SETC                 ; Root flags: C=1, N=0, Z=0
            INT  0
            ; Upon returning from all 6 nested ISRs, C must STILL be 1 and Z=0, N=0!
            JC   ROOT_C_OK
            LDM  R7, #0xBAD1
            HLT
        ROOT_C_OK:
            JZ   BAD_ROOT
            JN   BAD_ROOT
            IADD R7, R7, #0x1000
            OUT  R7
            HLT
        BAD_ROOT:
            LDM  R7, #0xBAD2
            HLT

        ISR_NEST:
            ; Clobber flags differently at each depth, then recurse via INT
            IADD R7, R7, #1
            IADD R0, R0, #-1
            JZ   GO_LEAF         ; When R0 hits 0, Z=1! Save Z=1 across INT 1 -> RTI!
            ; Here Z=0; force N=1 before nested INT 0
            LDM  R3, #-5
            ADD  R3, R3, R0      ; N=1, Z=0, C=0
            INT  0               ; Must preserve N=1!
            JN   NEST_N_OK
            LDM  R7, #0xBAD3
            HLT
        NEST_N_OK:
            RTI

        GO_LEAF:
            ; Currently Z=1! Trigger 6th nested interrupt (INT 1), which clobbers Z=0, N=1, C=1
            INT  1
            JZ   LEAF_RET_Z_OK   ; Z=1 must have been restored by RTI from ISR_LEAF!
            LDM  R7, #0xBAD4
            HLT
        LEAF_RET_Z_OK:
            IADD R7, R7, #0x200
            RTI

        ISR_LEAF:
            LDM  R4, #0xFFFFFFFF
            IADD R4, R4, #2      ; Sets C=1, Z=0, N=0 (clobbers caller's Z=1!)
            LDM  R4, #-1
            AND  R4, R4, R4      ; Sets N=1, Z=0, C=1
            IADD R7, R7, #0x10
            RTI
        """,
    ),

    # 6. Back-to-back 0-stall WB -> MEM store/output bypass chains
    (
        "cc06_pop_push_out_std_wb_mem_bypass_chain",
        [0xAAAA1111, 0xBBBB2222],
        r"""
        .org 0x10
            LDM  R5, #0x200
            LDM  R1, #0x13572468
            PUSH R1
            POP  R2
            PUSH R2              ; 0-stall WB -> MEM bypass (POP -> PUSH)
            POP  R3
            OUT  R3              ; 0-stall WB -> MEM bypass (POP -> OUT)
            IN   R4              ; 0xAAAA1111
            PUSH R4              ; 0-stall WB -> MEM bypass (IN -> PUSH)
            POP  R6
            STD  R6, 0(R5)       ; POP -> 2-word STD
            LDD  R0, 0(R5)
            OUT  R0              ; 0-stall WB -> MEM bypass (LDD -> OUT)
            LDD  R7, 0(R5)
            PUSH R7              ; 0-stall WB -> MEM bypass (LDD -> PUSH)
            POP  R7
            IN   R1              ; 0xBBBB2222
            OUT  R1              ; 0-stall WB -> MEM bypass (IN -> OUT)
            HLT
        """,
    ),

    # 7. Self-SWAP (SWAP Rx, Rx) and dense back-to-back primary + secondary SWAP forwarding chains
    (
        "cc07_swap_self_and_triple_swap_hazards",
        [],
        r"""
        .org 0x10
            LDM  R0, #0x100
            LDM  R1, #0x11111111
            LDM  R2, #0x22222222
            LDM  R3, #0x33333333
            STD  R1, 0(R0)
            SWAP R2, R2          ; Self-swap: Port 1 & Port 2 target R2 simultaneously
            OUT  R2              ; Must remain 0x22222222
            LDD  R1, 0(R0)       ; Load-use into SWAP!
            SWAP R2, R1          ; R2=0x11111111, R1=0x22222222 (stalls 1 cyc)
            SWAP R2, R2          ; Self-swap immediately after SWAP!
            SWAP R3, R1          ; R3=0x22222222, R1=0x33333333
            SWAP R1, R2          ; R1=0x11111111, R2=0x33333333
            ADD  R4, R1, R2      ; 0x44444444 (forwards both SWAP ports from EX1/EX2!)
            SUB  R5, R2, R3      ; 0x11111111 (forwards SWAP from EX2/MEM!)
            ADD  R6, R3, R1      ; 0x33333333 (forwards SWAP from MEM/WB!)
            OUT  R4
            OUT  R5
            OUT  R6
            HLT
        """,
    ),

    # 8. Stack Pointer wrap-around at SP = 4095 -> 4096 (d_addr wraps modulo 4096 to M[0])
    (
        "cc08_sp_wrap_around_0_and_4095",
        [],
        r"""
        .org 0x20
            ; At reset SP = 4095 (0xFFF) and M[0] = 0x20.
            ; POP increments SP to 4096 (0x1000) and reads M[4096 & 0xFFF] = M[0] = 0x20!
            POP  R1              ; R1 = 0x20, SP = 0x00001000
            OUT  R1
            PUSH R1              ; Writes M[0x1000 & 0xFFF] = M[0] = 0x20, restores SP = 0x00000FFF!
            PUSH R1              ; Normal push at M[4095], SP = 0x00000FFE
            POP  R2              ; R2 = 0x20, SP = 0x00000FFF
            OUT  R2
            HLT
        """,
    ),

    # 9. 32-bit ALU extreme overflow/borrow/sign boundaries + partial CCR flag preservation
    (
        "cc09_alu_32bit_corner_flags_and_partial_flag_preserve",
        [],
        r"""
        .org 0x10
            LDM  R0, #0
            LDM  R1, #0xFFFFFFFF
            INC  R1              ; 0xFFFFFFFF + 1 -> R1=0, Z=1, N=0, C=1
            ; NOT updates Z,N only -> must preserve C=1!
            NOT  R1              ; R1=0xFFFFFFFF, Z=0, N=1, C=1 preserved
            JC   C_KEPT_1        ; Takes branch & clears C -> 0, preserving N=1!
            HLT
        C_KEPT_1:
            JN   N_KEPT_1        ; N=1 was preserved across taken JC! Clears N -> 0
            HLT
        N_KEPT_1:
            ; Signed overflow boundary: 0x7FFFFFFF + 1 = 0x80000000 -> N=1, Z=0, C=0
            LDM  R2, #0x7FFFFFFF
            IADD R2, R2, #1
            JC   FAIL_9
            JN   SIGN_OK
            HLT
        SIGN_OK:
            ; Borrow as carry: 0 - 1 = 0xFFFFFFFF -> C=1, N=1, Z=0
            SUB  R3, R0, R2      ; 0 - 0x80000000 = 0x80000000 -> C=1, N=1, Z=0
            ; AND updates Z,N only -> must preserve C=1!
            AND  R4, R0, R3      ; R4 = 0 -> Z=1, N=0, C=1 preserved!
            JZ   Z_CLEAR_ONLY    ; Clears Z -> 0, must preserve C=1!
            HLT
        Z_CLEAR_ONLY:
            JZ   FAIL_9          ; Z was cleared by taken JZ!
            JC   ALL_FLAGS_OK    ; C=1 was preserved across AND and taken JZ!
            HLT
        ALL_FLAGS_OK:
            LDM  R7, #0x77777777
            OUT  R7
            HLT
        FAIL_9:
            LDM  R7, #0xDEAD0009
            OUT  R7
            HLT
        """,
    ),

    # 10. Branch jumping to its OWN PC (SELF: JZ SELF)
    (
        "cc10_self_branch_jz_to_own_pc",
        [],
        r"""
        .org 0x10
            LDM  R0, #0
            SUB  R0, R0, R0      ; Z = 1
        SELF_LOOP:
            JZ   SELF_LOOP       ; 1st time: Z=1 -> jumps to SELF_LOOP & clears Z=0 (allocates BTB)!
                                 ; 2nd time: BTB predicts taken to SELF_LOOP, EX2 sees Z=0 -> mispredicts & exits!
            LDM  R1, #0xABCD1234
            OUT  R1
            HLT
        """,
    ),

    # 11. Wrong-path minefield behind JMP, CALL, taken JZ, RET, RTI, and INT
    (
        "cc11_wrong_path_minefield",
        [],
        r"""
        .org 2
            .word ISR_11

        .org 0x10
            LDM  R0, #0x300
            LDM  R7, #0xBAD00000
            SUB  R1, R0, R0      ; Z = 1
            JZ   AFTER_JZ
            ; --- Wrong-path minefield #1 (behind taken JZ) ---
            HLT
            OUT  R7
            PUSH R7
            INT  0
        AFTER_JZ:
            JMP  AFTER_JMP
            ; --- Wrong-path minefield #2 (behind JMP) ---
            POP  R1
            ADD  R2, R1, R7
            HLT
            OUT  R7
        AFTER_JMP:
            CALL SUB_11
            ; --- Return point ---
            INT  0
            LDM  R6, #0x9999AAAA
            OUT  R6
            HLT

        SUB_11:
            IADD R5, R5, #0x42
            RET
            ; --- Wrong-path minefield #3 (behind RET — reaches EX2 before MEM redirect!) ---
            HLT
            SETC
            PUSH R7
            OUT  R7
            INT  0

        ISR_11:
            IADD R5, R5, #0x100
            RTI
            ; --- Wrong-path minefield #4 (behind RTI — reaches EX2 before MEM redirect!) ---
            HLT
            POP  R7
            SETC
            OUT  R7
        """,
    ),

    # 12. Negative hex immediates (#-0x10) and negative LDD/STD base offsets (-0x4(R1), -8(R1))
    (
        "cc12_negative_hex_imm_and_negative_ldd_std_offsets",
        [],
        r"""
        .org 0x10
            LDM  R1, #0x200
            LDM  R2, #0b10100101 ; Binary literal = 0xA5
            IADD R2, R2, #-0x05  ; 0xA5 - 5 = 0xA0 (previously stol("-0x05") returned 0!)
            STD  R2, -0x4(R1)    ; M[0x1FC] = 0xA0
            LDM  R3, #-1         ; 0xFFFFFFFF
            STD  R3, -8(R1)      ; M[0x1F8] = 0xFFFFFFFF
            LDD  R4, -0x4(R1)    ; R4 = 0xA0
            LDD  R5, -8(R1)      ; R5 = 0xFFFFFFFF
            IADD R6, R4, #-0x20  ; 0xA0 - 0x20 = 0x80
            OUT  R4
            OUT  R5
            OUT  R6
            HLT
        """,
    ),

    # 13. 8-value back-to-back IN.PORT burst across stall & 0-stall consumers
    (
        "cc13_back_to_back_in_port_burst_8vals",
        [0x10, 0x20, 0x30, 0x40, 0x50, 0x60, 0x70, 0x80],
        r"""
        .org 0x10
            IN   R0              ; 0x10
            IN   R1              ; 0x20 (back-to-back IN!)
            ADD  R2, R0, R1      ; 0x30 (1-cycle IN-use stall on R1)
            IN   R3              ; 0x30
            OUT  R3              ; 0-stall WB -> MEM bypass (IN -> OUT)
            IN   R4              ; 0x40
            PUSH R4              ; 0-stall WB -> MEM bypass (IN -> PUSH)
            IN   R5              ; 0x50
            SWAP R5, R2          ; 1-cycle IN-use stall on R5 -> R5=0x30, R2=0x50
            IN   R6              ; 0x60
            IN   R7              ; 0x70
            ADD  R6, R6, R7      ; 0xD0
            IN   R0              ; 0x80
            POP  R1              ; 0x40
            ADD  R0, R0, R1      ; 0xC0
            OUT  R2              ; 0x50
            OUT  R6              ; 0xD0
            OUT  R0              ; 0xC0
            HLT
        """,
    ),

    # 14. BTB 4-bit index collision ping-pong (0x80 and 0x90 share BTB index 0x0 with different tags)
    (
        "cc14_btb_index_aliasing_ping_pong",
        [],
        r"""
        .org 0x10
            LDM  R0, #6
            LDM  R1, #0
        OUTER_14:
            IADD R1, R1, #1
            SUB  R2, R0, R0      ; Z = 1
            JMP  0x80
        RET_80:
            SUB  R2, R0, R0      ; Z = 1
            JMP  0x90
        RET_90:
            IADD R0, R0, #-1
            JZ   DONE_14
            JMP  OUTER_14
        DONE_14:
            OUT  R1              ; Expect 6
            HLT

        .org 0x80
            JZ   RET_80          ; PC=0x80 -> BTB idx=0, tag=0x08
            HLT

        .org 0x90
            JZ   RET_90          ; PC=0x90 -> BTB idx=0, tag=0x09 (collides with 0x80!)
            HLT
        """,
    ),
]


# Live hardware INTR tests (custom Tcl cycle-precise pin stimulus)
HW_INTR_TESTS = [
    # 15. Multi-edge hardware INTR burst: edge #1 on 2-word JMP, edge #2 on exact hw_int_active cycle, edge #3 on hw_int_mem cycle!
    (
        "cc15_live_hw_intr_triple_burst",
        r"""
        .start MAIN
        .intr  HW_ISR

        .org 0x10
        MAIN:
            LDM  R0, #0
            LDM  R1, #100
            SETC                 ; C = 1 in main!
        SPIN:
            IADD R1, R1, #-1     ; 2-word op
            JZ   MAIN_DONE
            JMP  SPIN            ; 2-word JMP
        MAIN_DONE:
            ; Verify C=1 was preserved across all 3 hardware interrupts!
            JC   C_SURVIVED
            LDM  R7, #0xDEAD15
            HLT
        C_SURVIVED:
            OUT  R0              ; Must equal 3 (all 3 INTR edges serviced, none dropped!)
            HLT

        .org 0x80
        HW_ISR:
            ; Clobber flags inside ISR (C=0, N=1, Z=0) — RTI must restore caller CCR!
            LDM  R5, #-10
            IADD R5, R5, #1      ; C=0, N=1, Z=0
            IADD R0, R0, #1      ; Count ISR invocations in R0
            RTI
        """,
        # Tcl snippet after reset (30ns):
        # Fire pulse #1 at +35ns, then step cycle-by-cycle and fire pulse #2 on the EXACT cycle hw_int_active=='1',
        # and pulse #3 on a later cycle while hw_int_mem=='1'!
        r"""
        run 30ns
        # Pulse 1 during active 2-word SPIN loop
        run 30ns
        force -freeze /tb_Processor/intr 1
        run 10ns
        force -freeze /tb_Processor/intr 0
        # Step until hw_int_active == 1, then fire Pulse 2 right on the dispatch edge!
        for {set k 0} {$k < 30} {incr k} {
            if {[examine /tb_Processor/U_DUT/hw_int_active] eq "1"} {
                force -freeze /tb_Processor/intr 1
                run 10ns
                force -freeze /tb_Processor/intr 0
                break
            }
            run 10ns
        }
        # Now wait until that 2nd interrupt reaches hw_int_mem == 1, and fire Pulse 3 right on hw_int_mem!
        for {set k 0} {$k < 60} {incr k} {
            if {[examine /tb_Processor/U_DUT/hw_int_mem] eq "1" && $k > 5} {
                force -freeze /tb_Processor/intr 1
                run 10ns
                force -freeze /tb_Processor/intr 0
                break
            }
            run 10ns
        }
        run 9000ns
        """,
        {"R0": 3, "R1": 0, "SP": 0xFFF, "OUT": [3]},
    ),

    # 16. Hardware INTR arriving 1 cycle AFTER HLT is already in IF/ID (older HLT must win cleanly!)
    (
        "cc16_live_hw_intr_after_inflight_hlt",
        r"""
        .start MAIN
        .intr  BAD_ISR

        .org 0x10
        MAIN:
            LDM  R0, #0x42
            OUT  R0
            HLT                  ; PC = 0x13 -> HLT+1 = 0x14
            NOP
            NOP

        .org 0x80
        BAD_ISR:
            LDM  R0, #0xDEAD16
            OUT  R0
            RTI
        """,
        r"""
        run 30ns
        # Step cycle by cycle until HLT (0x0800) is in IF/ID, then immediately assert intr=1!
        for {set k 0} {$k < 20} {incr k} {
            if {[examine -hex /tb_Processor/U_DUT/ifid_ir] eq "0800" && [examine /tb_Processor/U_DUT/ifid_valid] eq "1"} {
                force -freeze /tb_Processor/intr 1
                run 10ns
                force -freeze /tb_Processor/intr 0
                break
            }
            run 10ns
        }
        run 300ns
        """,
        {"R0": 0x42, "PC": 0x14, "SP": 0xFFF, "OUT": [0x42]},
    ),
]


BAD_ASM_TESTS = [
    ("missing_operand",    ".org 0x10\nADD R1, R2\nHLT\n"),
    ("extra_operand",      ".org 0x10\nADD R1, R2, R3, R4\nHLT\n"),
    ("reg_out_of_range",   ".org 0x10\nINC R8\nHLT\n"),
    ("reg_trailing_junk",  ".org 0x10\nINC R1xyz\nHLT\n"),
    ("imm_trailing_junk",  ".org 0x10\nLDM R1, #123abc\nHLT\n"),
    ("duplicate_label",    ".org 0x10\nL1:\nNOP\nL1:\nHLT\n"),
    ("org_out_of_bounds",  ".org 5000\nNOP\n"),
    ("int_bad_index",      ".org 0x10\nINT 2\nHLT\n"),
]


def main():
    gpp = find_gpp()
    tmp_dir = tempfile.mkdtemp(prefix="risc6_cc_")
    asm_exe = os.path.join(tmp_dir, "assembler.exe" if os.name == "nt" else "assembler")

    try:
        print("=" * 78)
        print("6-STAGE PIPELINED RISC PROCESSOR — ADVERSARIAL CORNER-CASE SUITE")
        print("Designed by Anton Magdy (@AntonMagdy111) | Apache-2.0 License")
        print("=" * 78)

        # 1. Compile assembler with strict flags
        r = subprocess.run(
            [gpp, "-std=c++17", "-O2", "-Wall", "-Wextra", "-Werror",
             os.path.join(REPO_DIR, "assembler", "assembler.cpp"), "-o", asm_exe],
            capture_output=True, text=True,
        )
        assert r.returncode == 0 and r.stderr.strip() == "", f"g++ failed:\n{r.stderr}"
        print("[PASS] C++17 assembler compiled cleanly (-Wall -Wextra -Werror, 0 warnings).")

        # 2. Run negative assembler syntax/bounds tests
        for bname, bsrc in BAD_ASM_TESTS:
            ap = os.path.join(tmp_dir, f"bad_{bname}.asm")
            mp = os.path.join(tmp_dir, f"bad_{bname}.mem")
            with open(ap, "w", encoding="utf-8") as f:
                f.write(bsrc)
            rb = subprocess.run([asm_exe, ap, mp], capture_output=True, text=True)
            assert rb.returncode != 0, f"Assembler failed to reject malformed test {bname}!"
        print(f"[PASS] Assembler cleanly rejected {len(BAD_ASM_TESTS)}/{len(BAD_ASM_TESTS)} malformed/out-of-bounds inputs.")

        # 3. Assemble all 14 Golden-cosim corner tests + 2 live-INTR tests
        golden = {}
        mem_paths = {}
        for name, ins, src in CORNER_TESTS:
            ap = os.path.join(tmp_dir, f"{name}.asm")
            mp = os.path.join(tmp_dir, f"{name}.mem")
            with open(ap, "w", encoding="utf-8") as f:
                f.write(src)
            ra = subprocess.run([asm_exe, ap, mp], capture_output=True, text=True)
            assert ra.returncode == 0, f"Assemble failed on {name}:\n{ra.stderr}"
            mem_paths[name] = mp

            cpu = isa_sim.CPU(isa_sim.load_mem(mp))
            cpu.in_queue = list(ins)
            cpu.run(max_steps=10000)
            assert cpu.halted, f"Golden ISS did not halt on {name}!"
            golden[name] = (cpu.regs, cpu.sp, cpu.pc, f"{cpu.c}{cpu.n}{cpu.z}", cpu.out_log)

        for name, src, _, _ in HW_INTR_TESTS:
            ap = os.path.join(tmp_dir, f"{name}.asm")
            mp = os.path.join(tmp_dir, f"{name}.mem")
            with open(ap, "w", encoding="utf-8") as f:
                f.write(src)
            ra = subprocess.run([asm_exe, ap, mp], capture_output=True, text=True)
            assert ra.returncode == 0, f"Assemble failed on {name}:\n{ra.stderr}"
            mem_paths[name] = mp

        # 4. Build ModelSim batch script running all 16 corner-case tests
        tcl = [
            "if {[file isdirectory work]} { vdel -lib work -all }",
            "vlib work",
            "vmap work work",
            "vcom -2008 ../components/cpu_pkg.vhd",
            "vcom -2008 ../components/alu.vhd",
            "vcom -2008 ../components/RegisterFile.vhd",
            "vcom -2008 ../components/Memory.vhd",
            "vcom -2008 ../components/controlUnit.vhd",
            "vcom -2008 ../components/pc.vhd",
            "vcom -2008 ../components/sp.vhd",
            "vcom -2008 ../components/CCR.vhd",
            "vcom -2008 ../components/forwardingUnit.vhd",
            "vcom -2008 ../components/hazardDetectionUnit.vhd",
            "vcom -2008 ../components/outPutReg.vhd",
            "vcom -2008 ../components/branchPredictor.vhd",
            "vcom -2008 ../components/Pipelined_Registers/IF_ID.vhd",
            "vcom -2008 ../components/Pipelined_Registers/ID_EX1.vhd",
            "vcom -2008 ../components/Pipelined_Registers/EX1_EX2.vhd",
            "vcom -2008 ../components/Pipelined_Registers/EX2_MEM.vhd",
            "vcom -2008 ../components/Pipelined_Registers/MEM_WB.vhd",
            "vcom -2008 ../stages/fetchStage.vhd",
            "vcom -2008 ../stages/decodeStage.vhd",
            "vcom -2008 ../stages/execute1Stage.vhd",
            "vcom -2008 ../stages/execute2Stage.vhd",
            "vcom -2008 ../stages/memoryStage.vhd",
            "vcom -2008 ../stages/writeBackStage.vhd",
            "vcom -2008 ../Processor.vhd",
            "vcom -2008 ../tb_Processor.vhd",
            "proc run_cc {name mempath in_list} {",
            '    file copy -force $mempath "program.mem"',
            "    set n [llength $in_list]",
            '    set gargs ""',
            "    if {$n > 0} {",
            '        append gargs " -gIN_COUNT=$n"',
            "        for {set i 0} {$i < $n && $i < 8} {incr i} {",
            '            append gargs " -gIN_VAL$i=16#[lindex $in_list $i]"',
            "        }",
            "    }",
            '    eval "vsim -t 1ns work.tb_Processor -gCHECK_AT=9999999ns $gargs"',
            "    run 30ns",
            "    set out_log {}",
            "    for {set c 0} {$c < 1500} {incr c} {",
            "        run 10ns",
            '        if {[examine /tb_Processor/U_DUT/mem_out_en] eq "1"} {',
            "            lappend out_log [examine -hex /tb_Processor/U_DUT/mem_out_dat]",
            "        }",
            '        if {[examine /tb_Processor/U_DUT/halt_latch] eq "1" && $c > 5} {',
            "            for {set d 0} {$d < 6} {incr d} {",
            "                run 10ns",
            '                if {[examine /tb_Processor/U_DUT/mem_out_en] eq "1"} {',
            "                    lappend out_log [examine -hex /tb_Processor/U_DUT/mem_out_dat]",
            "                }",
            "            }",
            "            break",
            "        }",
            "    }",
            "    set regs {}",
            "    foreach r {r0 r1 r2 r3 r4 r5 r6 r7} { lappend regs [examine -hex /tb_Processor/$r] }",
            "    set sp  [examine -hex /tb_Processor/sp]",
            "    set pc  [examine -hex /tb_Processor/pc]",
            "    set ccr [examine -bin /tb_Processor/ccr]",
            '    puts "CC|$name|[join $regs ,]|$sp|$pc|$ccr|[join $out_log ,]"',
            "    quit -sim",
            "}",
        ]

        for name, ins, _ in CORNER_TESTS:
            mp = mem_paths[name].replace("\\", "/")
            in_s = " ".join(f"{v:08X}" for v in ins)
            tcl.append(f'run_cc "{name}" "{mp}" {{{in_s}}}')

        for name, _, custom_tcl, _ in HW_INTR_TESTS:
            mp = mem_paths[name].replace("\\", "/")
            tcl += [
                f'file copy -force "{mp}" "program.mem"',
                "vsim -t 1ns work.tb_Processor -gCHECK_AT=9999999ns",
                custom_tcl,
                "set regs {}",
                "foreach r {r0 r1 r2 r3 r4 r5 r6 r7} { lappend regs [examine -hex /tb_Processor/$r] }",
                "set sp   [examine -hex /tb_Processor/sp]",
                "set pc   [examine -hex /tb_Processor/pc]",
                "set outp [examine -hex /tb_Processor/out_port]",
                f'puts "HW|{name}|[join $regs ,]|$sp|$pc|$outp"',
                "quit -sim",
            ]

        tcl.append("quit -f")
        do_file = os.path.join(SIM_DIR, "_corner_cases.do")
        with open(do_file, "w", encoding="utf-8") as f:
            f.write("\n".join(tcl) + "\n")

        res = subprocess.run(["vsim", "-c", "-do", "_corner_cases.do"], cwd=SIM_DIR, capture_output=True, text=True)
        os.remove(do_file)
        shutil.copyfile(os.path.join(REPO_DIR, "test", "test_arithmetic.mem"), os.path.join(SIM_DIR, "program.mem"))

        assert_fails = [l for l in res.stdout.splitlines() if "ASSERT FAIL" in l or "** Failure:" in l or "** Error:" in l]
        warns = [l for l in res.stdout.splitlines() if "** Warning:" in l]

        cc_results = {}
        hw_results = {}
        for line in res.stdout.splitlines():
            c = line.lstrip("# ").strip()
            if c.startswith("CC|"):
                _, nm, rs, sp_s, pc_s, ccr_s, ol_s = c.split("|")
                cc_results[nm] = (
                    [int(x, 16) for x in rs.split(",")],
                    int(sp_s, 16),
                    int(pc_s, 16),
                    ccr_s,
                    [int(x, 16) for x in ol_s.split(",") if x],
                )
            elif c.startswith("HW|"):
                _, nm, rs, sp_s, pc_s, outp_s = c.split("|")
                hw_results[nm] = (
                    [int(x, 16) for x in rs.split(",")],
                    int(sp_s, 16),
                    int(pc_s, 16),
                    int(outp_s, 16),
                )

        passed = 0
        failed = 0
        for name, _, _ in CORNER_TESTS:
            assert name in cc_results, f"Missing result for {name}\n{res.stdout[-2000:]}"
            got_r, got_sp, got_pc, got_ccr, got_ol = cc_results[name]
            exp_r, exp_sp, exp_pc, exp_ccr, exp_ol = golden[name]
            errs = []
            for i in range(8):
                if got_r[i] != exp_r[i]:
                    errs.append(f"R{i}=0x{got_r[i]:08X}!=0x{exp_r[i]:08X}")
            if got_sp != exp_sp:   errs.append(f"SP=0x{got_sp:08X}!=0x{exp_sp:08X}")
            if got_pc != exp_pc:   errs.append(f"PC=0x{got_pc:08X}!=0x{exp_pc:08X}")
            if got_ccr != exp_ccr: errs.append(f"CCR={got_ccr}!={exp_ccr}")
            if got_ol != exp_ol:   errs.append(f"OUT={got_ol}!={exp_ol}")
            if not errs:
                passed += 1
                print(f"  [PASS] {name}")
            else:
                failed += 1
                print(f"  [FAIL] {name}: " + "; ".join(errs))

        for name, _, _, exp in HW_INTR_TESTS:
            assert name in hw_results, f"Missing HW result for {name}"
            got_r, got_sp, got_pc, got_outp = hw_results[name]
            errs = []
            for k, v in exp.items():
                if k.startswith("R"):
                    idx = int(k[1:])
                    if got_r[idx] != v:
                        errs.append(f"{k}=0x{got_r[idx]:08X}!=0x{v:08X}")
                elif k == "SP" and got_sp != v:
                    errs.append(f"SP=0x{got_sp:08X}!=0x{v:08X}")
                elif k == "PC" and got_pc != v:
                    errs.append(f"PC=0x{got_pc:08X}!=0x{v:08X}")
                elif k == "OUT" and got_outp != v[-1]:
                    errs.append(f"OUT=0x{got_outp:08X}!=0x{v[-1]:08X}")
            if not errs:
                passed += 1
                print(f"  [PASS] {name}")
            else:
                failed += 1
                print(f"  [FAIL] {name}: " + "; ".join(errs))

        print("-" * 78)
        print(f"CORNER-CASE RTL SUMMARY : {passed} / {len(CORNER_TESTS) + len(HW_INTR_TESTS)} PASSED, {failed} FAILED")
        print(f"COMPILER WARNINGS       : {len(warns)}")
        print(f"ASSERTION FAILURES (16) : {len(assert_fails)}")
        if assert_fails:
            for af in assert_fails[:10]:
                print("  ", af)
        print("=" * 78)

        sys.exit(0 if (failed == 0 and len(assert_fails) == 0 and len(warns) == 0) else 1)
    finally:
        shutil.rmtree(tmp_dir, ignore_errors=True)


if __name__ == "__main__":
    main()
