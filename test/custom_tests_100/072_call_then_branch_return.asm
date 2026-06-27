; Test 072: Subroutine uses branch before RET
.org 0x10
LDM R0, 0x1
CALL SUB
IADD R0, R0, 0x1
HLT
SUB:
SUB R1, R1, R1
JZ SKIP
LDM R7, 0xBAD
SKIP:
IADD R0, R0, 0x5
RET
