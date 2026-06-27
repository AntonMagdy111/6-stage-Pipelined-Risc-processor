; test_memory.asm
; Verifies: LDM, LDD, STD, PUSH, POP

.org 2
START:
    LDM   R0, #0xCAFE     ; R0 = 0xCAFE
    LDM   R1, #100        ; R1 = 100 (address)
    STD   R0, 0(R1)       ; M[100] = 0xCAFE
    LDD   R2, 0(R1)       ; R2 = M[100] = 0xCAFE
    STD   R0, 5(R1)       ; M[105] = 0xCAFE
    LDD   R3, 5(R1)       ; R3 = 0xCAFE

    LDM   R4, #0xAA
    PUSH  R4              ; push 0xAA, SP = 4094
    LDM   R5, #0xBB
    PUSH  R5              ; push 0xBB, SP = 4093
    POP   R6              ; R6 = 0xBB, SP = 4094
    POP   R7              ; R7 = 0xAA, SP = 4095
    HLT
