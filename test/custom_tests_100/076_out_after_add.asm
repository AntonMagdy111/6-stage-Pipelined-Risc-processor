; Test 076: OUT after ADD; registers also verify ADD result
.org 0x10
LDM R0, 0x4
LDM R1, 0x6
ADD R2, R0, R1
OUT R2
MOV R3, R2
HLT
