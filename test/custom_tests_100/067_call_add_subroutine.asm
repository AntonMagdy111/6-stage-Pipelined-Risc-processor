; Test 067: Subroutine increments R0 then returns
.org 0x10
LDM R0, 0x2
CALL SUB
IADD R0, R0, 0x3
HLT
SUB:
IADD R0, R0, 0x4
RET
