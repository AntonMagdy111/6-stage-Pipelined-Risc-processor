; Test 077: Four IN values accumulated
.org 0x10
IN R0
IN R1
IN R2
IN R3
ADD R4, R0, R1
ADD R5, R2, R3
ADD R6, R4, R5
HLT
