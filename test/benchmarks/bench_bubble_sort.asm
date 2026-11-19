; bench_bubble_sort.asm — In-memory Bubble Sort of 6 numbers using SWAP
; Input:  [42, 7, 99, 3, 55, 18] at M[0x300..0x305]
; Output: R2=3, R3=7, R4=18, R5=42, R6=55, R7=99, OUT.PORT = 99 (0x0063)
; Exercises: LDD, STD, SWAP, nested BTB loops, conditional branch skipping.
.org 0x10
    LDM  R0, #0x300
    LDM  R1, #42
    STD  R1, 0(R0)
    LDM  R1, #7
    STD  R1, 1(R0)
    LDM  R1, #99
    STD  R1, 2(R0)
    LDM  R1, #3
    STD  R1, 3(R0)
    LDM  R1, #55
    STD  R1, 4(R0)
    LDM  R1, #18
    STD  R1, 5(R0)

    LDM  R2, #5          ; outer passes = 5
OUTER_LOOP:
    LDM  R0, #0x300      ; ptr = base
    LDM  R3, #0x305      ; end_ptr = base + 5
INNER_LOOP:
    LDD  R4, 0(R0)       ; a = M[ptr]
    LDD  R5, 1(R0)       ; b = M[ptr+1]
    SUB  R6, R5, R4      ; b - a; if b < a (N=1), swap!
    JN   DO_SWAP
    JMP  NO_SWAP
DO_SWAP:
    SWAP R4, R5          ; exchange a <-> b
    STD  R4, 0(R0)
    STD  R5, 1(R0)
NO_SWAP:
    IADD R0, R0, #1      ; ptr++
    SUB  R6, R0, R3      ; ptr - end_ptr
    JN   INNER_LOOP
    IADD R2, R2, #-1     ; outer--
    JZ   SORT_DONE
    JMP  OUTER_LOOP

SORT_DONE:
    LDM  R0, #0x300
    LDD  R2, 0(R0)       ; 3
    LDD  R3, 1(R0)       ; 7
    LDD  R4, 2(R0)       ; 18
    LDD  R5, 3(R0)       ; 42
    LDD  R6, 4(R0)       ; 55
    LDD  R7, 5(R0)       ; 99
    OUT  R7              ; OUT = 99 (0x0063)
    HLT
