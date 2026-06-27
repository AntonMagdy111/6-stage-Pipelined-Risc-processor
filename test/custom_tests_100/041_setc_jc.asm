; Test 041: SETC followed by JC must jump
.org 0x10
SETC
JC TARGET
LDM R0, 0xBAD
TARGET:
LDM R1, 0xCAFE
HLT
