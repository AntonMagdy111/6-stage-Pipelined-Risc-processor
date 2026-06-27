; Test 075: IN then immediate MOV dependency
.org 0x10
IN R0
MOV R1, R0
HLT
