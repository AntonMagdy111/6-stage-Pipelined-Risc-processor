; Test 057: Loaded value used later in ADD
.org 0x10
LDM R0, 0x1C0
LDM R1, 0x10
STD R1, 0x2(R0)
LDD R2, 0x2(R0)
ADD R3, R2, R1
HLT
