; Test 088: LDD should not modify flags from previous SUB zero
.org 0x10
LDM R0, 0x200
LDM R1, 0x1111
STD R1, 0x0(R0)
SUB R2, R2, R2
LDD R3, 0x0(R0)
JZ TARGET
LDM R4, 0xBAD
TARGET:
LDM R5, 0x5555
HLT
