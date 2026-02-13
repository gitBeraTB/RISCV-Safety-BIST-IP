"""
Unit Test: misr_analyzer — MISR Signature Analyzer
Tests: reset, clear, determinism, different inputs, single-bit sensitivity.
"""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer


async def reset(dut):
    dut.rst_n.value = 0
    dut.enable.value = 0
    dut.clear.value = 0
    dut.dut_response.value = 0
    await Timer(50, unit="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)


@cocotb.test()
async def test_reset_zero(dut):
    """After reset, signature should be 0."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)
    sig = dut.signature.value.to_unsigned()
    assert sig == 0, f"Signature after reset: 0x{sig:08X} != 0"
    dut._log.info("✅ Signature is 0 after reset")


@cocotb.test()
async def test_clear(dut):
    """Clear should reset signature to 0 after processing data."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)

    # Feed some data
    dut.enable.value = 1
    for i in range(10):
        dut.dut_response.value = (i + 1) * 0x11111111
        await RisingEdge(dut.clk)

    sig_before = dut.signature.value.to_unsigned()
    assert sig_before != 0, "Signature should be non-zero after processing data"

    # Clear
    dut.enable.value = 0
    dut.clear.value = 1
    await RisingEdge(dut.clk)
    dut.clear.value = 0
    await RisingEdge(dut.clk)

    sig_after = dut.signature.value.to_unsigned()
    assert sig_after == 0, f"Signature after clear: 0x{sig_after:08X} != 0"
    dut._log.info("✅ Clear resets signature to 0")


@cocotb.test()
async def test_deterministic(dut):
    """Same input sequence should produce the same signature every time."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    test_data = [0xAAAA_BBBB, 0x1234_5678, 0xDEAD_BEEF, 0x0000_FFFF, 0x8000_0001]
    signatures = []

    for run in range(2):
        await reset(dut)
        dut.enable.value = 1
        for d in test_data:
            dut.dut_response.value = d
            await RisingEdge(dut.clk)
        dut.enable.value = 0
        await RisingEdge(dut.clk)
        signatures.append(dut.signature.value.to_unsigned())

    assert signatures[0] == signatures[1], \
        f"Non-deterministic: 0x{signatures[0]:08X} != 0x{signatures[1]:08X}"
    dut._log.info(f"✅ Deterministic signature: 0x{signatures[0]:08X}")


@cocotb.test()
async def test_different_inputs(dut):
    """Different input sequences should produce different signatures."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    sequences = [
        [0x1111_1111, 0x2222_2222, 0x3333_3333],
        [0x4444_4444, 0x5555_5555, 0x6666_6666],
        [0x1111_1111, 0x2222_2222, 0x3333_3334],  # Only last value differs
    ]
    sigs = []
    for seq in sequences:
        await reset(dut)
        dut.enable.value = 1
        for d in seq:
            dut.dut_response.value = d
            await RisingEdge(dut.clk)
        dut.enable.value = 0
        await RisingEdge(dut.clk)
        sigs.append(dut.signature.value.to_unsigned())

    assert len(set(sigs)) == len(sigs), f"Signatures not all unique: {[hex(s) for s in sigs]}"
    dut._log.info(f"✅ All {len(sigs)} different sequences produce unique signatures")


@cocotb.test()
async def test_single_bit_sensitivity(dut):
    """Flipping a single bit in input should change the signature."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    base_data = [0xAAAA_AAAA, 0x5555_5555, 0x1234_5678]
    sigs = []

    for flip_bit in [None, 0, 15, 31]:
        await reset(dut)
        dut.enable.value = 1
        for i, d in enumerate(base_data):
            if flip_bit is not None and i == 1:
                d ^= (1 << flip_bit)
            dut.dut_response.value = d
            await RisingEdge(dut.clk)
        dut.enable.value = 0
        await RisingEdge(dut.clk)
        sigs.append(dut.signature.value.to_unsigned())

    # All should be different
    assert len(set(sigs)) == len(sigs), \
        f"Single-bit flips didn't all produce unique signatures: {[hex(s) for s in sigs]}"
    dut._log.info("✅ Single-bit sensitivity verified")
