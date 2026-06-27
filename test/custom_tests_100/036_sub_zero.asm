; Test 036: SUB equal operands produces zero
.org 0x10
LDM R0, 0x5555
SUB R1, R0, R0
MOV R2, R1
HLT
