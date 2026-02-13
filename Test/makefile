# =============================================================================
# UNIFIED COCOTB MAKEFILE — RISC-V Safety BIST IP
# Per-module and integration test targets
# =============================================================================

SIM ?= icarus
TOPLEVEL_LANG ?= verilog
HDL_DIR = $(PWD)/../HDL
TS = $(PWD)/timescale.v

# Packages (needed by most modules)
PKGS = $(HDL_DIR)/prim_mubi_pkg.sv \
       $(HDL_DIR)/edn_pkg.sv \
       $(HDL_DIR)/top_racl_pkg.sv \
       $(HDL_DIR)/flash_ctrl_top_specific_pkg.sv \
       $(HDL_DIR)/ibex_pkg.sv

# Common compiler args
CARGS = -I$(HDL_DIR) -g2012

# Include cocotb Makefile
COCOTB_MAKEFILES = $(shell cocotb-config --makefiles)

# =============================================================================
# MODULE-SPECIFIC TARGETS
# =============================================================================

.PHONY: test_lfsr test_misr test_idle test_apb test_alu test_multdiv \
        test_bist_ctrl test_wrapper test_system test_all clean_all

# ---- 1. LFSR Generator ----
test_lfsr:
	$(MAKE) -f $(COCOTB_MAKEFILES)/Makefile.sim \
		SIM=$(SIM) TOPLEVEL_LANG=$(TOPLEVEL_LANG) \
		VERILOG_SOURCES="$(TS) $(HDL_DIR)/lfsr_gen.sv" \
		TOPLEVEL=lfsr_gen \
		COCOTB_TEST_MODULES=test_lfsr_gen \
		COMPILE_ARGS="$(CARGS)" \
		SIM_BUILD=sim_build/lfsr

# ---- 2. MISR Analyzer ----
test_misr:
	$(MAKE) -f $(COCOTB_MAKEFILES)/Makefile.sim \
		SIM=$(SIM) TOPLEVEL_LANG=$(TOPLEVEL_LANG) \
		VERILOG_SOURCES="$(TS) $(HDL_DIR)/misr_analyzer.sv" \
		TOPLEVEL=misr_analyzer \
		COCOTB_TEST_MODULES=test_misr_analyzer \
		COMPILE_ARGS="$(CARGS)" \
		SIM_BUILD=sim_build/misr

# ---- 3. Idle Detector ----
test_idle:
	$(MAKE) -f $(COCOTB_MAKEFILES)/Makefile.sim \
		SIM=$(SIM) TOPLEVEL_LANG=$(TOPLEVEL_LANG) \
		VERILOG_SOURCES="$(TS) $(HDL_DIR)/idle_detector.sv" \
		TOPLEVEL=idle_detector \
		COCOTB_TEST_MODULES=test_idle_detector \
		COMPILE_ARGS="$(CARGS)" \
		SIM_BUILD=sim_build/idle

# ---- 4. APB Slave Interface ----
test_apb:
	$(MAKE) -f $(COCOTB_MAKEFILES)/Makefile.sim \
		SIM=$(SIM) TOPLEVEL_LANG=$(TOPLEVEL_LANG) \
		VERILOG_SOURCES="$(TS) $(HDL_DIR)/apb_slave_if.sv" \
		TOPLEVEL=apb_slave_if \
		COCOTB_TEST_MODULES=test_apb_slave_if \
		COMPILE_ARGS="$(CARGS)" \
		SIM_BUILD=sim_build/apb

# ---- 5. Ibex ALU ----
test_alu:
	$(MAKE) -f $(COCOTB_MAKEFILES)/Makefile.sim \
		SIM=$(SIM) TOPLEVEL_LANG=$(TOPLEVEL_LANG) \
		VERILOG_SOURCES="$(TS) $(PKGS) $(HDL_DIR)/ibex_alu.sv" \
		TOPLEVEL=ibex_alu \
		COCOTB_TEST_MODULES=test_ibex_alu \
		COMPILE_ARGS="$(CARGS)" \
		SIM_BUILD=sim_build/alu

# ---- 6. Ibex MultDiv Fast ----
test_multdiv:
	$(MAKE) -f $(COCOTB_MAKEFILES)/Makefile.sim \
		SIM=$(SIM) TOPLEVEL_LANG=$(TOPLEVEL_LANG) \
		VERILOG_SOURCES="$(TS) $(PKGS) $(HDL_DIR)/ibex_multdiv_fast.sv" \
		TOPLEVEL=ibex_multdiv_fast \
		COCOTB_TEST_MODULES=test_ibex_multdiv \
		COMPILE_ARGS="$(CARGS)" \
		SIM_BUILD=sim_build/multdiv

