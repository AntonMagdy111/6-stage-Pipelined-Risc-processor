; Test 099: HLT should freeze CPU before following instruction executes
.org 0x10
LDM R0, 0x1111
HLT
LDM R0, 0x0BAD
