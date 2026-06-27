; Test 081: Long dependent arithmetic chain
.org 0x10
LDM R0, 0x1
IADD R0, R0, 0x1
IADD R0, R0, 0x1
IADD R0, R0, 0x1
IADD R1, R0, 0x1
ADD R2, R1, R0
ADD R3, R2, R1
HLT
