# run_failing.do -- Standalone single-test debug script (028_swap_then_add)
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
vcom -2008 tb_Processor_100.vhd

file copy -force "../test/custom_tests_100/028_swap_then_add.mem" "program.mem"
vsim -t 1ns work.tb_Processor_100 \
  -gTEST_NAME=028_swap_then_add.asm \
  -gEXP_R0=16#00000005 -gEXP_R1=16#0000000A \
  -gEXP_R2=16#0000000F -gEXP_R3=16#00000000 \
  -gEXP_R4=16#00000000 -gEXP_R5=16#00000000 \
  -gEXP_R6=16#00000000 -gEXP_R7=16#00000000 \
  -gEXP_SP=16#00000FFF -gCHECK_AT=5000ns
run 6000ns
