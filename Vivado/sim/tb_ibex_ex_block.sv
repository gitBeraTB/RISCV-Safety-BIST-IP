`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Vivado-Native Testbench for ibex_ex_block
// Uses packed arrays matching Vivado port declarations.
//////////////////////////////////////////////////////////////////////////////////

module tb_ibex_ex_block;

  // -------------------------------------------------------------------------
  // 1. Parameters and Signals
  // -------------------------------------------------------------------------
  import ibex_pkg::*;

  // Clock and Reset
  logic clk_i;
  logic rst_ni;

  // Inputs
  logic [31:0] alu_operand_a_i;
  logic [31:0] alu_operand_b_i;
  alu_op_e     alu_operator_i;
  logic        alu_instr_first_cycle_i;

  logic [31:0] multdiv_operand_a_i;
  logic [31:0] multdiv_operand_b_i;
  md_op_e      multdiv_operator_i;
  logic        mult_en_i;
  logic        div_en_i;
  logic        mult_sel_i;
  logic        div_sel_i;
  logic [1:0]  multdiv_signed_mode_i;
  logic        multdiv_ready_id_i;
  logic        data_ind_timing_i;

  // Vivado-Native: Packed array for Intermediate Value Loopback
  logic [1:0][31:0] imd_val_q_i;
  logic [1:0][31:0] imd_val_d_o;
  logic [1:0]       imd_val_we_o;

  // Outputs
  logic [31:0] result_ex_o;
  logic        ex_valid_o;
  logic        branch_decision_o;

  // Other (unused, tied to 0)
  logic core_sleep_i = 0;
  logic sim_fault_inject_i = 0;
  logic [31:0] paddr_i = 0;
  logic psel_i = 0;
  logic penable_i = 0;
  logic pwrite_i = 0;
  logic [31:0] pwdata_i = 0;
  logic [31:0] bt_a_operand_i = 0;
  logic [31:0] bt_b_operand_i = 0;

  // -------------------------------------------------------------------------
  // 2. DUT Instantiation (Vivado-Native packed array ports)
  // -------------------------------------------------------------------------
  ibex_ex_block #(
    .RV32M(RV32MFast),
    .RV32B(RV32BNone)
  ) u_dut (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    
    // ALU
    .alu_operator_i(alu_operator_i),
    .alu_operand_a_i(alu_operand_a_i),
    .alu_operand_b_i(alu_operand_b_i),
    .alu_instr_first_cycle_i(alu_instr_first_cycle_i),
    
    // MultDiv
    .multdiv_operator_i(multdiv_operator_i),
    .mult_sel_i(mult_sel_i),
    .div_en_i(div_en_i),
    .div_sel_i(div_sel_i),
    .multdiv_signed_mode_i(multdiv_signed_mode_i),
    .multdiv_operand_a_i(multdiv_operand_a_i),
    .multdiv_operand_b_i(multdiv_operand_b_i),
    .multdiv_ready_id_i(multdiv_ready_id_i),
    .data_ind_timing_i(data_ind_timing_i),
    
    // Vivado-Native: Direct packed array connection
    .imd_val_q_i(imd_val_q_i),
    .imd_val_d_o(imd_val_d_o),
    .imd_val_we_o(imd_val_we_o),
    
    // Outputs
    .result_ex_o(result_ex_o),
    .ex_valid_o(ex_valid_o),
    .branch_decision_o(branch_decision_o),
    
    // Other connections
    .core_sleep_i(core_sleep_i),
    .sim_fault_inject_i(sim_fault_inject_i),
    .bist_error_irq_o(),
    .paddr_i(paddr_i), .psel_i(psel_i), .penable_i(penable_i), 
    .pwrite_i(pwrite_i), .pwdata_i(pwdata_i), .prdata_o(), .pready_o(),
    .bt_a_operand_i(bt_a_operand_i), .bt_b_operand_i(bt_b_operand_i),
    .branch_target_o(),
    .alu_adder_result_ex_o()
  );

  // -------------------------------------------------------------------------
  // 3. Clock Generation & IMD Loopback
  // -------------------------------------------------------------------------
  
  // 10ns Clock (100 MHz)
  always #5 clk_i = ~clk_i;

  // IMD Register Loopback (Multi-cycle multiply needs memory)
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      imd_val_q_i <= '{default: '0};
    end else begin
      if (imd_val_we_o[0]) imd_val_q_i[0] <= imd_val_d_o[0];
      if (imd_val_we_o[1]) imd_val_q_i[1] <= imd_val_d_o[1];
    end
  end

  // -------------------------------------------------------------------------
  // 4. TEST SCENARIOS
  // -------------------------------------------------------------------------
  integer pass_count = 0;
  integer fail_count = 0;
  
  initial begin
    // Initial values
    clk_i = 0;
    rst_ni = 0;
    alu_operand_a_i = 0; alu_operand_b_i = 0;
    multdiv_operand_a_i = 0; multdiv_operand_b_i = 0;
    mult_en_i = 0; div_en_i = 0;
    mult_sel_i = 0; div_sel_i = 0;
    alu_instr_first_cycle_i = 0;
    multdiv_ready_id_i = 1;
    data_ind_timing_i = 0;
    multdiv_signed_mode_i = 2'b00;

    $display("========================================");
    $display(" VIVADO BIST SIMULATION STARTING");
    $display("========================================");
    
    // Release reset
    #20 rst_ni = 1;
    #10;

    // --- TEST 1: ALU ADD (15 + 25 = 40) ---
    $display("\nTEST 1: ALU ADD (15 + 25)");
    alu_operator_i = ALU_ADD;
    alu_operand_a_i = 32'd15;
    alu_operand_b_i = 32'd25;
    mult_sel_i = 0;
    
    #10;
    if (result_ex_o == 32'd40) begin
      $display("  -> PASS: Result = %d", result_ex_o);
      pass_count++;
    end else begin
      $display("  -> FAIL: Expected 40, Got %d", result_ex_o);
      fail_count++;
    end

    // --- TEST 2: ALU SUB (100 - 30 = 70) ---
    #20;
    $display("\nTEST 2: ALU SUB (100 - 30)");
    alu_operator_i = ALU_SUB;
    alu_operand_a_i = 32'd100;
    alu_operand_b_i = 32'd30;
    
    #10;
    if (result_ex_o == 32'd70) begin
      $display("  -> PASS: Result = %d", result_ex_o);
      pass_count++;
    end else begin
      $display("  -> FAIL: Expected 70, Got %d", result_ex_o);
      fail_count++;
    end

    // --- TEST 3: MULT (12 * 12 = 144) ---
    #20;
    $display("\nTEST 3: MULT (12 x 12)");
    
    multdiv_operator_i = MD_OP_MULL;
    multdiv_operand_a_i = 32'd12;
    multdiv_operand_b_i = 32'd12;
    multdiv_signed_mode_i = 2'b00;
    
    mult_en_i = 1;
    mult_sel_i = 1;
    
    wait(ex_valid_o == 1);
    
    if (result_ex_o == 32'd144) begin
      $display("  -> PASS: Result = %d", result_ex_o);
      pass_count++;
    end else begin
      $display("  -> FAIL: Expected 144, Got %d", result_ex_o);
      fail_count++;
    end

    mult_en_i = 0;

    // --- TEST 4: LARGE MULT (1000 * 500 = 500000) ---
    #40;
    $display("\nTEST 4: LARGE MULT (1000 x 500)");
    
    multdiv_operand_a_i = 32'd1000;
    multdiv_operand_b_i = 32'd500;
    mult_en_i = 1;
    
    wait(ex_valid_o == 0);
    wait(ex_valid_o == 1);

    if (result_ex_o == 32'd500000) begin
      $display("  -> PASS: Result = %d", result_ex_o);
      pass_count++;
    end else begin
      $display("  -> FAIL: Expected 500000, Got %d", result_ex_o);
      fail_count++;
    end

    $display("\n========================================");
    $display(" RESULTS: %0d PASSED, %0d FAILED", pass_count, fail_count);
    $display("========================================");
    $finish;
  end

endmodule
