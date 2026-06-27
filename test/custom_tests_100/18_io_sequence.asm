; Checks multiple IN values and OUT datapath. Use IN values: 5, 7, 3.
.org 0x10
IN R0
IN R1
ADD R2, R0, R1
OUT R2
IN R3
ADD R4, R2, R3
OUT R4
HLT
