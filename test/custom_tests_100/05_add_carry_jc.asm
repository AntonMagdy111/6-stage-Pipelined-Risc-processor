; Checks ADD carry and JC taken. Wrong flush will execute BAD path.
.org 0x10
LDM R0, 0xFFFFFFFF
LDM R1, 0x1
ADD R2, R0, R1
JC CARRY_OK
LDM R7, 0xBAD
CARRY_OK:
LDM R3, 0xCAFE
HLT
