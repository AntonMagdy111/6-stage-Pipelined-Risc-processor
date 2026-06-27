; Test 089: Loop decrements R0 from 3 to 0 using JZ/JMP
.org 0x10
LDM R0, 0x3
LDM R1, 0x1
LOOP:
SUB R2, R0, R1
MOV R0, R2
JZ DONE
JMP LOOP
DONE:
LDM R3, 0xD00E
HLT
