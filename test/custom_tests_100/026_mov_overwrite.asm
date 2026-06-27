; Test 026: MOV overwrites a previous register value
.org 0x10
LDM R0, 0xAAAA
LDM R1, 0xBBBB
MOV R0, R1
MOV R2, R0
HLT
