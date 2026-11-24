; Professor Test 2 - with NOPs between IN instructions for reliable timing

.org 2
.word 0x900
.start 0x10

.org 0x10
IN R1            ; R1=0x50
NOP
NOP
NOP
NOP
IN R2            ; R2=0x30
NOP
NOP
NOP
NOP
IN R3            ; R3=0x300
NOP
NOP
NOP
NOP
IN R4            ; R4=0x100
PUSH R3          ; SP=FFE, M[FFF]=0x300
JMP 0x30

.org 0x30
AND R5, R1, R5   ; R5=0, Z=1
JZ  0x50

.org 0x50
JZ 0x30          ; NOT taken
NOT R5           ; R5=0xFFFFFFFF, N=1
SUB R6, R5, R5   ; R6=0, Z=1
IN R1            ; R1=0x55
JZ 0x60

.org 0x60
IN R1            ; R1=0x75
JZ 0x70          ; NOT taken
JMP 0x70

.org 0x70
IADD R1, R1, 0x10
SUB R7, R1, R1   ; Z=1
PUSH R1
POP R1
JZ 0x80

.org 0x80
IN R6            ; R6=0x700
JMP 0x700

.org 0x700
ADD R7, R0, R1
POP R6           ; R6=0x300, SP=FFF
CALL 0x300
INC R6
NOP
NOP
HLT

.org 0x300
ADD R6, R3, R6
ADD R1, R1, R2
RET

.org 0x900
IN R7
AND R0, R0, R0
OUT R7
RTI
