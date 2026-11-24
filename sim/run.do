# ==========================================================================
# Project : 6-Stage Pipelined 32-Bit Von Neumann RISC Processor
# Author  : Anton Magdy (@AntonMagdy111) - https://github.com/AntonMagdy111
# Repo    : https://github.com/AntonMagdy111/6-stage-Pipelined-Risc-processor
# License : Apache-2.0 (see LICENSE and NOTICE for mandatory attribution)
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 Anton Magdy. All rights reserved.
# ==========================================================================
# run.do -- ModelSim simulation script
# -----------------------------------------------------------------------
# HOW TO USE:
#   1. Copy the test you want into program.mem:
#        e.g.  copy ..\test\test_memory.mem program.mem
#   2. In the do-file below, uncomment ONE vsim block matching that test
#      (comment out all others)
#   3. In ModelSim transcript:
#        do run.do
# -----------------------------------------------------------------------

puts {============================================================}
puts {6-Stage Pipelined 32-Bit Von Neumann RISC Processor}
puts {Designed by Anton Magdy (@AntonMagdy111) (Apache-2.0)}
puts {============================================================}

if {[file isdirectory work]} { vdel -lib work -all }
vlib work
vmap work work

vcom -2008 ../components/cpu_pkg.vhd
vcom -2008 ../components/alu.vhd
vcom -2008 ../components/RegisterFile.vhd
vcom -2008 ../components/Memory.vhd
vcom -2008 ../components/controlUnit.vhd
vcom -2008 ../components/pc.vhd
vcom -2008 ../components/sp.vhd
vcom -2008 ../components/CCR.vhd
vcom -2008 ../components/forwardingUnit.vhd
vcom -2008 ../components/hazardDetectionUnit.vhd
vcom -2008 ../components/outPutReg.vhd
vcom -2008 ../components/branchPredictor.vhd
vcom -2008 ../components/Pipelined_Registers/IF_ID.vhd
vcom -2008 ../components/Pipelined_Registers/ID_EX1.vhd
vcom -2008 ../components/Pipelined_Registers/EX1_EX2.vhd
vcom -2008 ../components/Pipelined_Registers/EX2_MEM.vhd
vcom -2008 ../components/Pipelined_Registers/MEM_WB.vhd
vcom -2008 ../stages/fetchStage.vhd
vcom -2008 ../stages/decodeStage.vhd
vcom -2008 ../stages/execute1Stage.vhd
vcom -2008 ../stages/execute2Stage.vhd
vcom -2008 ../stages/memoryStage.vhd
vcom -2008 ../stages/writeBackStage.vhd
vcom -2008 ../Processor.vhd
vcom -2008 ../tb_Processor.vhd

# -----------------------------------------------------------------------
# PICK ONE TEST — uncomment the matching vsim block, comment the rest
# -----------------------------------------------------------------------

# === TEST 1: test_arithmetic ===
# Instructions: NOP SETC NOT INC MOV SWAP ADD SUB AND IADD LDM
file copy -force "../test/test_arithmetic.mem" "program.mem"
vsim -t 1ns work.tb_Processor \
  -gEXP_R0=16#0000BEEF -gEXP_R1=16#00000008 \
  -gEXP_R2=16#00000001 -gEXP_R3=16#00000002 \
  -gEXP_R4=16#FFFFFFFA -gEXP_R5=16#00000006 \
  -gEXP_R6=16#0000000F -gEXP_R7=16#00000005 \
  -gEXP_SP=16#00000FFF

# === TEST 2: test_memory ===
# Instructions: LDM LDD STD PUSH POP
# copy ..\test\test_memory.mem program.mem  then uncomment:
# vsim -t 1ns work.tb_Processor \
#   -gEXP_R0=16#0000CAFE -gEXP_R1=16#00000064 \
#   -gEXP_R2=16#0000CAFE -gEXP_R3=16#0000CAFE \
#   -gEXP_R4=16#000000AA -gEXP_R5=16#000000BB \
#   -gEXP_R6=16#000000BB -gEXP_R7=16#000000AA \
#   -gEXP_SP=16#00000FFF

# === TEST 3: test_branches ===
# Instructions: JZ JN JC JMP CALL RET
# copy ..\test\test_branches.mem program.mem  then uncomment:
# vsim -t 1ns work.tb_Processor \
#   -gEXP_R0=16#0000ABCD -gEXP_R1=16#00001111 \
#   -gEXP_R2=16#00000000 -gEXP_R3=16#FFFFFFFF \
#   -gEXP_R4=16#00000000 -gEXP_R5=16#0000CCCC \
#   -gEXP_R6=16#0000BBBB -gEXP_R7=16#0000AAAA \
#   -gEXP_SP=16#00000FFF

