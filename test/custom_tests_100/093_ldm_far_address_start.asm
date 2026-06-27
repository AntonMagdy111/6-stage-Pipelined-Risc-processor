; Test 093: Program starts at high .ORG using reset vector
.org 0x300
LDM R0, 0x300
LDM R1, 0x1234
HLT
