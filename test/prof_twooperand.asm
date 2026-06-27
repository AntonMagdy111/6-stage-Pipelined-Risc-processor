; TwoOperand.txt - all numbers hex
; IN values: R1=5, R2=19, R3=FFFFFFFF, R4=FFFFF320
.org 0
    .word 0xFF
.org 0xFF
    IN R1
    IN R2
    IN R3
    IN R4
    MOV R5, R3
    ADD R4, R1, R4
    SUB R6, R5, R4
    AND R4, R7, R4
    IADD R2, R2, 0xFFFF
    SWAP R2, R4
    ADD R2, R1, R2
    ADD R6, R4, R2
    IADD R6, R6, 0x2
    AND R3, R2, R6
    HLT
