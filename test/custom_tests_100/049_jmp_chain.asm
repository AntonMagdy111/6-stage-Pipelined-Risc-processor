; Test 049: Multiple jumps to labels
.org 0x10
JMP A
LDM R0, 0xBAD
A:
JMP B
LDM R1, 0xBAD
B:
LDM R2, 0x2222
HLT
