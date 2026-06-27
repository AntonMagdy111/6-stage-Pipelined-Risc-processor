; Test 084: MOV result immediately used by ADD
.org 0x10
LDM R0, 0x9
MOV R1, R0
ADD R2, R1, R1
HLT
