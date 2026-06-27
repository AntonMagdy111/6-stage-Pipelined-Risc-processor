; Test 080: OUT inside subroutine after ADD
.org 0x10
LDM R0, 0x5
CALL SUB
MOV R2, R1
HLT
SUB:
IADD R1, R0, 0xA
OUT R1
RET
