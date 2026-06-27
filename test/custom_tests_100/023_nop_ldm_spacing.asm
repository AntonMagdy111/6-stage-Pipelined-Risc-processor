; Test 023: NOP should not change registers; LDM after NOPs should still execute
.org 0x10
NOP
NOP
LDM R0, 0x1234
NOP
LDM R1, 0x5678
HLT
