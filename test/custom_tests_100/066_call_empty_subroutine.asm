; Test 066: CALL/RET to empty subroutine
.org 0x10
LDM R0, 0x1
CALL SUB
IADD R0, R0, 0x1
HLT
SUB:
RET
LDM R7, 0xBAD
