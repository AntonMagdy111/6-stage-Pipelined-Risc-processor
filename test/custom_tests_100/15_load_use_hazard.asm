; Checks LDD followed immediately by dependent ADD.
.org 0x10
LDM R0, 0x120
LDM R1, 0x25
STD R1, 0x0(R0)
LDD R2, 0x0(R0)
ADD R3, R2, R2
IADD R4, R3, 0x1
HLT
