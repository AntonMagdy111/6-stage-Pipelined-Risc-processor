; Test 078: IN after taken branch only
.org 0x10
SUB R0, R0, R0
JZ TARGET
IN R1
TARGET:
IN R2
HLT
