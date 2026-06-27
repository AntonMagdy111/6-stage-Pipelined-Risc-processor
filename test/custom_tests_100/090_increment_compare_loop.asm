; Test 090: Loop increments R0 until equal to R1
.org 0x10
LDM R0, 0x0
LDM R1, 0x4
LOOP:
INC R0
SUB R2, R0, R1
JZ DONE
JMP LOOP
DONE:
MOV R3, R0
HLT
