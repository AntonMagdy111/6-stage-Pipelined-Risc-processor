; Test 060: Single PUSH then POP restores SP and value
.org 0x10
LDM R0, 0xAAAA
PUSH R0
POP R1
HLT
