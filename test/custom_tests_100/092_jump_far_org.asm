; Test 092: Jump to far .ORG address
.org 0x10
JMP FAR
LDM R0, 0xBAD
.org 0x350
FAR:
LDM R1, 0x350
HLT
