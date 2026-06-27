; OneOperand.txt - all numbers hex
; IN values: R1=5, R2=10
.org 0
    .word 0xA0
.org 0xA0
    NOP
    NOT R1
    INC R1
    IN R1
    IN R2
    NOT R2
    INC R1
    OUT R1
    OUT R2
    SETC
    INC R2
    OUT R2
    HLT
