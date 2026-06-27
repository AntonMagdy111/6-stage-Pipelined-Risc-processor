; Checks NOT, INC, zero/negative/carry side effects indirectly by data.
.org 0x10
LDM R0, 0xFFFFFFFF
INC R0
NOT R0
INC R1
LDM R2, 0x0
NOT R2
HLT
