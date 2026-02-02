import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, Event
from cocotb.utils import get_sim_time
import random

# Try importing matplotlib for graphing (Optional)
try:
    import matplotlib.pyplot as plt
    PLOT_AVAILABLE = True
except ImportError:
    PLOT_AVAILABLE = False

# --- ANSI COLOR CODES (For Python Terminal) ---
class Colors:
    HEADER = '\033[95m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    GREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'

# -----------------------------------------------------------------------------
# 1. DRIVER CLASSES (Stimulus Generators)
# -----------------------------------------------------------------------------

class APBDriver:
    """Handles Register Configuration via APB Protocol"""
    def __init__(self, dut):
        self.dut = dut
        self.log = dut._log

    async def write(self, addr, data):
        self.dut.paddr.value = addr
        self.dut.psel.value = 1
        self.dut.pwrite.value = 1
        self.dut.pwdata.value = data
        self.dut.penable.value = 0
        await RisingEdge(self.dut.clk)
        self.dut.penable.value = 1
        await RisingEdge(self.dut.clk)
        self.dut.psel.value = 0
        self.dut.penable.value = 0
        self.dut.pwrite.value = 0
        
        self.log.info(f"{Colors.BLUE}[APB WRITE] Addr: 0x{addr:02X} Data: {data} (0x{data:X}){Colors.ENDC}")

    async def read(self, addr):
        self.dut.paddr.value = addr
        self.dut.psel.value = 1
        self.dut.pwrite.value = 0
        self.dut.penable.value = 0
        await RisingEdge(self.dut.clk)
        self.dut.penable.value = 1
        await RisingEdge(self.dut.clk)
        data = self.dut.prdata.value
        self.dut.psel.value = 0
        self.dut.penable.value = 0
        return data

class SystemDriver:
    """Simulates the Main Processor sending data to ALU"""
    def __init__(self, dut):
        self.dut = dut
    
    async def send_traffic(self, a, b):
        """Injects valid data packet"""
        self.dut.sys_req_valid.value = 1
        self.dut.sys_data_a.value = a
        self.dut.sys_data_b.value = b
        await RisingEdge(self.dut.clk)
        
    async def go_idle(self):
        """Stops sending data"""
        self.dut.sys_req_valid.value = 0
        # Wait is handled by main loop

# -----------------------------------------------------------------------------
# 2. MONITOR & SCOREBOARD CLASS (Checker & Logger)
# -----------------------------------------------------------------------------
class MonitorAndScoreboard:
    def __init__(self, dut):
        self.dut = dut
        self.log = dut._log
        self.history = {
            'time': [],
            'sys_req': [],
            'bist_active': [],
            'alu_output': []
        }
        self.errors = 0

    async def run_monitor(self, stop_event):
        """Background task to record signals for plotting"""
        self.log.info(f"{Colors.CYAN}[MONITOR] Signal Logging Started...{Colors.ENDC}")
        while not stop_event.is_set():
            await RisingEdge(self.dut.clk)
            
            # DÜZELTME 1: units='ns' yerine unit='ns' (Deprecation Warning için)
            t = get_sim_time(unit='ns')
            
            req = 1 if self.dut.sys_req_valid.value == 1 else 0
            
            try:
                active = 1 if self.dut.bist_active.value == 1 else 0
            except AttributeError:
                # Eğer sinyal bulunamazsa (bazen Icarus internal sinyalleri gizler) 0 varsayalım
                active = 0 
            
            self.history['time'].append(t)
            self.history['sys_req'].append(req)
            self.history['bist_active'].append(active)

    def generate_plot(self):
        """Generates the waveform image using Matplotlib"""
        if not PLOT_AVAILABLE:
            self.log.warning("[REPORT] Matplotlib not installed. Skipping graph.")
            return

        self.log.info(f"{Colors.HEADER}[REPORT] Generating Timing Graph...{Colors.ENDC}")
        
        fig, (ax1, ax2) = plt.subplots(2, 1, sharex=True, figsize=(10, 6))
        
        # Plot 1: System Request
        ax1.step(self.history['time'], self.history['sys_req'], where='post', color='tab:blue', label='System Request')
        ax1.set_ylabel('Logic Level')
        ax1.set_title('System Activity (Process Valid)')
        ax1.grid(True, alpha=0.3)
        ax1.set_yticks([0, 1])

        # Plot 2: BIST Status
        ax2.step(self.history['time'], self.history['bist_active'], where='post', color='tab:red', label='BIST Active')
        ax2.set_ylabel('Logic Level')
        ax2.set_xlabel('Time (ns)')
        ax2.set_title('BIST Status (Internal Test Mode)')
        ax2.grid(True, alpha=0.3)
        ax2.set_yticks([0, 1])
        
        # Highlight Danger Zones (Where both are 1 - Should happen only for 1 cycle before abort)
        # Using fill_between logic could be added here for advanced analysis

        plt.savefig("bist_verification_result.png")
        self.log.info(f"{Colors.GREEN}[REPORT] Graph saved as 'bist_verification_result.png'{Colors.ENDC}")

