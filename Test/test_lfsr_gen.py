"""
Unit Test: lfsr_gen — LFSR Pattern Generator
Tests: reset value, enable/disable, seed loading, sequence uniqueness.
"""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

INITIAL_SEED = 0xDEAD_BEEF


async def reset(dut):
    dut.rst_n.value = 0
    dut.enable.value = 0
    dut.seed_load.value = 0
    dut.seed_data.value = 0
    await Timer(50, unit="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)


@cocotb.test()
async def test_reset_value(dut):
    """After reset, output should be INITIAL_SEED."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)
    val = dut.pattern_out.value.to_unsigned()
    assert val == INITIAL_SEED, f"Reset value mismatch: 0x{val:08X} != 0x{INITIAL_SEED:08X}"
    dut._log.info(f"✅ Reset value correct: 0x{val:08X}")


@cocotb.test()
async def test_enable_shifts(dut):
    """When enabled, output should change every cycle (LFSR shifts)."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)

    dut.enable.value = 1
    # Wait one cycle for the first enable to take effect (registered output)
    await RisingEdge(dut.clk)
    prev = dut.pattern_out.value.to_unsigned()

    for i in range(10):
        await RisingEdge(dut.clk)
        curr = dut.pattern_out.value.to_unsigned()
        assert curr != prev, f"Cycle {i}: output didn't change (stuck at 0x{curr:08X})"
        prev = curr

    dut._log.info("✅ LFSR output shifts every cycle when enabled")


@cocotb.test()
async def test_disable_holds(dut):
    """When disabled, output should freeze."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)

    # Run a few cycles to get a non-seed value
    dut.enable.value = 1
    for _ in range(5):
        await RisingEdge(dut.clk)

    # Disable and capture
    dut.enable.value = 0
    await RisingEdge(dut.clk)
    frozen_val = dut.pattern_out.value.to_unsigned()

    # Verify it stays frozen for 10 more cycles
    for i in range(10):
        await RisingEdge(dut.clk)
        curr = dut.pattern_out.value.to_unsigned()
        assert curr == frozen_val, f"Output changed while disabled at cycle {i}"

    dut._log.info(f"✅ Output held at 0x{frozen_val:08X} while disabled")


@cocotb.test()
async def test_seed_load(dut):
    """Loading a custom seed should override the LFSR register."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)

    custom_seed = 0x1234_5678
    dut.seed_load.value = 1
    dut.seed_data.value = custom_seed
    await RisingEdge(dut.clk)
    dut.seed_load.value = 0
    await RisingEdge(dut.clk)

    val = dut.pattern_out.value.to_unsigned()
    assert val != INITIAL_SEED, "Seed load did not change the value"
    dut._log.info(f"✅ Seed loaded successfully: 0x{val:08X}")


@cocotb.test()
async def test_sequence_uniqueness(dut):
    """100 consecutive outputs should all be unique (no short-period repeat)."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)

    dut.enable.value = 1
    values = set()
    for i in range(100):
        await RisingEdge(dut.clk)
        val = dut.pattern_out.value.to_unsigned()
        assert val not in values, f"Duplicate at cycle {i}: 0x{val:08X}"
        values.add(val)

    dut._log.info(f"✅ All 100 values unique")
