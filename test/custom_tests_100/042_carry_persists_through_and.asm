; Test 042: AND should not clear carry; JC should still be taken after SETC then AND
.org 0x10
SETC
LDM R0, 0xF0
LDM R1, 0x0F
AND R2, R0, R1
JC TARGET
LDM R3, 0xBAD
TARGET:
LDM R4, 0x7777
HLT
