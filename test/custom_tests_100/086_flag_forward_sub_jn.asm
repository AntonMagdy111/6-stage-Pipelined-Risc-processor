; Test 086: SUB negative result followed immediately by JN
.org 0x10
LDM R0, 0x1
LDM R1, 0x2
SUB R2, R0, R1
JN TARGET
LDM R3, 0xBAD
TARGET:
LDM R4, 0x5555
HLT
