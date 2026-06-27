; Test 030: NOT of mixed bit pattern
.org 0x10
LDM R0, 0x00FF00FF
NOT R0
MOV R1, R0
HLT
