; Test 045: NOT zero creates FFFFFFFF; JN should be taken
.org 0x10
LDM R0, 0x0
NOT R0
JN TARGET
LDM R1, 0xBAD
TARGET:
LDM R2, 0x9999
HLT
