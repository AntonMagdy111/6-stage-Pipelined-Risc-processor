; Test 028: SWAP followed by dependent ADD
.org 0x10
LDM R0, 0x000A
LDM R1, 0x0005
SWAP R0, R1
ADD R2, R0, R1
HLT
