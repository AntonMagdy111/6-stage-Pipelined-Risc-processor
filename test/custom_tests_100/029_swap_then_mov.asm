; Test 029: SWAP followed by MOVs from both swapped registers
.org 0x10
LDM R0, 0x00AA
LDM R1, 0x0055
SWAP R0, R1
MOV R2, R0
MOV R3, R1
HLT
