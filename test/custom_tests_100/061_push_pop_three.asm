; Test 061: Three pushes and three pops should be LIFO
.org 0x10
LDM R0, 0x1
LDM R1, 0x2
LDM R2, 0x3
PUSH R0
PUSH R1
PUSH R2
POP R3
POP R4
POP R5
HLT
