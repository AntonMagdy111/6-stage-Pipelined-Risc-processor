; Test 055: Store and load two different memory addresses
.org 0x10
LDM R0, 0x1A0
LDM R1, 0x1111
LDM R2, 0x2222
STD R1, 0x0(R0)
STD R2, 0x1(R0)
LDD R3, 0x0(R0)
LDD R4, 0x1(R0)
HLT
