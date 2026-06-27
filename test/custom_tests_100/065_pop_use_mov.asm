; Test 065: POP result immediately used by MOV
.org 0x10
LDM R0, 0x55
PUSH R0
POP R1
MOV R2, R1
HLT
