; Branch.txt
.org 0
    .word 0x10
.org 0x2
    .word 0x900
.org 0x900
    IN R7
    AND R0, R0, R0
    OUT R3
    RTI
    IADD R1, R2, 0x3
.org 0x10
    IN R1
    IN R2
    IN R3
    IN R4
    PUSH R4
    JMP 0x30
    INC R1
.org 0x30
    AND R5, R1, R5
    JZ 0x50
    SETC
.org 0x50
    JZ 0x30
    NOT R5
    SUB R7, R5, R5
    IN R1
    JZ 0x60
    ADD R1, R2, R3
.org 0x60
    IN R1
    JZ 0x70
    JMP 0x70
    INC R1
.org 0x70
    IADD R1, R1, 0x10
    SUB R7, R1, R1
    PUSH R1
    POP R1
    JZ 0x80
    INC R1
.org 0x80
    IN R6
    JMP 0x700
.org 0x700
    ADD R7, R0, R1
    POP R6
    CALL 0x300
    INC R6
    NOP
    NOP
    HLT
.org 0x300
    ADD R6, R3, R6
    ADD R1, R1, R2
    RET
    ADD R1, R1, R1
.org 0x500
    NOP
    NOP
