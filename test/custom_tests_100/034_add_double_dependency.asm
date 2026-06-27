; Test 034: ADD uses result from immediately previous ADD
.org 0x10
LDM R0, 0x3
LDM R1, 0x4
ADD R2, R0, R1
ADD R3, R2, R2
ADD R4, R3, R2
HLT
