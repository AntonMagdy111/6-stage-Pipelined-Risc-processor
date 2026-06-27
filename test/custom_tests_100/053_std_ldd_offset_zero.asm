; Test 053: STD/LDD with offset zero
.org 0x10
LDM R0, 0x190
LDM R1, 0x2468
STD R1, 0x0(R0)
LDD R2, 0x0(R0)
HLT
