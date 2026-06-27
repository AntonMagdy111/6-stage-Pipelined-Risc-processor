; Checks MOV and SWAP register routing.
.org 0x10
LDM R0, 0xAAAA
LDM R1, 0x5555
MOV R2, R0
SWAP R0, R1
MOV R3, R0
MOV R4, R1
HLT
