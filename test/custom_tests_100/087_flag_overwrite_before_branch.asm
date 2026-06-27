; Test 087: Second ALU op overwrites flags before JZ
.org 0x10
SUB R0, R0, R0
INC R1
JZ TARGET
LDM R2, 0x2222
JMP DONE
TARGET:
LDM R2, 0xBAD
DONE:
HLT
