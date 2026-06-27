; Test 068: Instruction after subroutine RET should not execute before return
.org 0x10
LDM R0, 0x1
CALL SUB
IADD R0, R0, 0x1
HLT
SUB:
IADD R0, R0, 0x5
RET
LDM R7, 0xBAD
