; Test 052: LDD from address stored by STD at base zero plus offset
.org 0x10
LDM R0, 0x0
LDM R1, 0x1357
STD R1, 0x180(R0)
LDD R2, 0x180(R0)
HLT
