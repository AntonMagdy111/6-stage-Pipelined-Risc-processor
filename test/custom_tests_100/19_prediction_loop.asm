; Checks repeated taken JN then final not-taken; good for branch predictor/flush.
.org 0x10
LDM R0, 0x0
LDM R1, 0x5
LOOP:
IADD R0, R0, 0x1
SUB R3, R0, R1
JN LOOP
HLT
