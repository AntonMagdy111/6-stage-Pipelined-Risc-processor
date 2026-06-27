; Test 027: SWAP with same register should leave value unchanged
.org 0x10
LDM R3, 0x1357
SWAP R3, R3
MOV R4, R3
HLT
