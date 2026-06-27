; Test 032: INC FFFFFFFF should wrap to zero and set carry/zero
.org 0x10
LDM R0, 0xFFFFFFFF
INC R0
MOV R1, R0
HLT
