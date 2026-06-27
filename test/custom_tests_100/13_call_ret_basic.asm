; Checks CALL stores return PC and RET restores it.
.org 0x10
LDM R0, 0x1
CALL SUB1
IADD R0, R0, 0x3
HLT
SUB1:
IADD R0, R0, 0x2
RET
LDM R7, 0xBAD
