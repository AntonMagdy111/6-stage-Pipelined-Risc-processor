; Test 082: IADD result immediately used by IADD and ADD
.org 0x10
LDM R0, 0x10
IADD R1, R0, 0x1
IADD R2, R1, 0x2
ADD R3, R2, R1
HLT
