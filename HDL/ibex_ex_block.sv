// Copyright lowRISC contributors.
// Copyright 2018 ETH Zurich and University of Bologna, see also CREDITS.md.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

/**
 * Execution stage
 *
 * Execution block: Hosts ALU and MUL/DIV unit
 */
// ICARUS FIX: Import en tepede
import ibex_pkg::*;

module ibex_ex_block #(
    parameter RV32M                    = 2,
    parameter RV32B                    = 0,
    parameter MultiplierImplementation = 0,
    parameter BranchTargetALU          = 0
) (
  input  logic                  clk_i,
  input  logic                  rst_ni,

  input  logic [6:0]            alu_operator_i,
  input  logic [31:0]           alu_operand_a_i,
  input  logic [31:0]           alu_operand_b_i,
  input  logic                  alu_instr_first_cycle_i,

  input  logic [1:0]            multdiv_operator_i,
  input  logic                  div_en_i,
  input  logic                  mult_sel_i,
  input  logic                  div_sel_i,
  input  logic [1:0]            multdiv_signed_mode_i,
  input  logic [31:0]           multdiv_operand_a_i,
  input  logic [31:0]           multdiv_operand_b_i,
  input  logic                  multdiv_ready_id_i,
  input  logic                  data_ind_timing_i,

  input  logic [31:0]           bt_a_operand_i,
  input  logic [31:0]           bt_b_operand_i,

  // ICARUS FIX: Modul portlarini da duzlestirdik!
  output logic [1:0]            imd_val_we_o,
  output logic [31:0]           imd_val_d_o_0,
  output logic [31:0]           imd_val_d_o_1,
  input  logic [31:0]           imd_val_q_i_0,
  input  logic [31:0]           imd_val_q_i_1,

  output logic [31:0]           alu_adder_result_ex_o,  
  output logic [31:0]           result_ex_o,
  output logic [31:0]           branch_target_o,        
  output logic                  branch_decision_o,      
  output logic                  ex_valid_o,

  // Dummy ports
  input  logic                  core_sleep_i, 
  input  logic                  sim_fault_inject_i, 
  output logic                  bist_error_irq_o,
  input  logic [31:0]           paddr_i,
  input  logic                  psel_i,
  input  logic                  penable_i,
  input  logic                  pwrite_i,
  input  logic [31:0]           pwdata_i,
  output logic [31:0]           prdata_o,
  output logic                  pready_o
);

  assign bist_error_irq_o = 1'b0;
  assign prdata_o         = 32'b0;
  assign pready_o         = 1'b0;

  logic [31:0] alu_result, multdiv_result;
  logic        multdiv_sel;

  assign multdiv_sel = mult_sel_i | div_sel_i;

  // Internal Signals (Flat)
  logic [31:0] alu_imd_val_d_0, alu_imd_val_d_1;
  logic [33:0] multdiv_imd_val_d_0, multdiv_imd_val_d_1;
  logic [1:0]  alu_imd_val_we, multdiv_imd_val_we;

  // -------------------------
  // ALU
  // -------------------------
  ibex_alu #(
    .RV32B(RV32B)
  ) alu_i (
    .clk_i              (clk_i),
    .rst_ni             (rst_ni),
    .operator_i         (alu_operator_i),
    .operand_a_i        (alu_operand_a_i),
    .operand_b_i        (alu_operand_b_i),
    .instr_first_cycle_i(alu_instr_first_cycle_i),
    
    // YENI BAGLANTILAR
    .imd_val_q_i_0      (imd_val_q_i_0),
    .imd_val_q_i_1      (imd_val_q_i_1),
    .imd_val_d_o_0      (alu_imd_val_d_0),
    .imd_val_d_o_1      (alu_imd_val_d_1),
    
    .imd_val_we_o       (alu_imd_val_we),
    .multdiv_operand_a_i(multdiv_operand_a_i),
    .multdiv_operand_b_i(multdiv_operand_b_i),
    .multdiv_sel_i      (multdiv_sel),
    .adder_result_o     (alu_adder_result_ex_o),
    .adder_result_ext_o (),
    .result_o           (alu_result),
    .comparison_result_o(),
    .is_equal_result_o  ()
  );

  // -------------------------
  // Multiplier / Divider
  // -------------------------
  if (MultiplierImplementation == 0) begin : gen_multdiv_fast
    ibex_multdiv_fast #(
      .RV32M(RV32M)
    ) multdiv_i (
      .clk_i             (clk_i),
      .rst_ni            (rst_ni),
      .mult_en_i         (mult_sel_i),
      .div_en_i          (div_sel_i),
      .mult_sel_i        (mult_sel_i),
      .div_sel_i         (div_sel_i),
      .operator_i        (multdiv_operator_i),
      .signed_mode_i     (multdiv_signed_mode_i),
      .op_a_i            (multdiv_operand_a_i),
      .op_b_i            (multdiv_operand_b_i),
      .alu_adder_ext_i   (32'b0),
      .alu_adder_i       (32'b0),
      .equal_to_zero_i   (1'b0),
      .data_ind_timing_i (data_ind_timing_i),
      .alu_operand_a_o   (),
      .alu_operand_b_o   (),
      .multdiv_result_o  (multdiv_result),
      .valid_o           (),
      .multdiv_ready_id_o(),
      
      // YENI BAGLANTILAR
      // Girisler (Zero extended 34 bit)
      .imd_val_q_i_0     ({2'b0, imd_val_q_i_0}),
      .imd_val_q_i_1     ({2'b0, imd_val_q_i_1}),
      .imd_val_d_o_0     (multdiv_imd_val_d_0),
      .imd_val_d_o_1     (multdiv_imd_val_d_1),
      .imd_val_we_o      (multdiv_imd_val_we)
    );
  end else begin : gen_multdiv_slow
      assign multdiv_result = 32'b0;
      assign multdiv_imd_val_d_0 = 34'b0;
      assign multdiv_imd_val_d_1 = 34'b0;
      assign multdiv_imd_val_we = 2'b0;
  end

  // -------------------------
  // Intermediate Value Mux
  // -------------------------
  // Output Mux: 34-bit multdiv output truncated to 32-bit
  assign imd_val_d_o_0 = multdiv_sel ? multdiv_imd_val_d_0[31:0] : alu_imd_val_d_0;
  assign imd_val_d_o_1 = multdiv_sel ? multdiv_imd_val_d_1[31:0] : alu_imd_val_d_1;
  
  assign imd_val_we_o   = multdiv_sel ? multdiv_imd_val_we : alu_imd_val_we;

  // -------------------------
  // Result Mux
  // -------------------------
  assign result_ex_o = multdiv_sel ? multdiv_result : alu_result;
  
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) ex_valid_o <= 1'b0;
    else         ex_valid_o <= 1'b1;
  end

  // Branch Target ALU (Simplified)
  if (BranchTargetALU) begin : g_branch_target_alu
    logic [32:0] bt_res;
    assign bt_res = $unsigned(bt_a_operand_i) + $unsigned(bt_b_operand_i);
    assign branch_target_o = bt_res[31:0];
  end else begin : g_no_branch_target_alu
    assign branch_target_o = 32'b0;
  end
  assign branch_decision_o = 1'b0;

endmodule