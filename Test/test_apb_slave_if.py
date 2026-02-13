"""
Unit Test: apb_slave_if — APB Slave Interface
Tests: write transaction, read transaction, pready always high, address decoding.
"""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer


async def reset(dut):
    dut.rst_n.value = 0
    dut.paddr.value = 0
    dut.psel.value = 0
    dut.penable.value = 0
    dut.pwrite.value = 0
    dut.pwdata.value = 0
    dut.reg_rdata.value = 0
    await Timer(50, unit="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)


async def apb_write(dut, addr, data):
    """Perform an APB write transaction (Setup + Access)."""
    # Setup phase
    dut.paddr.value = addr
    dut.psel.value = 1
    dut.pwrite.value = 1
    dut.pwdata.value = data
    dut.penable.value = 0
    await RisingEdge(dut.clk)
    # Access phase
    dut.penable.value = 1
    await RisingEdge(dut.clk)
    # Cleanup
    dut.psel.value = 0
    dut.penable.value = 0
    dut.pwrite.value = 0


async def apb_read(dut, addr):
    """Perform an APB read transaction and return prdata."""
    dut.paddr.value = addr
    dut.psel.value = 1
    dut.pwrite.value = 0
    dut.penable.value = 0
    await RisingEdge(dut.clk)
    dut.penable.value = 1
    await RisingEdge(dut.clk)
    data = dut.prdata.value.to_unsigned()
    dut.psel.value = 0
    dut.penable.value = 0
    return data


@cocotb.test()
async def test_write_transaction(dut):
    """APB write should assert reg_write_en and pass correct data/addr."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)

    # Setup phase
    dut.paddr.value = 0x08
    dut.psel.value = 1
    dut.pwrite.value = 1
    dut.pwdata.value = 0xCAFE_BABE
    dut.penable.value = 0
    await RisingEdge(dut.clk)

    # Access phase
    dut.penable.value = 1
    await RisingEdge(dut.clk)

    # Check outputs
    we = int(dut.reg_write_en.value)
    wdata = dut.reg_wdata.value.to_unsigned()
    addr = dut.reg_addr.value.to_unsigned()

    assert we == 1, f"reg_write_en not asserted: {we}"
    assert wdata == 0xCAFE_BABE, f"reg_wdata mismatch: 0x{wdata:08X}"
    assert addr == 0x08, f"reg_addr mismatch: 0x{addr:02X}"

    dut.psel.value = 0
    dut.penable.value = 0
    dut._log.info("✅ Write transaction verified")


@cocotb.test()
async def test_read_transaction(dut):
    """APB read should assert reg_read_en and return reg_rdata on prdata."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)

    # Set register read data
    test_val = 0xBEEF_DEAD
    dut.reg_rdata.value = test_val

    data = await apb_read(dut, 0x04)
    assert data == test_val, f"Read data mismatch: 0x{data:08X} != 0x{test_val:08X}"
    dut._log.info(f"✅ Read transaction verified: 0x{data:08X}")


@cocotb.test()
async def test_pready_always_high(dut):
    """pready should always be 1 (no wait states)."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)

    for _ in range(20):
        await RisingEdge(dut.clk)
        assert dut.pready.value == 1, "pready is not always high"

    dut._log.info("✅ pready always high (no wait states)")


@cocotb.test()
async def test_address_decoding(dut):
    """reg_addr should be lower 8 bits of paddr."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)

    test_addrs = [0x00, 0x04, 0x08, 0x0C, 0x10, 0xFF, 0x100, 0xABCD_00FC]
    for full_addr in test_addrs:
        dut.paddr.value = full_addr
        dut.psel.value = 1
        await RisingEdge(dut.clk)
        decoded = dut.reg_addr.value.to_unsigned()
        expected = full_addr & 0xFF
        assert decoded == expected, \
            f"Address 0x{full_addr:08X}: decoded 0x{decoded:02X} != expected 0x{expected:02X}"
        dut.psel.value = 0

    dut._log.info("✅ Address decoding verified for all test cases")
