; Test 056: Second STD should overwrite same address
.org 0x10
LDM R0, 0x1B0
LDM R1, 0x1111
LDM R2, 0x3333
STD R1, 0x0(R0)
STD R2, 0x0(R0)
LDD R3, 0x0(R0)
HLT
