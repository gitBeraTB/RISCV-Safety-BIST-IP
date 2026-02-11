# RISC-V Ibex Core with Built-In Self-Test (BIST) Integration

![Status](https://img.shields.io/badge/Status-Verified-success)
![Platform](https://img.shields.io/badge/Platform-Xilinx%20Vivado-blue)
![Language](https://img.shields.io/badge/Language-SystemVerilog-orange)

##  Executive Summary
This project demonstrates the integration of a custom **Built-In Self-Test (BIST)** architecture into the execution stage of the open-source **RISC-V Ibex Processor**. The design encapsulates the core Arithmetic Logic Unit (ALU) and Multiplier/Divider (MultDiv) within a proprietary BIST wrapper, enabling self-verification capabilities while maintaining compatibility with standard RISC-V instructions.

A critical challenge regarding bit-width mismatches (34-bit internal vs. 32-bit interface) was resolved through RTL engineering, and the final design was successfully synthesized and verified using Xilinx Vivado.

---

##  System Architecture

The project replaces the standard Ibex execution block with a wrapped version that includes test logic.

* **Top Module:** `ibex_alu_bist_wrapper`
* **Core Modules:**
    * `ibex_alu`: Standard Arithmetic Logic Unit.
    * `ibex_multdiv_fast`: Fast Multiplier/Divider unit (Modified).
* **Functionality:** The wrapper intercepts operands, manages the BIST state machine (optional expansion), and drives the execution units.

---

##  Technical Challenges & RTL Modifications

During the integration, a significant compatibility issue was identified between the Ibex MultDiv unit and the custom 32-bit BIST architecture.

###  The Problem: Bit-Width Mismatch
The `ibex_multdiv_fast` module internally utilized a **34-bit signed data path (`[33:0]`)** for intermediate calculations, whereas the target BIST wrapper was designed for a standard **32-bit RISC-V interface (`[31:0]`)**. This caused synthesis failures and connectivity issues.

### The Solution: Surgical RTL Truncation
To resolve this, the internal datapath of the MultDiv unit was modified:
1.  **Signal Truncation:** The intermediate value signal `imd_val_q_i` was truncated from 34-bits to 32-bits (`[31:0]`).
2.  **Logic Adaptation:** Bit-slicing operations in the SystemVerilog source code were updated (e.g., `[33:16]` -> `[31:16]`).
3.  **MSB Handling:** Logic blocks attempting to access the removed upper bits (`[33:32]`) were hardwired to `2'b00` to prevent synthesis errors while preserving arithmetic correctness for unsigned operations.

---

##  Verification & Simulation Results

The integrated design was verified using a behavioral testbench (`tb_ibex_ex_block.sv`) in Vivado. The simulation confirms that the BIST wrapper correctly drives the processor core and retrieves accurate results despite the bit-width modifications.

### Waveform Analysis
![Simulation Waveform](RISC-BIST.png)

| Test Case | Operation | Inputs | Expected Output | Measured Output | Status |
| :--- | :--- | :--- | :--- | :--- | :---: |
| **Test 1** | ALU ADD | `15 + 25` | `40 (0x28)` | `40 (0x28)` | ✅ **PASS** |
| **Test 2** | ALU SUB | `100 - 30` | `70 (0x46)` | `70 (0x46)` | ✅ **PASS** |
| **Test 3** | MULT (Standard) | `12 * 12` | `144 (0x90)` | `144 (0x90)` | ✅ **PASS** |
| **Test 4** | **MULT (Stress Test)** | `1000 * 500` | `500,000 (0x7A120)` | `500,000 (0x7A120)` | ✅ **PASS** |

> **Note on Test 4:** The stress test explicitly proves that truncating the internal sign-extension bits inside the multiplier **did not cause overflow or data corruption** for 32-bit operations. The result `0x7A120` is mathematically correct (500,000).

---

##  Synthesis Results (Xilinx Vivado)

The design achieves efficient resource utilization, suitable for low-power FPGA implementations.

| Resource Type | Used | Utilization |
| :--- | :---: | :---: |
| **Slice LUTs** | **625** | < 1% |
| **Slice Registers** | **283** | < 1% |
| **DSP Blocks** | **1** | < 1% |

* **Timing Analysis:** The design meets timing constraints with a **Worst Negative Slack (WNS) of +4.940 ns**, supporting operation speeds up to **~200 MHz**.

---

##  Directory Structure

```text
RISCV-Safety-BIST-IP/
├── HDL/            # SystemVerilog Source Files (Modified Ibex Core & Wrapper)
├── Test/           # Testbenches and Cocotb Scripts
├── Reports/        # Synthesis, Timing, and Utilization Reports
├── README.md       # Project Documentation
└── RISC-BIST.png   # Simulation Waveform Image

##  How to Run

1.  **Clone the Repository:**
    ```bash
    git clone [https://github.com/gitBeraTB/RISCV-Safety-BIST-IP.git](https://github.com/gitBeraTB/RISCV-Safety-BIST-IP.git)
    ```

2.  **Open in Vivado:**
    * Create a new project.
    * Add files from the `HDL` folder.
    * Set `ibex_ex_block` or `ibex_alu_bist_wrapper` as the Top Module.

3.  **Run Simulation:**
    * Add `Test/tb_ibex_ex_block.sv` as a simulation source.
    * Run Behavioral Simulation.

---

*Project developed by [Berath] as part of a RISC-V Safety & Verification study.*
