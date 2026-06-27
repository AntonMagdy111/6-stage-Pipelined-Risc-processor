; Test 050: JMP must flush a skipped two-word LDM instruction
.org 0x10
JMP TARGET
LDM R0, 0xBAD
TARGET:
LDM R1, 0x1111
HLT
