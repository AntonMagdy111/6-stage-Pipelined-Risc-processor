; test_arithmetic.asm
; Verifies: NOP, SETC, NOT, INC, MOV, SWAP, ADD, SUB, AND, IADD, LDM
; Final expected state:
;   R0 = 0xBEEF (from LDM at end)
;   R1 = 5 + 3 = 8 (ADD)
;   R2 = 5 - 3 = 2 (SUB), then SWAP with R3
;   R3 = 5 & 3 = 1 (AND), then swap with R2 -> R3 = 2, R2 = 1
;   R4 = ~5 = 0xFFFFFFFA (NOT)
;   R5 = 6 (INC of 5)
;   R6 = 5 (MOV from R7)
;   R7 = 5
;   C   = 1 (SETC)

.org 2
START:
    NOP
    SETC                ; C <- 1

    LDM   R7, #5
    LDM   R6, #5        ; will move into; just init to something
    MOV   R6, R7        ; R6 = R7 = 5
    LDM   R0, #5
    LDM   R1, #3
    ADD   R1, R0, R1    ; R1 = 5 + 3 = 8
    LDM   R0, #5
    LDM   R5, #5
    SUB   R2, R0, R5    ; ... wait, we need LDM R5 = 3 for SUB. Let's do step by step.
    LDM   R5, #3
    SUB   R2, R0, R5    ; R2 = 5 - 3 = 2
    AND   R3, R0, R5    ; R3 = 5 & 3 = 1
    NOT   R4            ; R4 = ~R4. R4 was 0 -> 0xFFFFFFFF
    LDM   R4, #5
    NOT   R4            ; R4 = ~5 = 0xFFFFFFFA
    LDM   R5, #5
    INC   R5            ; R5 = 6
    SWAP  R2, R3        ; R2 <-> R3 -> R2=1, R3=2
    IADD  R6, R7, #10   ; R6 = R7 + 10 = 15
    LDM   R0, #0xBEEF
    HLT
