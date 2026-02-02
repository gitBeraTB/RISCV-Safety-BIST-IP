# Simulator language
TOPLEVEL_LANG ?= verilog


VERILOG_SOURCES += $(PWD)/../HDL/ibex_src/ibex_pkg.sv
VERILOG_SOURCES += $(PWD)/../HDL/ibex_src/ibex_alu.sv

# 2. Bizim BIST Modüllerimiz
VERILOG_SOURCES += $(PWD)/../HDL/lfsr_gen.sv
VERILOG_SOURCES += $(PWD)/../HDL/misr_analyzer.sv
VERILOG_SOURCES += $(PWD)/../HDL/idle_detector.sv
VERILOG_SOURCES += $(PWD)/../HDL/apb_slave_if.sv
VERILOG_SOURCES += $(PWD)/../HDL/runtime_bist_controller.sv

# 3. Top Level Wrapper (Bu değişmedi)
VERILOG_SOURCES += $(PWD)/../HDL/ibex_alu_bist_wrapper.sv

# Top level module name
TOPLEVEL = ibex_alu_bist_wrapper

# Python test module name
COCOTB_TEST_MODULES = tb_ibex_wrapper

# Simulator
SIM ?= icarus

# Include Cocotb makefiles
include $(shell cocotb-config --makefiles)/Makefile.sim