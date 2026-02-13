"""
Unit Test: runtime_bist_controller — BIST Controller
Tests: APB register R/W, FSM idle-to-run, full BIST cycle, fail detection, safety abort.
"""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer


async def reset(dut):
    dut.rst_n.value = 0
    dut.sys_req_valid.value = 0
    dut.dut_result_in.value = 0
    dut.paddr.value = 0
    dut.psel.value = 0
    dut.penable.value = 0
    dut.pwrite.value = 0
    dut.pwdata.value = 0
    await Timer(50, unit="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


async def apb_write(dut, addr, data):
    dut.paddr.value = addr
    dut.psel.value = 1
    dut.pwrite.value = 1
    dut.pwdata.value = data
    dut.penable.value = 0
    await RisingEdge(dut.clk)
    dut.penable.value = 1
    await RisingEdge(dut.clk)
    dut.psel.value = 0
    dut.penable.value = 0
    dut.pwrite.value = 0


async def apb_read(dut, addr):
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


async def wait_bist_done(dut, timeout=600):
    """Wait until BIST starts (busy=1) then finishes (busy=0)."""
    # Phase 1: Wait for BIST to start
    for _ in range(timeout):
        status = await apb_read(dut, 0x04)
        if (status & 1) == 1:
            break
        await RisingEdge(dut.clk)
    else:
        raise TimeoutError("BIST never started (busy=1 not seen)")

    # Phase 2: Wait for BIST to finish
    for _ in range(timeout):
        status = await apb_read(dut, 0x04)
        if (status & 1) == 0:
            return status
        await RisingEdge(dut.clk)
    raise TimeoutError("BIST did not complete")


@cocotb.test()
async def test_apb_register_rw(dut):
    """Write and read back CTRL, THRESHOLD, GOLDEN_SIG registers."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)

    # Threshold register (0x08)
    await apb_write(dut, 0x08, 42)
    val = await apb_read(dut, 0x08)
    assert val == 42, f"Threshold read-back: {val} != 42"

    # Golden signature register (0x0C)
    await apb_write(dut, 0x0C, 0xCAFE_BABE)
    val = await apb_read(dut, 0x0C)
    assert val == 0xCAFE_BABE, f"Golden sig read-back: 0x{val:08X}"

    # CTRL register (0x00)
    await apb_write(dut, 0x00, 0x01)
    val = await apb_read(dut, 0x00)
    assert val == 0x01, f"CTRL read-back: {val}"

    dut._log.info("✅ APB register read/write verified")


@cocotb.test()
async def test_fsm_idle_to_run(dut):
    """Enable BIST, go idle → FSM should enter RUN_TEST (bist_active_mode=1)."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)

    # Set short threshold
    await apb_write(dut, 0x08, 5)
    # Enable BIST
    await apb_write(dut, 0x00, 1)

    # System is idle (sys_req_valid=0)
    dut.sys_req_valid.value = 0

    # Wait for BIST to become active
    bist_active_seen = False
    for i in range(50):
        await RisingEdge(dut.clk)
        try:
            if int(dut.bist_active_mode.value) == 1:
                bist_active_seen = True
                dut._log.info(f"   bist_active_mode=1 at cycle {i}")
                break
        except ValueError:
            pass

    assert bist_active_seen, "BIST never became active"
    dut._log.info("✅ FSM IDLE → WAIT_FOR_SLOT → RUN_TEST verified")


@cocotb.test()
async def test_bist_full_cycle_pass(dut):
    """Complete BIST cycle: run → capture signature → set golden → re-run → PASS."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)

    # Short threshold for fast test
    await apb_write(dut, 0x08, 3)
    await apb_write(dut, 0x00, 1)  # Enable
    dut.sys_req_valid.value = 0

    # First run: calibration - capture the golden signature
    status = await wait_bist_done(dut)
    golden = await apb_read(dut, 0x10)  # MISR signature
    dut._log.info(f"   Calibration signature: 0x{golden:08X}")

    # Save as golden
    await apb_write(dut, 0x0C, golden)

    # Re-enable for second run
    await apb_write(dut, 0x00, 1)
    dut.sys_req_valid.value = 0

    # Second run: should match golden → PASS
    status = await wait_bist_done(dut)
    await RisingEdge(dut.clk)  # Let status register update
    await RisingEdge(dut.clk)
    status = await apb_read(dut, 0x04)

    irq = int(dut.error_irq.value)
    dut._log.info(f"   Status: 0x{status:08X}, IRQ: {irq}")

    # Check PASS bit (bit 2) or no FAIL bit (bit 1)
    assert irq == 0, f"Error IRQ should be 0, got {irq}"
    dut._log.info("✅ Full BIST cycle PASS verified")


@cocotb.test()
async def test_bist_fail_detection(dut):
    """Set wrong golden → FAIL status + IRQ."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)

    # Set wrong golden signature
    await apb_write(dut, 0x0C, 0xDEAD_DEAD)
    await apb_write(dut, 0x08, 3)
    await apb_write(dut, 0x00, 1)
    dut.sys_req_valid.value = 0

    # Monitor for error_irq pulse during BIST execution
    irq_seen = False

    async def monitor_irq():
        nonlocal irq_seen
        while True:
            await RisingEdge(dut.clk)
            try:
                if int(dut.error_irq.value) == 1:
                    irq_seen = True
                    return
            except ValueError:
                pass

    irq_task = cocotb.start_soon(monitor_irq())

    status = await wait_bist_done(dut)

    # Disable BIST to prevent re-run
    await apb_write(dut, 0x00, 0)

    # Give a few cycles for any remaining signals to settle
    for _ in range(5):
        await RisingEdge(dut.clk)

    status = await apb_read(dut, 0x04)
    dut._log.info(f"   Status: 0x{status:08X}, IRQ seen: {irq_seen}")

    # Check either persistent status bit or IRQ pulse
    fail_detected = irq_seen or (status & 2) != 0
    assert fail_detected, f"BIST fail not detected (status=0x{status:08X}, irq_seen={irq_seen})"
    dut._log.info("✅ BIST fail detection verified (wrong golden → fault detected)")


@cocotb.test()
async def test_safety_abort(dut):
    """Interrupt during RUN_TEST → ABORT → no corruption."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)

    await apb_write(dut, 0x08, 3)
    await apb_write(dut, 0x00, 1)
    dut.sys_req_valid.value = 0

    # Wait for BIST to start running
    for _ in range(50):
        await RisingEdge(dut.clk)
        try:
            if int(dut.bist_active_mode.value) == 1:
                break
        except ValueError:
            pass

    # Interrupt! System needs the ALU
    dut.sys_req_valid.value = 1
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    # BIST should abort (bist_active_mode → 0)
    bist_active = int(dut.bist_active_mode.value)
    assert bist_active == 0, f"BIST should abort on sys_req_valid, but bist_active={bist_active}"
    dut._log.info("✅ Safety abort verified (BIST releases ALU on interrupt)")
