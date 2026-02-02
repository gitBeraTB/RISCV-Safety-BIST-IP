# File: Test/tb_ibex_wrapper.py
# Description: Functional Verification for Ibex ALU BIST Wrapper.
#              Full Version: Includes Imports, Polling Helpers, and Robust Logic.
# Author: ODTU EE Student
# -----------------------------------------------------------------------------

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.utils import get_sim_time
import random

# --- Constants ---
class AluOp:
    ALU_ADD = 0
    ALU_SUB = 1
    ALU_AND = 2
    ALU_OR  = 3
    ALU_XOR = 4
    ALU_SLT = 5
    ALU_SLL = 6

# --- APB Driver ---
class APBDriver:
    def __init__(self, dut):
        self.dut = dut
        self.log = dut._log

    async def write(self, addr, data):
        self.dut.paddr_i.value = addr
        self.dut.psel_i.value = 1
        self.dut.pwrite_i.value = 1
        self.dut.pwdata_i.value = data
        self.dut.penable_i.value = 0
        await RisingEdge(self.dut.clk_i)
        self.dut.penable_i.value = 1
        await RisingEdge(self.dut.clk_i)
        self.dut.psel_i.value = 0
        self.dut.penable_i.value = 0
        self.dut.pwrite_i.value = 0
        # self.log.info(f"[APB] Write Addr: 0x{addr:02X} Data: 0x{data:X}")

    async def read(self, addr):
        self.dut.paddr_i.value = addr
        self.dut.psel_i.value = 1
        self.dut.pwrite_i.value = 0
        self.dut.penable_i.value = 0
        await RisingEdge(self.dut.clk_i)
        self.dut.penable_i.value = 1
        await RisingEdge(self.dut.clk_i)
        data = self.dut.prdata_o.value
        self.dut.psel_i.value = 0
        self.dut.penable_i.value = 0
        return data

# --- RISC-V Core Driver ---
class RiscvCoreDriver:
    def __init__(self, dut):
        self.dut = dut
        self.log = dut._log

    async def execute_instruction(self, opcode, a, b):
        self.dut.core_sleep_i.value = 0 
        self.dut.operator_i.value = opcode
        self.dut.operand_a_i.value = a
        self.dut.operand_b_i.value = b
        await RisingEdge(self.dut.clk_i)

    def enter_wfi(self):
        self.log.info("[CORE] Entering WFI (Sleep) Mode...")
        self.dut.core_sleep_i.value = 1
        self.dut.operator_i.value = 0
        self.dut.operand_a_i.value = 0
        self.dut.operand_b_i.value = 0

    def wake_up(self):
        self.log.info("[CORE] Interrupt received! Waking up...")
        self.dut.core_sleep_i.value = 0

# --- POLLING HELPERS (Robust Timing) ---

async def wait_for_bist_start(apb, log):
    """BIST'in çalışmaya başladığını (BUSY=1) teyit eder."""
    log.info("   [WAIT] Waiting for BIST to START (Busy=1)...")
    for _ in range(200): 
        val = await apb.read(0x04)
        status = val.to_unsigned()
        if (status & 1): # If Busy bit is 1
            return
        await Timer(10, unit="ns")
    log.warning("[TIMEOUT] BIST did not start quickly (Check Threshold?)")

async def wait_for_bist_completion(apb, log):
    """BIST'in işini bitirmesini (BUSY=0) bekler."""
    log.info("   [WAIT] Waiting for BIST to FINISH (Busy=0)...")
    for _ in range(500):
        val = await apb.read(0x04)
        status = val.to_unsigned()
        if (status & 1) == 0: # If Busy bit is 0
            return status
        await Timer(50, unit="ns")
    log.error("[TIMEOUT] BIST Stuck in Busy State!")
    raise TimeoutError("BIST Timeout")

# --- MAIN TEST SEQUENCE ---

