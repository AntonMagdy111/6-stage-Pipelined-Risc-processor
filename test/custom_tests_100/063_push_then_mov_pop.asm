; Test 063: PUSH source after MOV and POP destination
.org 0x10
LDM R0, 0x1111
MOV R1, R0
PUSH R1
POP R2
HLT
