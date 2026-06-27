; Test 054: STD/LDD with nonzero offset
.org 0x10
LDM R0, 0x190
LDM R1, 0xAAAA
STD R1, 0x5(R0)
LDD R2, 0x5(R0)
HLT
