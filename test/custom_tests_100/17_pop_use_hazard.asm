; Checks POP followed immediately by dependent ADD.
.org 0x10
LDM R0, 0x11
PUSH R0
POP R1
ADD R2, R1, R1
HLT