# -----------------------------------------------------------------------------
# 3. MAIN TEST SEQUENCE
# -----------------------------------------------------------------------------

@cocotb.test()
async def test_professional_scenario(dut):
    """
    Full Verification Suite:
    1. Configuration
    2. Random Traffic (System Mode)
    3. Auto-BIST Entry (Idle Mode)
    4. Safety Interrupt Check (Abort Mode)
    """
    
    # --- Setup ---
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    
    apb = APBDriver(dut)
    sys_drv = SystemDriver(dut)
    sb = MonitorAndScoreboard(dut)
    
    # Start Monitor Thread
    stop_monitor = Event()
    cocotb.start_soon(sb.run_monitor(stop_monitor))

    # Reset
    dut.rst_n.value = 0
    dut.sys_req_valid.value = 0
    await Timer(50, unit="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut._log.info(f"{Colors.HEADER}======================================{Colors.ENDC}")
    dut._log.info(f"{Colors.HEADER}   STARTING PROFESSIONAL VERIFICATION {Colors.ENDC}")
    dut._log.info(f"{Colors.HEADER}======================================{Colors.ENDC}")

    # --- Phase 1: Configuration ---
    # Set Idle Threshold to 10 clock cycles
    await apb.write(0x08, 10) 
    # Enable BIST
    await apb.write(0x00, 1)

    # --- Phase 2: Random Traffic (System Dominance) ---
    dut._log.info(f"\n{Colors.CYAN}[PHASE 1] Generating Random System Traffic...{Colors.ENDC}")
    for i in range(5):
        a = random.randint(0, 100)
        b = random.randint(0, 100)
        await sys_drv.send_traffic(a, b)
        
        # Simple Check
        res = dut.sys_result_out.value.to_unsigned()
        if res != (a+b):
            dut._log.error(f"{Colors.FAIL}ALU ERROR! Exp: {a+b} Got: {res}{Colors.ENDC}")
            sb.errors += 1
            
    # --- Phase 3: Go Idle & Wait for BIST ---
    dut._log.info(f"\n{Colors.CYAN}[PHASE 2] System Going Idle. Expecting BIST to take over...{Colors.ENDC}")
    await sys_drv.go_idle()
    
    # Wait enough time for: Threshold (10) + Some Test Cycles
    await Timer(200, unit="ns")
    
    # Verify BIST is running via APB Status Read
    status = await apb.read(0x04)
    status_int = status.to_unsigned()
    
    if status_int & 1: # Bit 0 is Busy
        dut._log.info(f"{Colors.GREEN}[CHECK] BIST is officially RUNNING (Status: 0x{status_int:X}){Colors.ENDC}")
    else:
        dut._log.error(f"{Colors.FAIL}[CHECK] BIST failed to start! (Status: 0x{status_int:X}){Colors.ENDC}")
        sb.errors += 1

    # --- Phase 4: The SAFETY Test (Interruption) ---
    dut._log.info(f"\n{Colors.WARNING}[PHASE 3] INJECTING EMERGENCY INTERRUPTION!{Colors.ENDC}")
    
    # Force traffic while BIST is running
    critical_a = 0xAAAA
    critical_b = 0x5555
    await sys_drv.send_traffic(critical_a, critical_b)
    
    # Wait 2 cycles for MUX switch and Pipeline
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Check output immediately
    final_res = dut.sys_result_out.value.to_unsigned()
    expected = critical_a + critical_b
    
    if final_res == expected:
        dut._log.info(f"{Colors.GREEN}[PASS] Safety Mechanism Worked! Output: 0x{final_res:X}{Colors.ENDC}")
    else:
        dut._log.error(f"{Colors.FAIL}[FAIL] Safety Violation! BIST blocked the bus. Output: 0x{final_res:X}{Colors.ENDC}")
        sb.errors += 1

    # --- Teardown ---
    stop_monitor.set() # Stop recording
    sb.generate_plot() # Save PNG
    
    dut._log.info(f"{Colors.HEADER}======================================{Colors.ENDC}")
    if sb.errors == 0:
        dut._log.info(f"{Colors.GREEN}       TEST SUITE PASSED ✅ {Colors.ENDC}")
    else:
        dut._log.error(f"{Colors.FAIL}       TEST SUITE FAILED ({sb.errors} Errors) ❌ {Colors.ENDC}")
    dut._log.info(f"{Colors.HEADER}======================================{Colors.ENDC}")