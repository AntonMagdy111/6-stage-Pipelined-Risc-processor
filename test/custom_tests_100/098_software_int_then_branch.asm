; Test 098: Return from INT then execute branch correctly
.org 0x10
LDM R0, 0x0
INT 0
SUB R1, R1, R1
JZ DONE
LDM R7, 0xBAD
DONE:
LDM R2, 0x2222
HLT
.org 0x2
.WORD H0
.WORD H1
.org 0x280
H0:
LDM R5, 0x5555
RTI
.org 0x290
H1:
LDM R6, 0x6666
RTI