# ---- 7. Runtime BIST Controller ----
test_bist_ctrl:
	$(MAKE) -f $(COCOTB_MAKEFILES)/Makefile.sim \
		SIM=$(SIM) TOPLEVEL_LANG=$(TOPLEVEL_LANG) \
		VERILOG_SOURCES="$(TS) $(PKGS) $(HDL_DIR)/apb_slave_if.sv \
		                 $(HDL_DIR)/idle_detector.sv $(HDL_DIR)/lfsr_gen.sv \
		                 $(HDL_DIR)/misr_analyzer.sv $(HDL_DIR)/runtime_bist_controller.sv" \
		TOPLEVEL=runtime_bist_controller \
		COCOTB_TEST_MODULES=test_bist_controller \
		COMPILE_ARGS="$(CARGS)" \
		SIM_BUILD=sim_build/bist_ctrl

# ---- 8. BIST Wrapper (Integration) ----
test_wrapper:
	$(MAKE) -f $(COCOTB_MAKEFILES)/Makefile.sim \
		SIM=$(SIM) TOPLEVEL_LANG=$(TOPLEVEL_LANG) \
		VERILOG_SOURCES="$(TS) $(PKGS) $(HDL_DIR)/ibex_alu.sv \
		                 $(HDL_DIR)/apb_slave_if.sv $(HDL_DIR)/idle_detector.sv \
		                 $(HDL_DIR)/lfsr_gen.sv $(HDL_DIR)/misr_analyzer.sv \
		                 $(HDL_DIR)/runtime_bist_controller.sv $(HDL_DIR)/ibex_alu_bist_wrapper.sv" \
		TOPLEVEL=ibex_alu_bist_wrapper \
		COCOTB_TEST_MODULES=test_bist_wrapper \
		COMPILE_ARGS="$(CARGS)" \
		SIM_BUILD=sim_build/wrapper

# ---- 9. Full System (Integration) ----
test_system:
	$(MAKE) -f $(COCOTB_MAKEFILES)/Makefile.sim \
		SIM=$(SIM) TOPLEVEL_LANG=$(TOPLEVEL_LANG) \
		VERILOG_SOURCES="$(TS) $(PKGS) $(HDL_DIR)/ibex_alu.sv \
		                 $(HDL_DIR)/ibex_multdiv_fast.sv \
		                 $(HDL_DIR)/apb_slave_if.sv $(HDL_DIR)/idle_detector.sv \
		                 $(HDL_DIR)/lfsr_gen.sv $(HDL_DIR)/misr_analyzer.sv \
		                 $(HDL_DIR)/runtime_bist_controller.sv \
		                 $(HDL_DIR)/ibex_alu_bist_wrapper.sv $(HDL_DIR)/ibex_ex_block.sv" \
		TOPLEVEL=ibex_ex_block \
		COCOTB_TEST_MODULES=test_full_system \
		COMPILE_ARGS="$(CARGS)" \
		SIM_BUILD=sim_build/system

# =============================================================================
# RUN ALL TESTS
# =============================================================================
test_all:
	@echo "============================================="
	@echo " RUNNING ALL COCOTB TESTS"
	@echo "============================================="
	@PASS=0; FAIL=0; TOTAL=0; \
	for target in test_lfsr test_misr test_idle test_apb test_alu test_multdiv \
	              test_bist_ctrl test_wrapper test_system; do \
		echo ""; \
		echo ">>> Running: $$target <<<"; \
		echo "---------------------------------------------"; \
		$(MAKE) -f Makefile $$target && \
			{ echo ">>> ✅ $$target PASSED"; PASS=$$((PASS+1)); } || \
			{ echo ">>> ❌ $$target FAILED"; FAIL=$$((FAIL+1)); }; \
		TOTAL=$$((TOTAL+1)); \
	done; \
	echo ""; \
	echo "============================================="; \
	echo " FINAL SUMMARY: $$PASS/$$TOTAL PASSED, $$FAIL FAILED"; \
	echo "============================================="; \
	test $$FAIL -eq 0

# =============================================================================
# CLEAN
# =============================================================================
clean_all:
	rm -rf sim_build results.xml __pycache__