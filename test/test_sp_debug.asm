; Minimal SP test - just STD to see if SP changes
.org 2
LDM R0, 0x100
LDM R1, 0xCAFE
STD R1, 0x10(R0)
HLT
