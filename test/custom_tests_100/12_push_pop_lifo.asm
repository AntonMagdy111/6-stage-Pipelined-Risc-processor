; Checks stack LIFO order and final SP.
.org 0x10
LDM R0, 0xAAAA
LDM R1, 0xBBBB
PUSH R0
PUSH R1
POP R2
POP R3
HLT
