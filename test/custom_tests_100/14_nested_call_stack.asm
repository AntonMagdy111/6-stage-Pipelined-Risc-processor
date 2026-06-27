; Checks nested CALL/RET stack behavior.
.org 0x10
LDM R0, 0x1
CALL A
IADD R0, R0, 0xA
HLT
A:
IADD R0, R0, 0x2
CALL B
IADD R0, R0, 0x4
RET
B:
IADD R0, R0, 0x3
RET
