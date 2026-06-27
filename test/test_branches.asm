; test_branches.asm
; Verifies: JZ, JN, JC, JMP, CALL, RET

.org 2
START:
    LDM   R0, #5
    LDM   R1, #5
    SUB   R2, R0, R1    ; R2 = 0, Z = 1
    JZ    HIT_ZERO      ; should jump
    LDM   R7, #0xDEAD   ; should be skipped
HIT_ZERO:
    LDM   R7, #0xAAAA   ; R7 = 0xAAAA  (proves we jumped)

    ; Test JN with negative result
    LDM   R0, #1
    LDM   R1, #2
    SUB   R3, R0, R1    ; R3 = -1, N = 1
    JN    HIT_NEG
    LDM   R6, #0xBAD
HIT_NEG:
    LDM   R6, #0xBBBB   ; R6 = 0xBBBB

    ; Test JC (carry out from add)
    LDM   R0, #0xFFFFFFFF
    LDM   R1, #1
    ADD   R4, R0, R1    ; R4 = 0, C = 1
    JC    HIT_C
    LDM   R5, #0xBAD
HIT_C:
    LDM   R5, #0xCCCC   ; R5 = 0xCCCC

    ; Test CALL/RET
    CALL  FUNC
    LDM   R0, #0xABCD   ; should be reached after RET
    JMP   DONE

FUNC:
    LDM   R1, #0x1111
    RET

DONE:
    HLT
