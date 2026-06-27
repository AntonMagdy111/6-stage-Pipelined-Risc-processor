; Test 031: INC increments zero to one and forwards result
.org 0x10
INC R0
MOV R1, R0
INC R1
HLT
