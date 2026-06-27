; test_hazards.asm
; Tests RAW hazards - these stress the forwarding unit and stall logic.
; Without forwarding, all results below would be WRONG.

.org 2
START:
    ; -----------------------------------------------
    ; TEST 1: EX->EX forwarding (1 instr gap)
    ; ADD produces R1, next instr immediately uses R1
    ; Without forwarding: R2 = old_R1 + 5 (wrong)
    ; With forwarding:    R2 = 8 + 5 = 13 (correct)
    ; -----------------------------------------------
    LDM   R0, #8
    ADD   R1, R0, R0    ; R1 = 16... wait, use simpler
    LDM   R0, #8
    LDM   R3, #5
    ADD   R1, R0, R3    ; R1 = 13
    ADD   R2, R1, R3    ; R2 = R1 + 5 = 18  <-- R1 must be forwarded from EX1/EX2

    ; -----------------------------------------------
    ; TEST 2: EX->EX forwarding chain (back-to-back)
    ; Each result immediately feeds the next
    ; -----------------------------------------------
    LDM   R0, #1
    INC   R0            ; R0 = 2
    INC   R0            ; R0 = 3  <-- must forward R0 from previous INC
    INC   R0            ; R0 = 4  <-- must forward again
    ; R0 should be 4

    ; -----------------------------------------------
    ; TEST 3: MEM->EX forwarding (2 instr gap)
    ; Result is 2 instructions ahead
    ; -----------------------------------------------
    LDM   R4, #100
    LDM   R5, #7
    ADD   R6, R4, R5    ; R6 = 107
    NOP                 ; gap
    ADD   R7, R6, R5    ; R7 = 107 + 7 = 114  <-- R6 from EX2/MEM

    ; -----------------------------------------------
    ; TEST 4: Load-use stall
    ; LDD produces R1 in MEM stage. Next instr
    ; needs R1 in EX1. Must stall 1 cycle.
    ; -----------------------------------------------
    LDM   R0, #200      ; base address
    LDM   R1, #0xABCD
    STD   R1, 0(R0)     ; store 0xABCD at M[200]
    LDD   R1, 0(R0)     ; R1 = M[200] = 0xABCD
    ADD   R2, R1, R1    ; R2 = 0xABCD + 0xABCD = 0x1579A
                        ; WITHOUT stall: R2 uses stale R1 (wrong)
                        ; WITH stall: R2 = 0x1579A (correct)

    ; -----------------------------------------------
    ; TEST 5: Branch NOT taken (fall-through)
    ; Z is 0, JZ should NOT jump
    ; -----------------------------------------------
    LDM   R0, #5
    LDM   R1, #3
    SUB   R3, R0, R1    ; R3 = 2, Z = 0
    JZ    WRONG         ; should NOT jump (Z=0)
    LDM   R4, #0x1111   ; should reach here
    JMP   DONE

WRONG:
    LDM   R4, #0xDEAD   ; should be skipped

DONE:
    HLT
; Expected final state:
;   R0 = 200
;   R2 = 8  (from TEST 1: ADD R1=13, wait...recalc below)
;   R2 after TEST1 = 18, then overwritten by TEST4 = 0x1579A
;   R4 = 0x1111 (branch NOT taken, fell through)
