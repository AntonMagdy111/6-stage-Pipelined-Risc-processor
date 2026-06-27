; Test 094: Store/load near top of 4KB memory
.org 0x10
LDM R0, 0x3F0
LDM R1, 0xAAAA
STD R1, 0x5(R0)
LDD R2, 0x5(R0)
HLT
