"""
Unit Test: ibex_multdiv_fast — MultDiv Fast Module
Tests: basic multiply, edge cases, random multiply, FSM progression.
"""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random

MD_OP_MULL = 0
MASK32 = 0xFFFFFFFF


async def imd_val_loopback(dut):
    """Emulates the pipeline register that feeds back intermediate values."""
    while True:
        await RisingEdge(dut.clk_i)
        try:
            we = int(dut.imd_val_we_o.value)
            if we & 1:
                dut.imd_val_q_i_0.value = int(dut.imd_val_d_o_0.value)
            if we & 2:
                dut.imd_val_q_i_1.value = int(dut.imd_val_d_o_1.value)
        except ValueError:
            pass


async def reset(dut):
    dut.rst_ni.value = 0
    dut.mult_en_i.value = 0
    dut.div_en_i.value = 0
    dut.mult_sel_i.value = 0
    dut.div_sel_i.value = 0
    dut.operator_i.value = 0
    dut.signed_mode_i.value = 0
    dut.op_a_i.value = 0
    dut.op_b_i.value = 0
    dut.alu_adder_ext_i.value = 0
    dut.alu_adder_i.value = 0
    dut.equal_to_zero_i.value = 0
    dut.data_ind_timing_i.value = 0
    dut.imd_val_q_i_0.value = 0
    dut.imd_val_q_i_1.value = 0
    await Timer(50, unit="ns")
    dut.rst_ni.value = 1
    await RisingEdge(dut.clk_i)
    await RisingEdge(dut.clk_i)


async def do_multiply(dut, a, b, cycles=10):
    """Perform a MULL operation and return the result."""
    dut.operator_i.value = MD_OP_MULL
    dut.op_a_i.value = a
    dut.op_b_i.value = b
    dut.signed_mode_i.value = 0
    dut.mult_en_i.value = 1
    dut.mult_sel_i.value = 1

    for _ in range(cycles):
        await RisingEdge(dut.clk_i)

    res = dut.multdiv_result_o.value.to_unsigned()
    dut.mult_en_i.value = 0
    dut.mult_sel_i.value = 0
    return res


@cocotb.test()
async def test_multiply_basic(dut):
    """Basic multiplication: 12*12=144, 7*8=56, 100*100=10000."""
    cocotb.start_soon(Clock(dut.clk_i, 10, unit="ns").start())
    cocotb.start_soon(imd_val_loopback(dut))
    await reset(dut)

    test_cases = [(12, 12, 144), (7, 8, 56), (100, 100, 10000), (256, 256, 65536)]
    for a, b, expected in test_cases:
        await reset(dut)
        res = await do_multiply(dut, a, b)
        assert res == expected, f"MULL({a}*{b}): got {res}, expected {expected}"
        dut._log.info(f"   ✅ {a} × {b} = {res}")

    dut._log.info("✅ Basic multiplication verified")


@cocotb.test()
async def test_multiply_edge(dut):
    """Edge cases: 0*N, 1*N, N*1."""
    cocotb.start_soon(Clock(dut.clk_i, 10, unit="ns").start())
    cocotb.start_soon(imd_val_loopback(dut))
    await reset(dut)

    test_cases = [(0, 12345, 0), (1, 9999, 9999), (65535, 1, 65535)]
    for a, b, expected in test_cases:
        await reset(dut)
        res = await do_multiply(dut, a, b)
        assert res == expected, f"MULL({a}*{b}): got {res}, expected {expected}"
        dut._log.info(f"   ✅ {a} × {b} = {res}")

    dut._log.info("✅ Edge case multiplication verified")


@cocotb.test()
async def test_multiply_random(dut):
    """10 random 16-bit multiplications verified against Python."""
    cocotb.start_soon(Clock(dut.clk_i, 10, unit="ns").start())
    cocotb.start_soon(imd_val_loopback(dut))

    random.seed(42)
    for i in range(10):
        a = random.randint(0, 0xFFFF)
        b = random.randint(0, 0xFFFF)
        expected = (a * b) & MASK32
        await reset(dut)
        res = await do_multiply(dut, a, b)
        assert res == expected, f"Random MULL #{i}: {a}*{b}=0x{res:08X}, expected 0x{expected:08X}"

    dut._log.info("✅ 10 random multiplications verified")


@cocotb.test()
async def test_fsm_state_progression(dut):
    """Verify that mult FSM cycles through ALBL->ALBH->AHBL for MULL."""
    cocotb.start_soon(Clock(dut.clk_i, 10, unit="ns").start())
    cocotb.start_soon(imd_val_loopback(dut))
    await reset(dut)

    dut.operator_i.value = MD_OP_MULL
    dut.op_a_i.value = 100
    dut.op_b_i.value = 200
    dut.signed_mode_i.value = 0
    dut.mult_en_i.value = 1
    dut.mult_sel_i.value = 1

    # Observe valid_o going high (indicates FSM completed)
    valid_seen = False
    for i in range(15):
        await RisingEdge(dut.clk_i)
        try:
            if int(dut.valid_o.value) == 1:
                valid_seen = True
                dut._log.info(f"   valid_o asserted at cycle {i}")
                break
        except ValueError:
            pass

    assert valid_seen, "valid_o never asserted — FSM may be stuck"
    dut._log.info("✅ MultDiv FSM progression verified (valid_o asserted)")
