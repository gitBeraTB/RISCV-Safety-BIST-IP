import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

# -----------------------------------------------------------------------------
# CONSTANTS (Mappings from ibex_pkg.sv)
# -----------------------------------------------------------------------------
ALU_ADD = 0
ALU_SUB = 1
MD_OP_MULL = 0  # 32-bit multiplication (Lower 32-bit result)

async def reset_dut(dut):
    """
    Resets the Design Under Test (DUT) and initializes input signals to zero.
    """
    dut.rst_ni.value = 0
    dut.alu_operand_a_i.value = 0
    dut.alu_operand_b_i.value = 0
    dut.alu_operator_i.value = 0
    dut.mult_en_i.value = 0
    dut.div_en_i.value = 0
    dut.mult_sel_i.value = 0
    dut.div_sel_i.value = 0
    dut.multdiv_ready_id_i.value = 1
    
    # Initialize the loopback array signals
    dut.imd_val_q_i[0].value = 0
    dut.imd_val_q_i[1].value = 0
    
    # Wait for 20ns during Reset
    await Timer(20, units="ns")
    dut.rst_ni.value = 1
    await RisingEdge(dut.clk_i)

@cocotb.test()
async def test_alu_and_mult(dut):
    """
    Main Test: Verifies ALU Addition, Subtraction, and MultDiv Multiplication.
    Checks if the 34-bit to 32-bit modification affected the logic.
    """
    
    # 1. Start Clock (10ns period = 100 MHz)
    cocotb.start_soon(Clock(dut.clk_i, 10, units="ns").start())

    # 2. Apply Reset
    await reset_dut(dut)
    dut._log.info("--- RESET COMPLETED ---")

    # -------------------------------------------------------------------------
    # TEST 1: ALU ADDITION (15 + 25)
    # -------------------------------------------------------------------------
    dut._log.info("TEST 1: ALU Addition (15 + 25)")
    
    dut.alu_operator_i.value = ALU_ADD
    dut.alu_operand_a_i.value = 15
    dut.alu_operand_b_i.value = 25
    dut.mult_sel_i.value = 0 # Select ALU output
    
    await RisingEdge(dut.clk_i) # Wait for one clock cycle
    
    # Check Result
    res = int(dut.result_ex_o.value)
    assert res == 40, f"ALU ADD Error! Expected: 40, Got: {res}"
    dut._log.info(f"✅ TEST 1 PASSED: 15 + 25 = {res}")

    # -------------------------------------------------------------------------
    # TEST 2: ALU SUBTRACTION (100 - 30)
    # -------------------------------------------------------------------------
    await RisingEdge(dut.clk_i)
    dut._log.info("TEST 2: ALU Subtraction (100 - 30)")
    
    dut.alu_operator_i.value = ALU_SUB
    dut.alu_operand_a_i.value = 100
    dut.alu_operand_b_i.value = 30
    
    await RisingEdge(dut.clk_i)
    
    res = int(dut.result_ex_o.value)
    assert res == 70, f"ALU SUB Error! Expected: 70, Got: {res}"
    dut._log.info(f"✅ TEST 2 PASSED: 100 - 30 = {res}")

    # -------------------------------------------------------------------------
    # TEST 3: MULTIPLIER (12 * 12)
    # -------------------------------------------------------------------------
    # Note: Multiplication is a multi-cycle operation. We must wait for 'ex_valid_o'.
    
    await RisingEdge(dut.clk_i)
    dut._log.info("TEST 3: MultDiv Multiplication (12 * 12)")
    
    dut.multdiv_operator_i.value = MD_OP_MULL
    dut.multdiv_operand_a_i.value = 12
    dut.multdiv_operand_b_i.value = 12
    dut.multdiv_signed_mode_i.value = 0 # Unsigned mode
    
    dut.mult_en_i.value = 1  # Enable Multiplier
    dut.mult_sel_i.value = 1 # Select Multiplier output (Mux)
    
    # Wait until valid signal is high (Operation finished)
    await RisingEdge(dut.clk_i)
    while dut.ex_valid_o.value == 0:
        await RisingEdge(dut.clk_i)
        
    res = int(dut.result_ex_o.value)
    assert res == 144, f"MULT Error! Expected: 144, Got: {res}"
    dut._log.info(f"✅ TEST 3 PASSED: 12 * 12 = {res}")

    # Disable Enable signal
    dut.mult_en_i.value = 0
    await RisingEdge(dut.clk_i)

    # -------------------------------------------------------------------------
    # TEST 4: LARGE NUMBER MULTIPLICATION (1000 * 500)
    # -------------------------------------------------------------------------
    # This verifies that bit truncation didn't break larger calculations.
    
    dut._log.info("TEST 4: Large Number Multiplication (1000 * 500)")
    
    dut.multdiv_operand_a_i.value = 1000
    dut.multdiv_operand_b_i.value = 500
    dut.mult_en_i.value = 1
    
    # Wait for the previous operation's valid signal to drop (if any)
    # and wait for the new valid signal.
    await RisingEdge(dut.clk_i)
    while dut.ex_valid_o.value == 0:
        await RisingEdge(dut.clk_i)

    res = int(dut.result_ex_o.value)
    expected_val = 500000
    assert res == expected_val, f"BIG MULT Error! Expected: {expected_val}, Got: {res}"
    
    dut._log.info(f"🏆 TEST 4 (FINAL) PASSED: 1000 * 500 = {res}")
    dut._log.info("### ALL SIMULATIONS COMPLETED SUCCESSFULLY ###")