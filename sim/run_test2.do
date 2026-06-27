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

vsim -t 1ns work.tb_Processor \
  -gEXP_R0=16#00000000 \
  -gEXP_R1=16#000000B5 \
  -gEXP_R2=16#00000030 \
  -gEXP_R3=16#00000300 \
  -gEXP_R4=16#00000100 \
  -gEXP_R5=16#FFFFFFFF \
  -gEXP_R6=16#00000601 \
  -gEXP_R7=16#00000085 \
  -gEXP_SP=16#00000FFF \
  -gIN_COUNT=7 \
  -gIN_VAL0=16#00000050 \
  -gIN_VAL1=16#00000030 \
  -gIN_VAL2=16#00000300 \
  -gIN_VAL3=16#00000100 \
  -gIN_VAL4=16#00000055 \
  -gIN_VAL5=16#00000075 \
  -gIN_VAL6=16#00000700

run 6000ns
