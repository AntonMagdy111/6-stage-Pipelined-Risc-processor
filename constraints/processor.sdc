# ---------------------------------------------------------------------------
# processor.sdc — Synopsys Design Constraints (SDC) for 6-Stage RISC Processor
# Target: Single-edge rising-clock synchronous pipeline (100 MHz nominal, 10 ns)
# Compatible with Siemens Precision RTL, Synopsys DC/PrimeTime, Intel Quartus,
# and Xilinx Vivado.
# ---------------------------------------------------------------------------

# Primary system clock (100 MHz -> 10.0 ns period, 50% duty cycle)
create_clock -name sys_clk -period 10.000 -waveform {0.000 5.000} [get_ports clk]

# Clock uncertainty (jitter + skew budget for setup/hold margin)
set_clock_uncertainty -setup 0.300 [get_clocks sys_clk]
set_clock_uncertainty -hold  0.100 [get_clocks sys_clk]

# External I/O timing budgets (20% of clock period external delay)
set_input_delay  -clock sys_clk -max 2.000 [get_ports {in_port[*] intr}]
set_input_delay  -clock sys_clk -min 0.500 [get_ports {in_port[*] intr}]

set_output_delay -clock sys_clk -max 2.000 [get_ports {out_port[*] in_en_obs}]
set_output_delay -clock sys_clk -min 0.500 [get_ports {out_port[*] in_en_obs}]

# Observation / debug ports (non-functional testbench taps)
set_false_path -to [get_ports {pc_obs[*] sp_obs[*] ccr_obs[*] r0_obs[*] r1_obs[*] r2_obs[*] r3_obs[*] r4_obs[*] r5_obs[*] r6_obs[*] r7_obs[*]}]

# Asynchronous/global reset recovery path (rst is held >= 2 cycles externally)
set_false_path -from [get_ports rst]

# ---------------------------------------------------------------------------
# Critical Path Notes (see docs/REPORT.md Section 2.3):
#   Dominant path: U_E2M (EX2/MEM) -> U_MEM (combinational d_out) ->
#                  U_MEMS (mem_wb_data) -> U_EX1 (7:1 fwd mux + 32-bit ALU) ->
#                  U_EX12 setup.
#   Because all sequential blocks (RegisterFile, Memory, PC, Pipeline Regs)
#   use rising_edge(clk) exclusively, there are ZERO half-cycle paths.
# ---------------------------------------------------------------------------
