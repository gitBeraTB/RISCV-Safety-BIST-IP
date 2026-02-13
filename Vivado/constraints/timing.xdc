## ============================================================================
## RISC-V BIST IP — Xilinx Vivado Timing Constraints
## Target: Artix-7 (xc7a35tcpg236-1) @ 100 MHz
## ============================================================================

## ----------------------------------------------------------------------------
## Clock Definition
## ----------------------------------------------------------------------------
create_clock -name sys_clk -period 10.000 [get_ports clk_i]

## ----------------------------------------------------------------------------
## Input Delay Constraints
## Assume all inputs arrive within 3ns of clock edge
## ----------------------------------------------------------------------------
set_input_delay -clock sys_clk -max 3.000 [get_ports -filter {DIRECTION == IN && NAME != "clk_i"}]
set_input_delay -clock sys_clk -min 0.500 [get_ports -filter {DIRECTION == IN && NAME != "clk_i"}]

## ----------------------------------------------------------------------------
## Output Delay Constraints
## Assume all outputs must be stable 3ns before next clock edge
## ----------------------------------------------------------------------------
set_output_delay -clock sys_clk -max 3.000 [get_ports -filter {DIRECTION == OUT}]
set_output_delay -clock sys_clk -min 0.500 [get_ports -filter {DIRECTION == OUT}]

## ----------------------------------------------------------------------------
## Clock Uncertainty
## ----------------------------------------------------------------------------
set_clock_uncertainty -setup 0.100 [get_clocks sys_clk]
set_clock_uncertainty -hold  0.050 [get_clocks sys_clk]

## ----------------------------------------------------------------------------
## False Paths (Async Reset)
## ----------------------------------------------------------------------------
set_false_path -from [get_ports rst_ni]

## ----------------------------------------------------------------------------
## Max Fanout Constraint
## ----------------------------------------------------------------------------
set_property MAX_FANOUT 50 [get_ports clk_i]
