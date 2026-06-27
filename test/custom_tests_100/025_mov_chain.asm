; Test 025: MOV dependency chain across multiple registers
.org 0x10
LDM R0, 0x1111
MOV R1, R0
MOV R2, R1
MOV R3, R2
MOV R4, R3
HLT
