; Test 040: IADD with negative immediate encoded as -1
.org 0x10
LDM R0, 0x10
IADD R1, R0, -1
IADD R2, R1, -2
HLT
