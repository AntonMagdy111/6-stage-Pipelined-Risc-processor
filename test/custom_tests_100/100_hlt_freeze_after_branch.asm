; Test 100: HLT reached after jump should freeze before later code
.org 0x10
JMP STOP
LDM R0, 0xBAD
STOP:
LDM R1, 0x2222
HLT
LDM R1, 0x0BAD
