; Test 047: JC should not jump when carry is zero
.org 0x10
LDM R0, 0x1
LDM R1, 0x2
ADD R2, R0, R1
JC TARGET
LDM R3, 0xAAAA
JMP DONE
TARGET:
LDM R3, 0xBAD
DONE:
HLT
