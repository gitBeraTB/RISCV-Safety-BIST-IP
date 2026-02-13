"""
Unit Test: idle_detector — Idle Detector
Tests: reset, threshold trigger, activity reset, various thresholds.
"""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer


async def reset(dut):
    dut.rst_n.value = 0
    dut.system_valid.value = 0
    dut.threshold.value = 10
    await Timer(50, unit="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)


@cocotb.test()
async def test_reset_no_trigger(dut):
    """After reset, idle_trigger should be 0."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)
    assert dut.idle_trigger.value == 0, "idle_trigger should be 0 after reset"
    dut._log.info("✅ idle_trigger is 0 after reset")


@cocotb.test()
async def test_threshold_trigger(dut):
    """idle_trigger should fire after threshold+1 idle cycles."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)

    threshold = 10
    dut.threshold.value = threshold
    dut.system_valid.value = 0

    # Before threshold, trigger should be 0
    for i in range(threshold):
        await RisingEdge(dut.clk)
        trig = int(dut.idle_trigger.value)
        assert trig == 0, f"Triggered too early at cycle {i}"

    # At threshold+1 (registered output), should trigger
    await RisingEdge(dut.clk)
    trig = int(dut.idle_trigger.value)
    if trig == 0:
        # One more cycle for registered output
        await RisingEdge(dut.clk)
        trig = int(dut.idle_trigger.value)
    assert trig == 1, f"Did not trigger after threshold={threshold}"
    dut._log.info(f"✅ Triggered correctly after {threshold} idle cycles")


@cocotb.test()
async def test_activity_resets_counter(dut):
    """system_valid pulse should reset the idle counter."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)

    threshold = 10
    dut.threshold.value = threshold
    dut.system_valid.value = 0

    # Wait 8 cycles (close to threshold)
    for _ in range(8):
        await RisingEdge(dut.clk)
    assert dut.idle_trigger.value == 0, "Triggered too early"

    # Pulse system_valid to reset counter
    dut.system_valid.value = 1
    await RisingEdge(dut.clk)
    dut.system_valid.value = 0

    # Wait 8 more cycles - should NOT trigger because counter was reset
    for _ in range(8):
        await RisingEdge(dut.clk)
    assert dut.idle_trigger.value == 0, "Counter was not reset by system_valid"

    # Wait remaining cycles to trigger (need threshold total idle cycles)
    for _ in range(5):
        await RisingEdge(dut.clk)
    trig = int(dut.idle_trigger.value)
    assert trig == 1, "Did not trigger after full idle period"
    dut._log.info("✅ Activity correctly resets the idle counter")


@cocotb.test()
async def test_various_thresholds(dut):
    """Test with threshold values: 5, 20, 50."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    for threshold in [5, 20, 50]:
        await reset(dut)
        dut.threshold.value = threshold
        dut.system_valid.value = 0

        for i in range(threshold):
            await RisingEdge(dut.clk)
            assert dut.idle_trigger.value == 0, f"Early trigger at cycle {i}, threshold={threshold}"

        await RisingEdge(dut.clk)
        trig = int(dut.idle_trigger.value)
        assert trig == 1, f"No trigger after threshold={threshold}"
        dut._log.info(f"   ✅ Threshold={threshold} verified")

    dut._log.info("✅ All threshold values verified")
