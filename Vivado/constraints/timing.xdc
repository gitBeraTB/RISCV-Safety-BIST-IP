## ============================================================================
## RISC-V BIST IP — Xilinx Vivado Timing & Pin Constraints
## Target: Artix-7 (xc7a35tcpg236-1) @ 100 MHz
## Top Module: fpga_top
## ============================================================================

## ----------------------------------------------------------------------------
## Clock Definition (100 MHz)
## ----------------------------------------------------------------------------
create_clock -name sys_clk -period 10.000 [get_ports clk_i]

## ----------------------------------------------------------------------------
## Clock Uncertainty
## ----------------------------------------------------------------------------
set_clock_uncertainty -setup 0.100 [get_clocks sys_clk]
set_clock_uncertainty -hold  0.050 [get_clocks sys_clk]

## ----------------------------------------------------------------------------
## False Paths (Async Reset & Switches)
## ----------------------------------------------------------------------------
set_false_path -from [get_ports rst_ni]
set_false_path -from [get_ports {sw_i[*]}]
set_false_path -from [get_ports {btn_i[*]}]

## ----------------------------------------------------------------------------
## Input Delay Constraints
## ----------------------------------------------------------------------------
set_input_delay -clock sys_clk -max 3.000 [get_ports {sw_i[*] btn_i[*]}]
set_input_delay -clock sys_clk -min 0.500 [get_ports {sw_i[*] btn_i[*]}]

## ----------------------------------------------------------------------------
## Output Delay Constraints
## ----------------------------------------------------------------------------
set_output_delay -clock sys_clk -max 3.000 [get_ports {led_o[*] led_result_o[*]}]
set_output_delay -clock sys_clk -min 0.500 [get_ports {led_o[*] led_result_o[*]}]

## ============================================================================
## NOTE: Pin assignments below are for Basys3 board.
## Comment out or modify for other boards.
## ============================================================================

## Clock (Basys3: 100 MHz oscillator on W5)
# set_property -dict { PACKAGE_PIN W5  IOSTANDARD LVCMOS33 } [get_ports clk_i]

## Reset (Basys3: Center button)
# set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } [get_ports rst_ni]

## Switches (Basys3: SW0-SW3)
# set_property -dict { PACKAGE_PIN V17 IOSTANDARD LVCMOS33 } [get_ports {sw_i[0]}]
# set_property -dict { PACKAGE_PIN V16 IOSTANDARD LVCMOS33 } [get_ports {sw_i[1]}]
# set_property -dict { PACKAGE_PIN W16 IOSTANDARD LVCMOS33 } [get_ports {sw_i[2]}]
# set_property -dict { PACKAGE_PIN W17 IOSTANDARD LVCMOS33 } [get_ports {sw_i[3]}]

## Buttons (Basys3: BTNU, BTNL, BTNR, BTND)
# set_property -dict { PACKAGE_PIN T18 IOSTANDARD LVCMOS33 } [get_ports {btn_i[0]}]
# set_property -dict { PACKAGE_PIN W19 IOSTANDARD LVCMOS33 } [get_ports {btn_i[1]}]
# set_property -dict { PACKAGE_PIN T17 IOSTANDARD LVCMOS33 } [get_ports {btn_i[2]}]
# set_property -dict { PACKAGE_PIN U17 IOSTANDARD LVCMOS33 } [get_ports {btn_i[3]}]

## Status LEDs (Basys3: LD12-LD15)
# set_property -dict { PACKAGE_PIN L1  IOSTANDARD LVCMOS33 } [get_ports {led_o[0]}]
# set_property -dict { PACKAGE_PIN P1  IOSTANDARD LVCMOS33 } [get_ports {led_o[1]}]
# set_property -dict { PACKAGE_PIN N3  IOSTANDARD LVCMOS33 } [get_ports {led_o[2]}]
# set_property -dict { PACKAGE_PIN P3  IOSTANDARD LVCMOS33 } [get_ports {led_o[3]}]

## Result LEDs (Basys3: LD0-LD7)
# set_property -dict { PACKAGE_PIN U16 IOSTANDARD LVCMOS33 } [get_ports {led_result_o[0]}]
# set_property -dict { PACKAGE_PIN E19 IOSTANDARD LVCMOS33 } [get_ports {led_result_o[1]}]
# set_property -dict { PACKAGE_PIN U19 IOSTANDARD LVCMOS33 } [get_ports {led_result_o[2]}]
# set_property -dict { PACKAGE_PIN V19 IOSTANDARD LVCMOS33 } [get_ports {led_result_o[3]}]
# set_property -dict { PACKAGE_PIN W18 IOSTANDARD LVCMOS33 } [get_ports {led_result_o[4]}]
# set_property -dict { PACKAGE_PIN U15 IOSTANDARD LVCMOS33 } [get_ports {led_result_o[5]}]
# set_property -dict { PACKAGE_PIN U14 IOSTANDARD LVCMOS33 } [get_ports {led_result_o[6]}]
# set_property -dict { PACKAGE_PIN V14 IOSTANDARD LVCMOS33 } [get_ports {led_result_o[7]}]
