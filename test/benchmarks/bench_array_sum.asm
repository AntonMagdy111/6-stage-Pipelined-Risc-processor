; ==========================================================================
; Project : 6-Stage Pipelined 32-Bit Von Neumann RISC Processor
; Author  : Anton Magdy (@AntonMagdy111) - https://github.com/AntonMagdy111
; Repo    : https://github.com/AntonMagdy111/6-stage-Pipelined-Risc-processor
; License : Apache-2.0 (see LICENSE and NOTICE for mandatory attribution)
; SPDX-License-Identifier: Apache-2.0
; Copyright (c) 2026 Anton Magdy. All rights reserved.
; ==========================================================================
; bench_array_sum.asm — Store 12 elements [1..12] into RAM and sum them
; Exercises: STD/LDD memory streaming, 1-cycle load-use stall, BTB loops.
; Expected: R4 = 78 (0x004E), OUT.PORT = 0x0000004E
.org 0x10
    LDM  R0, #0x200      ; ptr = base address
    LDM  R1, #1          ; val = 1
    LDM  R2, #13         ; end_val = 13 (stores 1..12)
STORE_LOOP:
    STD  R1, 0(R0)       ; M[ptr] = val
    IADD R0, R0, #1      ; ptr++
    IADD R1, R1, #1      ; val++
    SUB  R3, R1, R2      ; val - 13
    JN   STORE_LOOP

    LDM  R0, #0x200      ; ptr = base
    LDM  R2, #0x20C      ; end_ptr = base + 12
    LDM  R4, #0          ; sum = 0
SUM_LOOP:
    LDD  R5, 0(R0)       ; elem = M[ptr]
    ADD  R4, R4, R5      ; sum += elem  (1-cycle load-use hazard!)
    IADD R0, R0, #1      ; ptr++
    SUB  R3, R0, R2      ; ptr - end_ptr
    JN   SUM_LOOP
    OUT  R4              ; OUT = 78 (0x004E)
    HLT
