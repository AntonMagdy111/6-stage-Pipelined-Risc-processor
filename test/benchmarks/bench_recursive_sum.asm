; ==========================================================================
; Project : 6-Stage Pipelined 32-Bit Von Neumann RISC Processor
; Author  : Anton Magdy (@AntonMagdy111) - https://github.com/AntonMagdy111
; Repo    : https://github.com/AntonMagdy111/6-stage-Pipelined-Risc-processor
; License : Apache-2.0 (see LICENSE and NOTICE for mandatory attribution)
; SPDX-License-Identifier: Apache-2.0
; Copyright (c) 2026 Anton Magdy. All rights reserved.
; ==========================================================================
; bench_recursive_sum.asm — 10-level recursive CALL/RET with stack frames
; Computes sum(10) = 10 + 9 + ... + 1 = 55 (0x0037)
; Exercises: deep nested CALL/RET, zero-bubble CALL, PUSH/POP stack frames.
; Expected: R1 = 55 (0x0037), SP = 0x0FFF, OUT.PORT = 0x00000037
.org 0x10
    LDM  R0, #10         ; argument N = 10
    LDM  R1, #0          ; accumulator = 0
    LDM  R7, #0          ; constant 0 for compare
    CALL REC_SUM
    OUT  R1              ; OUT = 55 (0x0037)
    HLT

REC_SUM:
    SUB  R6, R0, R7      ; check if N == 0
    JZ   BASE_CASE
    PUSH R0              ; save N on stack frame
    IADD R0, R0, #-1     ; N = N - 1
    CALL REC_SUM         ; recurse
    POP  R2              ; restore saved N
    ADD  R1, R1, R2      ; acc += N (1-cycle pop-use hazard!)
BASE_CASE:
    RET
    LDM  R5, #0xBAD      ; wrong-path guard after RET
