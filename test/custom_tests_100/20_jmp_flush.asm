; Checks unconditional JMP flushes wrong-path instructions.
.org 0x10
LDM R0, 0x1
JMP TARGET
LDM R0, 0xBAD
LDM R7, 0xBAD
TARGET:
IADD R0, R0, 0x1
HLT
