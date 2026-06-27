; test_edgecases.asm - Full test with real INC overflow

.org 2
START:
    ; TEST 1: INC overflow -> Z=1, C=1
    LDM   R0, #0xFFFFFFFF
    INC   R0            ; R0=0, Z=1, C=1
    JZ    INC_OK
    LDM   R7, #0xDEAD
INC_OK:
    JC    INC_C_OK
    LDM   R7, #0xDEAD
INC_C_OK:
    LDM   R1, #0x1111

    ; TEST 2: NOT of 0 -> N=1
    LDM   R2, #0
    NOT   R2            ; R2=0xFFFFFFFF, N=1
    JN    NOT_OK
    LDM   R7, #0xDEAD
NOT_OK:
    LDM   R3, #0x2222

    ; TEST 3: SUB zero -> Z=1
    LDM   R4, #42
    LDM   R5, #42
    SUB   R6, R4, R5    ; Z=1
    JZ    SUB_OK
    LDM   R7, #0xDEAD
SUB_OK:
    LDM   R4, #0x3333

    ; TEST 4: JN not taken (N=0)
    LDM   R0, #10
    LDM   R1, #3
    SUB   R5, R0, R1    ; R5=7, N=0
    JN    WRONG_N
    LDM   R5, #0x4444
    JMP   NESTED_TEST
WRONG_N:
    LDM   R5, #0xDEAD

    ; TEST 5: Nested CALL
NESTED_TEST:
    CALL  OUTER
    LDM   R6, #0x5555
    JMP   DONE

OUTER:
    LDM   R0, #0xAAAA
    CALL  INNER
    LDM   R1, #0xBBBB
    RET

INNER:
    LDM   R2, #0xCCCC
    RET

DONE:
    HLT
