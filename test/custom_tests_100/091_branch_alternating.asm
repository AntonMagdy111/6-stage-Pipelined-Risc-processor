; Test 091: Taken then not-taken branches stress predictor state
.org 0x10
SUB R0, R0, R0
JZ T1
LDM R7, 0xBAD
T1:
INC R0
JZ BAD
LDM R1, 0x1111
JMP DONE
BAD:
LDM R7, 0xBAD
DONE:
HLT
