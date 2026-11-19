; ==========================================================================
; Project : 6-Stage Pipelined 32-Bit Von Neumann RISC Processor
; Author  : Anton Magdy (@AntonMagdy111) - https://github.com/AntonMagdy111
; Repo    : https://github.com/AntonMagdy111/6-stage-Pipelined-Risc-processor
; License : Apache-2.0 (see LICENSE and NOTICE for mandatory attribution)
; SPDX-License-Identifier: Apache-2.0
; Copyright (c) 2026 Anton Magdy. All rights reserved.
; ==========================================================================
; bench_fibonacci.asm — Iterative Fibonacci F(15) = 610 (0x0262)
; Exercises: tight ALU forwarding chains + 2-bit BTB loop prediction.
; Expected: R0 = 610 (0x0262), R1 = 987 (0x03DB), OUT.PORT = 0x00000262
.org 0x10
    LDM  R0, #0          ; a = F(0) = 0
    LDM  R1, #1          ; b = F(1) = 1
    LDM  R2, #0          ; i = 0
    LDM  R3, #15         ; N = 15
FIB_LOOP:
    ADD  R4, R0, R1      ; next = a + b
    MOV  R0, R1          ; a = b
    MOV  R1, R4          ; b = next
    IADD R2, R2, #1      ; i++
    SUB  R5, R2, R3      ; i - N
    JN   FIB_LOOP        ; loop while i < N
    OUT  R0              ; OUT = F(15) = 610 (0x0262)
    HLT
