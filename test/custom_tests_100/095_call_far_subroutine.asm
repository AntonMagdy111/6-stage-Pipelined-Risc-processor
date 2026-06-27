; Test 095: CALL to far .ORG subroutine
.org 0x10
LDM R0, 0x1
CALL FAR_SUB
IADD R0, R0, 0x1
HLT
.org 0x300
FAR_SUB:
IADD R0, R0, 0x10
RET
