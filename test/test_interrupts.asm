; test_interrupts.asm
; Verifies: INT, RTI

; INT 1 -> PC <- M[1+2] = M[3]. Put HANDLER address there.
.org 3
    .word HANDLER

.org 10
.start 10
START:
    LDM   R0, #0x1111
    LDM   R1, #0x2222
    INT   1               ; jump to address held in M[3]
    LDM   R5, #0x9999     ; after RTI returns here
    HLT

HANDLER:
    LDM   R2, #0x3333
    RTI                   ; pop PC
