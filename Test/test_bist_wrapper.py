"""
Integration Test: ibex_alu_bist_wrapper — ALU + BIST Wrapper
Tests: normal passthrough, BIST mode muxing, calibration cycle, fault injection.
"""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random

# ALU opcodes
ALU_ADD = 0
ALU_SUB = 1
ALU_XOR = 2


async def reset(dut):
    dut.rst_ni.value = 0
    dut.operator_i.value = 0
    dut.operand_a_i.value = 0
    dut.operand_b_i.value = 0
    dut.instr_first_cycle_i.value = 1
    dut.multdiv_en_i.value = 0
    dut.imd_val_q_i.value = 0
    dut.imd_val_we_i.value = 0
    dut.core_sleep_i.value = 0
    dut.sim_fault_inject_i.value = 0
    dut.paddr_i.value = 0
    dut.psel_i.value = 0
    dut.penable_i.value = 0
    dut.pwrite_i.value = 0
    dut.pwdata_i.value = 0
    await Timer(50, unit="ns")
    dut.rst_ni.value = 1
    await RisingEdge(dut.clk_i)
    await RisingEdge(dut.clk_i)


async def apb_write(dut, addr, data):
    dut.paddr_i.value = addr
    dut.psel_i.value = 1
    dut.pwrite_i.value = 1
    dut.pwdata_i.value = data
    dut.penable_i.value = 0
    await RisingEdge(dut.clk_i)
    dut.penable_i.value = 1
    await RisingEdge(dut.clk_i)
    dut.psel_i.value = 0
    dut.penable_i.value = 0
    dut.pwrite_i.value = 0


async def apb_read(dut, addr):
    dut.paddr_i.value = addr
    dut.psel_i.value = 1
    dut.pwrite_i.value = 0
    dut.penable_i.value = 0
    await RisingEdge(dut.clk_i)
    dut.penable_i.value = 1
    await RisingEdge(dut.clk_i)
    data = dut.prdata_o.value.to_unsigned()
    dut.psel_i.value = 0
    dut.penable_i.value = 0
    return data


async def wait_bist_start(dut, timeout=200):
    for _ in range(timeout):
        status = await apb_read(dut, 0x04)
        if status & 1:
            return
        await Timer(10, unit="ns")
    dut._log.warning("[TIMEOUT] BIST did not start")


async def wait_bist_done(dut, timeout=600):
    for _ in range(timeout):
        status = await apb_read(dut, 0x04)
        if (status & 1) == 0:
            return status
        await Timer(50, unit="ns")
    raise TimeoutError("BIST timeout")


@cocotb.test()
async def test_normal_alu_passthrough(dut):
    """In normal mode, ALU operations should pass through correctly."""
    cocotb.start_soon(Clock(dut.clk_i, 10, unit="ns").start())
    await reset(dut)

    # ADD
    dut.operator_i.value = ALU_ADD
    dut.operand_a_i.value = 100
    dut.operand_b_i.value = 200
    dut.core_sleep_i.value = 0  # System active
    await RisingEdge(dut.clk_i)
    res = dut.result_o.value.to_unsigned()
    assert res == 300, f"Normal ADD: got {res}, expected 300"

    # SUB
    dut.operator_i.value = ALU_SUB
    dut.operand_a_i.value = 500
    dut.operand_b_i.value = 123
    await RisingEdge(dut.clk_i)
    res = dut.result_o.value.to_unsigned()
    assert res == 377, f"Normal SUB: got {res}, expected 377"

    dut._log.info("✅ Normal ALU passthrough verified")


