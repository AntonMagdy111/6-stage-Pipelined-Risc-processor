; Test 071: CALL while user stack data already exists
.org 0x10
LDM R0, 0xAAAA
PUSH R0
CALL SUB
POP R1
HLT
SUB:
LDM R2, 0x2222
RET
