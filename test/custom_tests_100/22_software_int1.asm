; Checks software INT 1: PC should jump to M[3], then RTI returns.
; This is likely to expose the current INT-index bug.
.org 0x10
LDM R0, 0x1111
INT 1
LDM R1, 0x2222
HLT
.org 0x2
.WORD HANDLER0
.WORD HANDLER1
.org 0x80
HANDLER0:
LDM R5, 0x5555
RTI
.org 0x90
HANDLER1:
LDM R6, 0x6666
RTI
