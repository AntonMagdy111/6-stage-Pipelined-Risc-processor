; Test 035: ADD overflow wraps result to zero
.org 0x10
LDM R0, 0xFFFFFFFF
LDM R1, 0x1
ADD R2, R0, R1
MOV R3, R2
HLT