@cocotb.test()
async def test_ibex_integration(dut):
    # 1. Initialization
    cocotb.start_soon(Clock(dut.clk_i, 10, unit="ns").start())
    apb = APBDriver(dut)
    core = RiscvCoreDriver(dut)
    
    dut.rst_ni.value = 0
    dut.core_sleep_i.value = 0
    dut.sim_fault_inject_i.value = 0 
    
    await Timer(50, unit="ns")
    dut.rst_ni.value = 1
    await RisingEdge(dut.clk_i)
    dut._log.info("[INIT] System Reset Complete.")

    # 2. Configuration
    await apb.write(0x08, 10) # Threshold = 10
    await apb.write(0x00, 1)  # Enable BIST

    # 3. Normal Mode Check
    dut._log.info("---------------------------------------------------")
    dut._log.info("[PHASE 1] Normal ALU Operations...")
    val_a = 50
    val_b = 25
    await core.execute_instruction(AluOp.ALU_ADD, val_a, val_b)
    res = dut.result_o.value.to_unsigned()
    if res != (val_a + val_b):
        assert False, f"ADD Failed: {res}"
    dut._log.info(f"   [PASS] Normal ADD Operation Verified.")

    # -------------------------------------------------------------------------
    # 4. CALIBRATION PHASE
    # -------------------------------------------------------------------------
    dut._log.info("---------------------------------------------------")
    dut._log.info("[PHASE 2] CALIBRATION: Learning Golden Signature...")
    
    core.enter_wfi() # Sleep to trigger BIST
    
    # A. Wait for Start
    await wait_for_bist_start(apb, dut._log)
    
    # B. Wait for Finish
    await wait_for_bist_completion(apb, dut._log)
    
    # C. Read Result
    actual_sig = await apb.read(0x10)
    actual_sig_int = actual_sig.to_unsigned()
    
    if actual_sig_int == 0xFFFFFFFF or actual_sig_int == 0:
        dut._log.warning(f"[WARN] Captured Signature seems invalid: 0x{actual_sig_int:X}")
    else:
        dut._log.info(f"[CALIBRATE] Captured Valid Signature: 0x{actual_sig_int:X}")
    
    # D. Save Golden Signature
    await apb.write(0x0C, actual_sig_int)
    dut._log.info("[CALIBRATE] Golden Signature Saved.")

    # -------------------------------------------------------------------------
    # 5. Safety Recovery Check
    # -------------------------------------------------------------------------
    dut._log.info("---------------------------------------------------")
    dut._log.info("[PHASE 3] Testing Interrupt Recovery...")
    core.wake_up()
    crit_a = 100
    crit_b = 200
    await core.execute_instruction(AluOp.ALU_ADD, crit_a, crit_b)
    await RisingEdge(dut.clk_i) # Wait for logic
    
    res = dut.result_o.value.to_unsigned()
    if res == (crit_a + crit_b):
        dut._log.info(f"[PASS] Recovery Verified. Output: {res}")
    else:
        assert False, f"Recovery Failed. Output: {res}"

    # -------------------------------------------------------------------------
    # 6. FAULT INJECTION TEST
    # -------------------------------------------------------------------------
    dut._log.info("---------------------------------------------------")
    dut._log.info("[PHASE 4] FAULT INJECTION TEST...")

    # Reset System State
    core.enter_wfi()
    dut.sim_fault_inject_i.value = 0 
    
    # A. Wait for BIST to Start
    await wait_for_bist_start(apb, dut._log)
    
    # B. INJECT FAULT
    dut._log.info("   -> Injecting Hardware Fault...")
    dut.sim_fault_inject_i.value = 1
    
    # C. Wait for Completion
    final_status_val = await wait_for_bist_completion(apb, dut._log)
    
    # D. Check Results
    irq_val = dut.bist_error_irq_o.value
    
    # Status (Bit 1 = Fail)
    if irq_val == 1 and (final_status_val & 2):
        dut._log.info(f"[PASS] Fault Detected! IRQ: {irq_val}, Status: 0x{final_status_val:X}")
    else:
        faulty_sig = await apb.read(0x10)
        dut._log.error(f"[FAIL] Fault Missed! IRQ: {irq_val}, Status: 0x{final_status_val:X}")
        dut._log.error(f"       Golden: 0x{actual_sig_int:X} vs Faulty: 0x{faulty_sig.to_unsigned():X}")
        assert False

    dut.sim_fault_inject_i.value = 0
    dut._log.info("---------------------------------------------------")
    dut._log.info("ALL TESTS PASSED ✅")