; Test 048: LDM should not change Z flag set by previous SUB
.org 0x10
LDM R0, 0x7
SUB R1, R0, R0
LDM R2, 0x1234
JZ TARGET
LDM R3, 0xBAD
TARGET:
LDM R4, 0xABCD
HLT
