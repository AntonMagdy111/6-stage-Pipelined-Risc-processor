; Test 039: IADD with positive immediate
.org 0x10
LDM R0, 0x10
IADD R1, R0, 0x25
IADD R2, R1, 0x5
HLT
