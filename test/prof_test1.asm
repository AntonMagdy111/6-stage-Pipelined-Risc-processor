; Professor test1
; IN port should be set to 0xFFFFFFFF in testbench before running
.org 2
LDM R0, 0x1
LDM R1, 0xAAAA
LDM R2, 0xFFFF
INC R0
MOV R4, R1
NOT R1
MOV R3, R0
IN R0
OUT R0
AND R5, R1, R0
MOV R6, R0
NOT R6
INC R0
HLT
