; Test 064: POP result immediately used by ADD
.org 0x10
LDM R0, 0x10
PUSH R0
POP R1
ADD R2, R1, R1
HLT
