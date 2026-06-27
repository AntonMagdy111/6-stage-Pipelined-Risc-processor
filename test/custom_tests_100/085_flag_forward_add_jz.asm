; Test 085: ADD zero result followed immediately by JZ
.org 0x10
LDM R0, 0xFFFFFFFF
LDM R1, 0x1
ADD R2, R0, R1
JZ TARGET
LDM R3, 0xBAD
TARGET:
LDM R4, 0x4444
HLT
