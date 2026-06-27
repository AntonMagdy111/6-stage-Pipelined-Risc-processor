; Checks negative flag and JN taken.
.org 0x10
LDM R0, 0x3
LDM R1, 0x5
SUB R2, R0, R1
JN NEG_OK
LDM R7, 0xBAD
NEG_OK:
LDM R3, 0x7777
HLT
