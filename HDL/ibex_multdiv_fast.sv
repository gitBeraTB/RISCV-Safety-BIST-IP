// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`define OP_L 15:0
`define OP_H 31:16

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
  
  // Flat Portlar (34 bit)
  output logic [33:0]      imd_val_d_o_0,
  output logic [33:0]      imd_val_d_o_1,
  output logic [1:0]       imd_val_we_o,
  input  logic [33:0]      imd_val_q_i_0, // Dogrudan bunu kullanacagiz
  input  logic [33:0]      imd_val_q_i_1  // Dogrudan bunu kullanacagiz
);

  // --- MANTIK ---
  logic signed [31:0] mac_res_signed;
  logic        [31:0] mac_res_ext;
  logic        [31:0] accum;
  logic               sign_a, sign_b;
  logic               mult_valid;
  logic               signed_mult;
  logic [31:0]        mac_res_d;
  logic [31:0]        mac_res;
  
  // Divider Sinyalleri
  logic [31:0] op_remainder_d;
  logic [31:0] op_numerator_q, op_denominator_q, op_quotient_q;
  logic [31:0] op_numerator_d, op_denominator_d, op_quotient_d;
  logic [31:0] next_remainder;
  logic [32:0] next_quotient;
  logic [31:0] res_adder_h;
  logic [4:0]  div_counter_q, div_counter_d;
  logic        div_valid, div_hold, mult_hold;
  logic        is_greater_equal;
  logic        div_by_zero_q, div_by_zero_d;
  logic        div_sign_a, div_sign_b, div_change_sign, rem_change_sign;
  logic [31:0] one_shift;

  logic mult_en_internal, div_en_internal, multdiv_en;

  typedef enum logic [2:0] {
    MD_IDLE, MD_ABS_A, MD_ABS_B, MD_COMP, MD_LAST, MD_CHANGE_SIGN, MD_FINISH
  } md_fsm_e;
  md_fsm_e md_state_q, md_state_d;

  assign mult_en_internal = mult_en_i & ~mult_hold;
  assign div_en_internal  = div_en_i & ~div_hold;
  assign multdiv_en = mult_en_internal | div_en_internal;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      div_counter_q    <= '0;
      md_state_q       <= MD_IDLE;
      op_numerator_q   <= '0;
      op_quotient_q    <= '0;
      div_by_zero_q    <= '0;
    end else if (div_en_internal) begin
      div_counter_q    <= div_counter_d;
      op_numerator_q   <= op_numerator_d;
      op_quotient_q    <= op_quotient_d;
      md_state_q       <= md_state_d;
      div_by_zero_q    <= div_by_zero_d;
    end
  end

  // Intermediate Value Output (Flat Port Assign)
  // [0] -> imd_val_d_o_0
  assign imd_val_d_o_0 = div_sel_i ? {2'b0, op_remainder_d} : {2'b0, mac_res_d};
  
  // [1] -> imd_val_d_o_1
  assign imd_val_d_o_1 = {2'b0, op_denominator_d};

  // Write Enable Output
  assign imd_val_we_o[0] = multdiv_en;
  assign imd_val_we_o[1] = div_en_internal;
  
  // Input Reading (Flat Port Usage)
  assign op_denominator_q = imd_val_q_i_1[31:0];

  assign signed_mult      = (signed_mode_i != 2'b00);
  assign multdiv_result_o = div_sel_i ? imd_val_q_i_0[31:0] : mac_res_d;

  // -------------------------
  // FAST MULTIPLIER LOGIC
  // -------------------------
  logic [15:0] mult_op_a;
  logic [15:0] mult_op_b;

  typedef enum logic [1:0] {
      ALBL, ALBH, AHBL, AHBH
  } mult_fsm_e;
  mult_fsm_e mult_state_q, mult_state_d;

  assign mac_res_signed = $signed({sign_a, mult_op_a}) * $signed({sign_b, mult_op_b}) + $signed(accum);
  assign mac_res_ext    = $unsigned(mac_res_signed);
  assign mac_res        = mac_res_ext[31:0];

  always_comb begin
      mult_op_a    = op_a_i[`OP_L];
      mult_op_b    = op_b_i[`OP_L];
      sign_a       = 1'b0;
      sign_b       = 1'b0;
      accum        = imd_val_q_i_0[31:0]; // FIXED: Flat port kullanildi
      mac_res_d    = mac_res;
      mult_state_d = mult_state_q;
      mult_valid   = 1'b0;
      mult_hold    = 1'b0;

      case (mult_state_q)
        ALBL: begin
          mult_op_a = op_a_i[`OP_L];
          mult_op_b = op_b_i[`OP_L];
          sign_a    = 1'b0;
          sign_b    = 1'b0;
          accum     = '0;
          mac_res_d = mac_res;
          mult_state_d = ALBH;
        end

        ALBH: begin
          mult_op_a = op_a_i[`OP_L];
          mult_op_b = op_b_i[`OP_H];
          sign_a    = 1'b0;
          sign_b    = signed_mode_i[1] & op_b_i[31];
          
          // FIXED: 2D array yerine flat port
          accum     = {16'b0, imd_val_q_i_0[31:16]};
          
          if (operator_i == MD_OP_MULL) begin
             // FIXED: Flat port
             mac_res_d = {mac_res[`OP_L], imd_val_q_i_0[`OP_L]};
          end else begin
             mac_res_d = mac_res;
          end
          mult_state_d = AHBL;
        end

        AHBL: begin
          mult_op_a = op_a_i[`OP_H];
          mult_op_b = op_b_i[`OP_L];
          sign_a    = signed_mode_i[0] & op_a_i[31];
          sign_b    = 1'b0;
          if (operator_i == MD_OP_MULL) begin
            accum        = {16'b0, imd_val_q_i_0[31:16]}; // FIXED
            mac_res_d    = {mac_res[15:0], imd_val_q_i_0[15:0]}; // FIXED
            mult_valid   = 1'b1;
            mult_state_d = ALBL;
          end else begin
            accum        = imd_val_q_i_0[31:0]; // FIXED
            mac_res_d    = mac_res;
            mult_state_d = AHBH;
          end
        end

        AHBH: begin
          mult_op_a = op_a_i[`OP_H];
          mult_op_b = op_b_i[`OP_H];
          sign_a    = signed_mode_i[0] & op_a_i[31];
          sign_b    = signed_mode_i[1] & op_b_i[31];
          accum[17: 0]  = imd_val_q_i_0[31:16]; // FIXED
          accum[31:18]  = {14{signed_mult & imd_val_q_i_0[31]}}; // FIXED
          mac_res_d     = mac_res;
          mult_valid    = 1'b1;
          mult_state_d = ALBL;
        end
        default: mult_state_d = ALBL;
      endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
        mult_state_q <= ALBL;
      end else begin
        if (mult_en_internal) begin
          mult_state_q <= mult_state_d;
        end
      end
  end

  // -------------------------
  // DIVIDER LOGIC
  // -------------------------
  assign res_adder_h    = alu_adder_ext_i[31:1];
  assign next_remainder = is_greater_equal ? res_adder_h : imd_val_q_i_0[31:0]; // FIXED
  assign next_quotient  = is_greater_equal ? {1'b0, op_quotient_q} | {1'b0, one_shift} :
                                             {1'b0, op_quotient_q};
  assign one_shift      = {31'b0, 1'b1} << div_counter_q;

  always_comb begin
    if ((imd_val_q_i_0[31] ^ op_denominator_q[31]) == 1'b0) begin // FIXED
      is_greater_equal = (res_adder_h[31] == 1'b0);
    end else begin
      is_greater_equal = imd_val_q_i_0[31]; // FIXED
    end
  end

  assign div_sign_a      = op_a_i[31] & signed_mode_i[0];
  assign div_sign_b      = op_b_i[31] & signed_mode_i[1];
  assign div_change_sign = (div_sign_a ^ div_sign_b) & ~div_by_zero_q;
  assign rem_change_sign = div_sign_a;

  always_comb begin
    div_counter_d    = div_counter_q - 5'h1;
    op_remainder_d   = imd_val_q_i_0[31:0]; // FIXED
    op_quotient_d    = op_quotient_q;
    md_state_d       = md_state_q;
    op_numerator_d   = op_numerator_q;
    op_denominator_d = op_denominator_q;
    alu_operand_a_o  = {32'h0  , 1'b1};
    alu_operand_b_o  = {~op_b_i, 1'b1};
    div_valid        = 1'b0;
    div_hold         = 1'b0;
    div_by_zero_d    = div_by_zero_q;

    case (md_state_q)
      MD_IDLE: begin
        if (operator_i == MD_OP_DIV) begin
          op_remainder_d = '1;
          md_state_d     = md_fsm_e'((!data_ind_timing_i && equal_to_zero_i) ? MD_FINISH : MD_ABS_A);
          div_by_zero_d  = equal_to_zero_i;
        end else begin
          op_remainder_d = op_a_i;
          md_state_d     = md_fsm_e'((!data_ind_timing_i && equal_to_zero_i) ? MD_FINISH : MD_ABS_A);
        end
        alu_operand_a_o  = {32'h0  , 1'b1};
        alu_operand_b_o  = {~op_b_i, 1'b1};
        div_counter_d    = 5'd31;
      end
      MD_ABS_A: begin
        op_quotient_d   = '0;
        op_numerator_d  = div_sign_a ? alu_adder_i : op_a_i;
        md_state_d      = MD_ABS_B;
        div_counter_d   = 5'd31;
        alu_operand_a_o = {32'h0  , 1'b1};
        alu_operand_b_o = {~op_a_i, 1'b1};
      end
      MD_ABS_B: begin
        op_remainder_d   = { 31'h0, op_numerator_q[31]};
        op_denominator_d = div_sign_b ? alu_adder_i : op_b_i;
        md_state_d       = MD_COMP;
        div_counter_d    = 5'd31;
        alu_operand_a_o  = {32'h0  , 1'b1};
        alu_operand_b_o  = {~op_b_i, 1'b1};
      end
      MD_COMP: begin
        op_remainder_d  = {1'b0, next_remainder[31:0], op_numerator_q[div_counter_d]};
        op_quotient_d   = next_quotient[31:0];
        md_state_d      = md_fsm_e'((div_counter_q == 5'd1) ? MD_LAST : MD_COMP);
        alu_operand_a_o = {imd_val_q_i_0[31:0], 1'b1}; // FIXED
        alu_operand_b_o = {~op_denominator_q[31:0], 1'b1};
      end
      MD_LAST: begin
        if (operator_i == MD_OP_DIV) begin
          op_remainder_d = next_quotient[31:0];
        end else begin
          op_remainder_d = next_remainder[31:0];
        end
        alu_operand_a_o  = {imd_val_q_i_0[31:0], 1'b1}; // FIXED
        alu_operand_b_o  = {~op_denominator_q[31:0], 1'b1};
        md_state_d = MD_CHANGE_SIGN;
      end
      MD_CHANGE_SIGN: begin
        md_state_d  = MD_FINISH;
        if (operator_i == MD_OP_DIV) begin
          op_remainder_d = (div_change_sign) ? alu_adder_i : imd_val_q_i_0[31:0]; // FIXED
        end else begin
          op_remainder_d = (rem_change_sign) ? alu_adder_i : imd_val_q_i_0[31:0]; // FIXED
        end
        alu_operand_a_o  = {32'h0  , 1'b1};
        alu_operand_b_o  = {~imd_val_q_i_0[31:0], 1'b1}; // FIXED
      end
      MD_FINISH: begin
        md_state_d = MD_IDLE;
        div_hold   = 1'b0;
        div_valid  = 1'b1;
      end
      default: md_state_d = MD_IDLE;
    endcase
  end

  assign valid_o = mult_valid | div_valid;
  assign multdiv_ready_id_o = 1'b1;

endmodule