; Test 037: SUB creates negative two's-complement result
.org 0x10
LDM R0, 0x3
LDM R1, 0x8
SUB R2, R0, R1
MOV R3, R2
HLT
