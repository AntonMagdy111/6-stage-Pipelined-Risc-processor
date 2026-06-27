; Checks SUB borrow sets carry and JC taken.
.org 0x10
LDM R0, 0x3
LDM R1, 0x5
SUB R2, R0, R1
JC BORROW_OK
LDM R7, 0xBAD
BORROW_OK:
LDM R3, 0x1234
HLT
