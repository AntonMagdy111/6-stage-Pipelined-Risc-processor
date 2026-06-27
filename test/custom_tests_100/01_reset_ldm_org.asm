; 01_reset_ldm_org.asm
; Checks reset vector through .ORG and immediate loading.
.org 0x20
LDM R0, 0x1111
LDM R1, 0x2222
LDM R2, 0x3333
HLT