@cocotb.test()
async def test_bist_mode_mux(dut):
    """When BIST is active, ALU inputs should come from LFSR pattern."""
    cocotb.start_soon(Clock(dut.clk_i, 10, unit="ns").start())
    await reset(dut)

    # Configure BIST with short threshold
    await apb_write(dut, 0x08, 5)   # Threshold
    await apb_write(dut, 0x00, 1)   # Enable

    # Go to sleep (idle)
    dut.core_sleep_i.value = 1
    dut.operator_i.value = ALU_ADD
    dut.operand_a_i.value = 0xAAAA
    dut.operand_b_i.value = 0xBBBB

    # Wait for BIST to start
    await wait_bist_start(dut)

    # During BIST, the result_o should NOT be operand_a + operand_b
    await RisingEdge(dut.clk_i)
    res = dut.result_o.value.to_unsigned()
    expected_normal = 0xAAAA + 0xBBBB
    # The result should be bist_pattern + ~bist_pattern (from mux)
    dut._log.info(f"   BIST mode result: 0x{res:08X} (normal would be 0x{expected_normal:08X})")
    assert res != expected_normal, "ALU should be using BIST patterns, not normal inputs"
    dut._log.info("✅ BIST mode input muxing verified")


@cocotb.test()
async def test_calibration_and_recheck(dut):
    """Full calibration: run BIST → capture signature → save golden → re-run → PASS."""
    cocotb.start_soon(Clock(dut.clk_i, 10, unit="ns").start())
    await reset(dut)

    # 1. Configure
    await apb_write(dut, 0x08, 3)  # Short threshold
    await apb_write(dut, 0x00, 1)  # Enable
    dut.core_sleep_i.value = 1     # Go idle

    # 2. First run: calibration
    await wait_bist_start(dut)
    await wait_bist_done(dut)

    golden = await apb_read(dut, 0x10)
    dut._log.info(f"   Calibration signature: 0x{golden:08X}")

    # 3. Save golden
    await apb_write(dut, 0x0C, golden)

    # 4. Re-run
    dut.core_sleep_i.value = 0
    await RisingEdge(dut.clk_i)
    await apb_write(dut, 0x00, 1)
    dut.core_sleep_i.value = 1

    await wait_bist_start(dut)
    await wait_bist_done(dut)

    for _ in range(3):
        await RisingEdge(dut.clk_i)

    irq = int(dut.bist_error_irq_o.value)
    assert irq == 0, f"IRQ should be 0 after matching golden, got {irq}"
    dut._log.info("✅ Calibration → re-run → PASS verified")


@cocotb.test()
async def test_fault_injection(dut):
    """With sim_fault_inject, BIST should detect a hardware fault."""
    cocotb.start_soon(Clock(dut.clk_i, 10, unit="ns").start())
    await reset(dut)

    # 1. Calibration run (no fault)
    await apb_write(dut, 0x08, 3)
    await apb_write(dut, 0x00, 1)
    dut.core_sleep_i.value = 1
    dut.sim_fault_inject_i.value = 0

    await wait_bist_start(dut)
    await wait_bist_done(dut)

    golden = await apb_read(dut, 0x10)
    await apb_write(dut, 0x0C, golden)
    dut._log.info(f"   Golden: 0x{golden:08X}")

    # 2. Fault injection run with IRQ monitor
    irq_seen = False

    async def monitor_irq():
        nonlocal irq_seen
        while True:
            await RisingEdge(dut.clk_i)
            try:
                if int(dut.bist_error_irq_o.value) == 1:
                    irq_seen = True
                    return
            except ValueError:
                pass

    cocotb.start_soon(monitor_irq())

    dut.core_sleep_i.value = 0
    await RisingEdge(dut.clk_i)
    await apb_write(dut, 0x00, 1)
    dut.core_sleep_i.value = 1

    await wait_bist_start(dut)
    dut.sim_fault_inject_i.value = 1
    await wait_bist_done(dut)

    # Disable to prevent re-run
    await apb_write(dut, 0x00, 0)

    for _ in range(5):
        await RisingEdge(dut.clk_i)

    faulty_sig = await apb_read(dut, 0x10)
    dut._log.info(f"   Faulty signature: 0x{faulty_sig:08X}, IRQ seen: {irq_seen}")
    assert irq_seen, f"Fault should trigger IRQ but it was not observed"
    dut._log.info("✅ Fault injection detection verified")
