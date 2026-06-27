; Test 096: Software INT 0 jumps through M[2] then RTI returns
.org 0x10
LDM R0, 0x1111
INT 0
LDM R1, 0x2222
HLT
.org 0x2
.WORD H0
.WORD H1
.org 0x280
H0:
LDM R5, 0xAAAA
RTI
.org 0x290
H1:
LDM R6, 0xBBBB
RTI
