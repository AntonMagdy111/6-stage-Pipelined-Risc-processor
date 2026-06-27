; Test 058: LDD followed by NOP before dependent ADD
.org 0x10
LDM R0, 0x1D0
LDM R1, 0x21
STD R1, 0x0(R0)
LDD R2, 0x0(R0)
NOP
ADD R3, R2, R2
HLT
