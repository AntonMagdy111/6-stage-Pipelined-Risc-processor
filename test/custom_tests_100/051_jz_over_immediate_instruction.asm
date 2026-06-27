; Test 051: Taken JZ must flush skipped LDM immediate pair
.org 0x10
SUB R0, R0, R0
JZ TARGET
LDM R1, 0xBAD
TARGET:
LDM R2, 0x2222
HLT
