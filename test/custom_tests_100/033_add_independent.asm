; Test 033: Independent ADD operations
.org 0x10
LDM R0, 0x10
LDM R1, 0x20
ADD R2, R0, R1
LDM R3, 0x7
ADD R4, R2, R3
HLT
