; Memory.txt
; IN values: R2=19, R3=FFFFFFFF, R4=FFFFF320, then R5=10, R5=10, R2=19
.org 0
    .word 0x300
.org 0x300
    IN R2
    IN R3
    IN R4
    LDM R1, 0x5
    PUSH R1
    PUSH R2
    POP R1
    POP R2
    ADD R5, R2, R1
    IN R5
    STD R2, 0x200(R5)
    STD R1, 0x201(R5)
    LDD R3, 0x201(R5)
    LDD R4, 0x200(R5)
    ADD R5, R4, R3
    IN R5
    IN R2
    STD R4, 0x200(R2)
    LDD R3, 0x201(R5)
    LDD R2, 0x200(R3)
    ADD R2, R2, R3
    HLT
