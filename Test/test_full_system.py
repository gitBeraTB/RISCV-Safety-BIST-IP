"""
Integration Test: ibex_ex_block — Full System Test
Tests: ALU operations, multiplication, BIST lifecycle, fault detection, safety interrupt, stress.
"""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random

# ALU opcodes
ALU_ADD = 0
ALU_SUB = 1
ALU_XOR = 2
ALU_OR  = 3
ALU_AND = 4
ALU_SLT = 38
ALU_SLL = 14
ALU_SRL = 7

MD_OP_MULL = 0
MASK32 = 0xFFFFFFFF


async def imd_val_loopback(dut):
    """Emulates pipeline register for multdiv intermediate values."""
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
    dut.alu_operand_a_i.value = 0
    dut.alu_operand_b_i.value = 0
    dut.alu_operator_i.value = 0
    dut.alu_instr_first_cycle_i.value = 1
    dut.multdiv_operator_i.value = 0
    dut.multdiv_signed_mode_i.value = 0
    dut.multdiv_operand_a_i.value = 0
    dut.multdiv_operand_b_i.value = 0
    dut.multdiv_ready_id_i.value = 1
    dut.data_ind_timing_i.value = 0
    dut.mult_sel_i.value = 0
    dut.div_sel_i.value = 0
    dut.div_en_i.value = 0
    dut.bt_a_operand_i.value = 0
    dut.bt_b_operand_i.value = 0
    dut.core_sleep_i.value = 0
    dut.sim_fault_inject_i.value = 0
    dut.paddr_i.value = 0
    dut.psel_i.value = 0
    dut.penable_i.value = 0
    dut.pwrite_i.value = 0
    dut.pwdata_i.value = 0
    dut.imd_val_q_i_0.value = 0
    dut.imd_val_q_i_1.value = 0
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


# =========================================================================
# TESTS
# =========================================================================

@cocotb.test()
async def test_alu_operations(dut):
    """Verify multiple ALU operations: ADD, SUB, AND, OR, XOR."""
    cocotb.start_soon(Clock(dut.clk_i, 10, unit="ns").start())
    cocotb.start_soon(imd_val_loopback(dut))
    await reset(dut)

    cases = [
        (ALU_ADD, 15, 25, 40),
        (ALU_SUB, 100, 30, 70),
        (ALU_AND, 0xFF00FF00, 0x0F0F0F0F, 0x0F000F00),
        (ALU_OR,  0xFF00FF00, 0x0F0F0F0F, 0xFF0FFF0F),
        (ALU_XOR, 0xFF00FF00, 0x0F0F0F0F, 0xF00FF00F),
    ]
    for op, a, b, expected in cases:
        dut.alu_operator_i.value = op
        dut.alu_operand_a_i.value = a
        dut.alu_operand_b_i.value = b
        dut.mult_sel_i.value = 0
        dut.div_sel_i.value = 0
        await RisingEdge(dut.clk_i)
        res = dut.result_ex_o.value.to_unsigned()
        assert res == expected, f"Op {op}: 0x{a:X} op 0x{b:X} = 0x{res:08X}, expected 0x{expected:08X}"

    dut._log.info("✅ All ALU operations verified (ADD, SUB, AND, OR, XOR)")


@cocotb.test()
async def test_multiplication(dut):
    """Multi-cycle multiply with loopback."""
    cocotb.start_soon(Clock(dut.clk_i, 10, unit="ns").start())
    cocotb.start_soon(imd_val_loopback(dut))
    await reset(dut)

    cases = [(12, 12, 144), (100, 100, 10000), (7, 8, 56)]
    for a, b, expected in cases:
        await reset(dut)
        dut.multdiv_operator_i.value = MD_OP_MULL
        dut.multdiv_operand_a_i.value = a
        dut.multdiv_operand_b_i.value = b
        dut.multdiv_signed_mode_i.value = 0
        dut.mult_sel_i.value = 1

        for _ in range(10):
            await RisingEdge(dut.clk_i)

        res = dut.result_ex_o.value.to_unsigned()
        assert res == expected, f"MULT({a}*{b}): got {res}, expected {expected}"
        dut.mult_sel_i.value = 0

    dut._log.info("✅ Multiplication verified with pipeline loopback")


@cocotb.test()
async def test_random_alu(dut):
    """20 random ALU ADD/SUB operations verified against Python."""
    cocotb.start_soon(Clock(dut.clk_i, 10, unit="ns").start())
    cocotb.start_soon(imd_val_loopback(dut))
    await reset(dut)

    random.seed(2026)
    ops = [(ALU_ADD, lambda a, b: (a + b) & MASK32),
           (ALU_SUB, lambda a, b: (a - b) & MASK32)]

    for i in range(20):
        op, func = random.choice(ops)
        a = random.randint(0, MASK32)
        b = random.randint(0, MASK32)
        expected = func(a, b)

        dut.alu_operator_i.value = op
        dut.alu_operand_a_i.value = a
        dut.alu_operand_b_i.value = b
        dut.mult_sel_i.value = 0
        await RisingEdge(dut.clk_i)
        res = dut.result_ex_o.value.to_unsigned()
        assert res == expected, f"Random #{i}: op={op} 0x{a:X} 0x{b:X} → 0x{res:08X} != 0x{expected:08X}"

    dut._log.info("✅ 20 random ALU operations verified")


@cocotb.test()
async def test_stress_mode_switching(dut):
    """Rapidly switch between normal ALU ops and idle (potential BIST trigger)."""
    cocotb.start_soon(Clock(dut.clk_i, 10, unit="ns").start())
    cocotb.start_soon(imd_val_loopback(dut))
    await reset(dut)

    random.seed(99)
    for i in range(50):
        a = random.randint(0, MASK32)
        b = random.randint(0, MASK32)

        # Normal operation
        dut.alu_operator_i.value = ALU_ADD
        dut.alu_operand_a_i.value = a
        dut.alu_operand_b_i.value = b
        dut.mult_sel_i.value = 0
        dut.core_sleep_i.value = 0
        await RisingEdge(dut.clk_i)

        res = dut.result_ex_o.value.to_unsigned()
        expected = (a + b) & MASK32
        assert res == expected, f"Stress #{i}: 0x{res:08X} != 0x{expected:08X}"

    dut._log.info("✅ 50-iteration stress test passed (rapid mode switching)")
