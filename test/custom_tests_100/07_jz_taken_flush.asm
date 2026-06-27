; Checks Z flag and taken JZ flush.
.org 0x10
LDM R0, 0x5
SUB R1, R0, R0
JZ ZERO_OK
LDM R7, 0xBAD
ZERO_OK:
LDM R2, 0x1111
HLT
