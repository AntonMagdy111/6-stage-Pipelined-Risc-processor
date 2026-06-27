; Checks STD then LDD with base+offset addressing.
.org 0x10
LDM R0, 0x100
LDM R1, 0xCAFE
STD R1, 0x10(R0)
LDD R2, 0x10(R0)
LDM R3, 0xBEEF
STD R3, 0x11(R0)
LDD R4, 0x11(R0)
HLT
