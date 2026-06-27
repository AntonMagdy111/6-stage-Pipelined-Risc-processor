; Test 059: LDD immediately followed by dependent ADD
.org 0x10
LDM R0, 0x1E0
LDM R1, 0x12
STD R1, 0x0(R0)
LDD R2, 0x0(R0)
ADD R3, R2, R2
HLT
