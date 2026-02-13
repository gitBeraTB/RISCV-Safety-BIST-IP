// Copyright lowRISC contributors.
// Copyright 2018 ETH Zurich and University of Bologna, see also CREDITS.md.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`define OP_L 15:0
`define OP_H 31:16

/**
 * Fast Multiplier and Division
 *
 * 16x16 kernel multiplier and Long Division
 */

import ibex_pkg::*;

module ibex_multdiv_fast #(
  parameter integer RV32M = 2
) (
  input  logic             clk_i,
  input  logic             rst_ni,
  input  logic             mult_en_i,
  input  logic             div_en_i,
  input  logic             mult_sel_i,
  input  logic             div_sel_i,
  input  logic [1:0]       operator_i,
  input  logic [1:0]       signed_mode_i,
  input  logic [31:0]      op_a_i,
  input  logic [31:0]      op_b_i,
  input  logic [31:0]      alu_adder_ext_i,
  input  logic [31:0]      alu_adder_i,
  input  logic             equal_to_zero_i,
  input  logic             data_ind_timing_i,
  output logic [31:0]      alu_operand_a_o,
  output logic [31:0]      alu_operand_b_o,
  output logic [31:0]      multdiv_result_o,
  output logic             valid_o,
  output logic             multdiv_ready_id_o,
  
  // ICARUS FIX: Flat Ports (34 bit)
  output logic [33:0]      imd_val_d_o_0,
  output logic [33:0]      imd_val_d_o_1,
  output logic [1:0]       imd_val_we_o,
  input  logic [33:0]      imd_val_q_i_0,
  input  logic [33:0]      imd_val_q_i_1
);
  
  // Dahili sinyal koprusu
  logic [1:0][33:0] imd_val_d_o;
  logic [1:0][33:0] imd_val_q_i;

  assign imd_val_d_o_0 = imd_val_d_o[0];
  assign imd_val_d_o_1 = imd_val_d_o[1];

  assign imd_val_q_i[0] = imd_val_q_i_0;
  assign imd_val_q_i[1] = imd_val_q_i_1;

  // --- KODUN GERI KALANI AYNI ---
  // Dummy logic or Full implementation goes here...
  // Senin son calisan halini (dummy logic'li) kullanalim:

  assign alu_operand_a_o    = 32'b0;
  assign alu_operand_b_o    = 32'b0;
  assign multdiv_result_o   = 32'b0;
  assign valid_o            = 1'b0;
  assign multdiv_ready_id_o = 1'b1;

  // Dahili array'e atama
  assign imd_val_d_o[0] = 34'b0;
  assign imd_val_d_o[1] = 34'b0;
  assign imd_val_we_o   = 2'b0;

endmodule