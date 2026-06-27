; Checks EX/MEM/WB forwarding through a dependency chain.
.org 0x10
LDM R0, 0x1
IADD R1, R0, 0x1
ADD R2, R1, R1
ADD R3, R2, R1
IADD R4, R3, 0x1
HLT