# === TEST 4: test_io ===
# Instructions: IN OUT SETC NOP HLT
# copy ..\test\test_io.mem program.mem  then uncomment:
# vsim -t 1ns work.tb_Processor \
#   -gEXP_R0=16#00001234 -gEXP_R1=16#0000FEED \
#   -gEXP_R2=16#00000000 -gEXP_R3=16#00000000 \
#   -gEXP_R4=16#00000000 -gEXP_R5=16#00000000 \
#   -gEXP_R6=16#00000000 -gEXP_R7=16#00000000 \
#   -gEXP_SP=16#00000FFF -gCHECK_OUT=true -gEXP_OUT=16#0000FEED

# === TEST 5: test_interrupts ===
# Instructions: INT RTI
# copy ..\test\test_interrupts.mem program.mem  then uncomment:
# vsim -t 1ns work.tb_Processor \
#   -gEXP_R0=16#00001111 -gEXP_R1=16#00002222 \
#   -gEXP_R2=16#00003333 -gEXP_R3=16#00000000 \
#   -gEXP_R4=16#00000000 -gEXP_R5=16#00009999 \
#   -gEXP_R6=16#00000000 -gEXP_R7=16#00000000 \
#   -gEXP_SP=16#00000FFF

# === TEST 6: test_hazards ===
# Tests: EX->EX forwarding, MEM->EX forwarding, load-use stall, branch not-taken
# copy ..\test\test_hazards.mem program.mem  then uncomment:
# vsim -t 1ns work.tb_Processor \
#   -gEXP_R0=16#00000005 -gEXP_R1=16#00000003 \
#   -gEXP_R2=16#0001579A -gEXP_R3=16#00000002 \
#   -gEXP_R4=16#00001111 -gEXP_R5=16#00000007 \
#   -gEXP_R6=16#0000006B -gEXP_R7=16#00000072 \
#   -gEXP_SP=16#00000FFF

# === TEST 7: test_edgecases ===
# Tests: INC overflow, NOT of 0, SUB=0, branch not-taken, nested CALL
# copy ..\test\test_edgecases.mem program.mem  then uncomment:
# vsim -t 1ns work.tb_Processor \
#   -gEXP_R0=16#0000AAAA -gEXP_R1=16#0000BBBB \
#   -gEXP_R2=16#0000CCCC -gEXP_R3=16#00002222 \
#   -gEXP_R4=16#00003333 -gEXP_R5=16#00004444 \
#   -gEXP_R6=16#00005555 -gEXP_R7=16#00000000 \
#   -gEXP_SP=16#00000FFF

# -----------------------------------------------------------------------
# Wave window (GUI mode) & simulation run
# -----------------------------------------------------------------------
if {![batch_mode]} {
    delete wave *
    add wave -divider "Clock and reset"
    add wave -radix binary   /tb_Processor/clk
    add wave -radix binary   /tb_Processor/rst
    add wave -radix binary   /tb_Processor/intr
    add wave -divider "Architectural state"
    add wave -radix unsigned /tb_Processor/pc
    add wave -radix unsigned /tb_Processor/sp
    add wave -radix binary   /tb_Processor/ccr
    add wave -divider "Registers R0-R7"
    add wave -radix hex /tb_Processor/r0
    add wave -radix hex /tb_Processor/r1
    add wave -radix hex /tb_Processor/r2
    add wave -radix hex /tb_Processor/r3
    add wave -radix hex /tb_Processor/r4
    add wave -radix hex /tb_Processor/r5
    add wave -radix hex /tb_Processor/r6
    add wave -radix hex /tb_Processor/r7
    add wave -divider "I/O"
    add wave -radix hex      /tb_Processor/in_port
    add wave -radix binary   /tb_Processor/in_en_obs
    add wave -radix hex      /tb_Processor/out_port
    add wave -divider "Pipeline & Hazards"
    add wave -radix binary   /tb_Processor/U_DUT/ifid_valid
    add wave -radix hex      /tb_Processor/U_DUT/ifid_ir
    add wave -radix binary   /tb_Processor/U_DUT/idex1_valid
    add wave -radix binary   /tb_Processor/U_DUT/ex12_valid
    add wave -radix binary   /tb_Processor/U_DUT/e2m_valid
    add wave -radix binary   /tb_Processor/U_DUT/mw_valid
    add wave -radix binary   /tb_Processor/U_DUT/hz_stall
    add wave -radix binary   /tb_Processor/U_DUT/flush_front
    add wave -radix binary   /tb_Processor/U_DUT/halt_latch
    add wave -divider "Forwarding & Branch Predictor"
    add wave -radix binary   /tb_Processor/U_DUT/fwd_sel_a
    add wave -radix binary   /tb_Processor/U_DUT/fwd_sel_b
    add wave -radix binary   /tb_Processor/U_DUT/fwd_sel_store
    add wave -radix binary   /tb_Processor/U_DUT/if_pred_taken
    add wave -radix binary   /tb_Processor/U_DUT/ex2_misp_gated
    add wave -radix hex      /tb_Processor/U_DUT/redirect_pc
}

run 6000 ns
if {![batch_mode]} {
    wave zoom full
}
