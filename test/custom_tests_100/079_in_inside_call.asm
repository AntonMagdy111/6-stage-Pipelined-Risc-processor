; Test 079: IN instruction inside subroutine
.org 0x10
CALL SUB
MOV R1, R0
HLT
SUB:
IN R0
RET
