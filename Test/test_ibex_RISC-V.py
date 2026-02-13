import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge

# -----------------------------------------------------------------------------
# CONSTANTS
# -----------------------------------------------------------------------------
ALU_ADD = 0
ALU_SUB = 1
MD_OP_MULL = 0

# -----------------------------------------------------------------------------
# IMD_VAL LOOPBACK: Mimics the external register that feeds back
# multdiv intermediate values each clock cycle.
# -----------------------------------------------------------------------------
async def imd_val_loopback(dut):
    """
    Continuously loops back imd_val_d_o -> imd_val_q_i on every rising edge.
    This emulates the pipeline register that exists in the real Ibex core.
    """
    while True:
        await RisingEdge(dut.clk_i)
        try:
            we = int(dut.imd_val_we_o.value)
            if we & 1:
                dut.imd_val_q_i_0.value = int(dut.imd_val_d_o_0.value)
            if we & 2:
                dut.imd_val_q_i_1.value = int(dut.imd_val_d_o_1.value)
        except ValueError:
            pass  # Skip if X/Z values

async def reset_dut(dut):
    """
    Kapsamli Reset Fonksiyonu: Tum girisleri sifirlar.
    X/Z yayilimini onler.
    """
    dut._log.info("Resetting DUT...")
    dut.rst_ni.value = 0
    
    # ALU Girisleri
    dut.alu_operand_a_i.value = 0
    dut.alu_operand_b_i.value = 0
    dut.alu_operator_i.value = 0
    dut.alu_instr_first_cycle_i.value = 1 # Onemli! Shifter mantigi icin 1 olmali
    
    # MultDiv Girisleri
    dut.multdiv_operator_i.value = 0
    dut.multdiv_signed_mode_i.value = 0
    dut.multdiv_operand_a_i.value = 0
    dut.multdiv_operand_b_i.value = 0
    dut.multdiv_ready_id_i.value = 1
    dut.data_ind_timing_i.value = 0
    
    # Kontrol Sinyalleri (Bunlar X olursa sonuc X olur!)
    dut.mult_sel_i.value = 0
    dut.div_sel_i.value = 0
    dut.div_en_i.value = 0
    
    # Branch Target ALU (Kullanilmasa bile sifirla)
    dut.bt_a_operand_i.value = 0
    dut.bt_b_operand_i.value = 0

    # Dummy / BIST Sinyalleri
    dut.core_sleep_i.value = 0
    dut.sim_fault_inject_i.value = 0
    dut.paddr_i.value = 0
    dut.psel_i.value = 0
    dut.penable_i.value = 0
    dut.pwrite_i.value = 0
    dut.pwdata_i.value = 0

    # Flat Loopback Sinyalleri
    dut.imd_val_q_i_0.value = 0
    dut.imd_val_q_i_1.value = 0
    
    # Reset suresini uzatalim
    await Timer(50, unit="ns")
    dut.rst_ni.value = 1
    
    # Reset sonrasi 2 cycle bekle ki sinyaller otursun
    await RisingEdge(dut.clk_i)
    await RisingEdge(dut.clk_i)
    dut._log.info("Reset Complete.")

@cocotb.test()
async def test_alu_and_mult(dut):
    """
    Main Test: Verifies ALU Addition, Subtraction, and MultDiv Multiplication.
    """
    
    # 1. Start Clock (10ns period = 100 MHz)
    cocotb.start_soon(Clock(dut.clk_i, 10, unit="ns").start())

    # 2. Start IMD_VAL loopback (emulates pipeline register)
    cocotb.start_soon(imd_val_loopback(dut))

    # 3. Apply Reset
    await reset_dut(dut)

    # -------------------------------------------------------------------------
    # TEST 1: ALU ADDITION (15 + 25)
    # -------------------------------------------------------------------------
    dut._log.info("TEST 1: ALU Addition (15 + 25)")
    
    dut.alu_operator_i.value = ALU_ADD
    dut.alu_operand_a_i.value = 15
    dut.alu_operand_b_i.value = 25
    
    # Output Mux icin ALU secimi
    dut.mult_sel_i.value = 0
    dut.div_sel_i.value = 0
    
    await RisingEdge(dut.clk_i)
    
    # Hata Ayiklama Blogu
    try:
        # X degeri varsa int() cevirimi hata verir
        res = int(dut.result_ex_o.value)
        
        assert res == 40, f"ALU ADD Error! Expected: 40, Got: {res}"
        dut._log.info(f"✅ TEST 1 PASSED: 15 + 25 = {res}")
        
    except ValueError:
        dut._log.error(f"❌ TEST 1 FAILED: Result contains X or Z (Unknown)")
        dut._log.error(f"   Binary Value: {dut.result_ex_o.value}")
        raise # Testi durdur

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
    await RisingEdge(dut.clk_i)
    dut._log.info("TEST 3: MultDiv Multiplication (12 * 12)")
    
    dut.multdiv_operator_i.value = MD_OP_MULL
    dut.multdiv_operand_a_i.value = 12
    dut.multdiv_operand_b_i.value = 12
    dut.multdiv_signed_mode_i.value = 0 
    
    # Multiplier Enable
    dut.mult_sel_i.value = 1 
    
    # Wait for mult FSM to complete (ALBL -> ALBH -> AHBL = 3 cycles for MULL)
    for i in range(10):
        await RisingEdge(dut.clk_i)
    
    res = int(dut.result_ex_o.value)
    assert res == 144, f"MULT Error! Expected: 144, Got: {res}"
    dut._log.info(f"✅ TEST 3 PASSED: 12 * 12 = {res}")

    dut.mult_sel_i.value = 0
    await RisingEdge(dut.clk_i)

    dut._log.info("### ALL SIMULATIONS COMPLETED SUCCESSFULLY ###")