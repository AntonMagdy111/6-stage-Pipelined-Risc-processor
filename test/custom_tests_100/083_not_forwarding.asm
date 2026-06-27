; Test 083: NOT result immediately used by AND
.org 0x10
LDM R0, 0x0F0F
NOT R0
LDM R1, 0xFFFF
AND R2, R0, R1
HLT
