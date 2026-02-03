# -----------------------------------------------------------------------------
# COCOTB MAKEFILE FOR RISC-V IBEX EX_BLOCK
# -----------------------------------------------------------------------------

# Simulator setup
SIM ?= icarus
TOPLEVEL_LANG ?= verilog

# HDL Klasörünün Yolu
HDL_DIR = $(PWD)/../HDL

# -----------------------------------------------------------------------------
# SIMULATION SETTINGS (CRITICAL FIX)
# -----------------------------------------------------------------------------

# Icarus Verilog'a include dosyalarını (prim_assert.sv gibi) 
# HDL klasöründe aramasını söylüyoruz:
EXTRA_ARGS += -I$(HDL_DIR) -g2012

# -----------------------------------------------------------------------------
# SOURCE FILES
# -----------------------------------------------------------------------------

# 1. Packages
VERILOG_SOURCES += $(HDL_DIR)/prim_mubi_pkg.sv
VERILOG_SOURCES += $(HDL_DIR)/edn_pkg.sv
VERILOG_SOURCES += $(HDL_DIR)/top_racl_pkg.sv
VERILOG_SOURCES += $(HDL_DIR)/flash_ctrl_top_specific_pkg.sv
VERILOG_SOURCES += $(HDL_DIR)/ibex_pkg.sv

# 2. Sub-modules
VERILOG_SOURCES += $(HDL_DIR)/ibex_alu.sv
VERILOG_SOURCES += $(HDL_DIR)/ibex_multdiv_fast.sv

# 3. Wrapper
VERILOG_SOURCES += $(HDL_DIR)/ibex_alu_bist_wrapper.sv

# 4. Top Module
VERILOG_SOURCES += $(HDL_DIR)/ibex_ex_block.sv

# -----------------------------------------------------------------------------
# CONFIGURATION
# -----------------------------------------------------------------------------

TOPLEVEL = ibex_ex_block
MODULE = test_ibex_RISC-V

include $(shell cocotb-config --makefiles)/Makefile.sim