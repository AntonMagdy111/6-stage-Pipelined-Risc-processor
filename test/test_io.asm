; test_io.asm
; Verifies: IN, OUT, SETC, NOP, HLT

.org 2
START:
    NOP
    SETC                 ; C = 1
    IN    R0             ; R0 <- IN.PORT (testbench will drive 0x1234)
    OUT   R0             ; OUT.PORT = 0x1234
    LDM   R1, #0xFEED
    OUT   R1             ; OUT.PORT = 0xFEED
    HLT
