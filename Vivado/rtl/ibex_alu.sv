// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Vivado-Native Version: Uses packed arrays and proper module-scoped import.

module ibex_alu import ibex_pkg::*; #(
  parameter RV32B = 0
) (
  input  logic                  clk_i,
  input  logic                  rst_ni,
  input  logic [6:0]            operator_i,
  input  logic [31:0]           operand_a_i,
  input  logic [31:0]           operand_b_i,
  input  logic                  instr_first_cycle_i,

  // Vivado-Native: Packed array ports
  input  logic [1:0][31:0]      imd_val_q_i,
  output logic [1:0][31:0]      imd_val_d_o,
  
  output logic [1:0]            imd_val_we_o,
  input  logic [31:0]           multdiv_operand_a_i,
  input  logic [31:0]           multdiv_operand_b_i,
  input  logic                  multdiv_sel_i,
  output logic [31:0]           adder_result_o,
  output logic [33:0]           adder_result_ext_o,
  
  output logic [31:0]           result_o,
  output logic                  comparison_result_o,
  output logic                  is_equal_result_o
);

  logic [31:0] operand_a_rev;
  logic [32:0] operand_b_neg;

  // bit reverse operand_a for left shifts and bit counting
  for (genvar k = 0; k < 32; k++) begin : gen_rev_operand_a
    assign operand_a_rev[k] = operand_a_i[31-k];
  end

  ///////////
  // Adder //
  ///////////

  logic        adder_op_a_shift1;
  logic        adder_op_a_shift2;
  logic        adder_op_a_shift3;
  logic        adder_op_b_negate;
  logic [32:0] adder_in_a, adder_in_b;
  logic [31:0] adder_result;

  always_comb begin
    adder_op_a_shift1 = 1'b0;
    adder_op_a_shift2 = 1'b0;
    adder_op_a_shift3 = 1'b0;
    adder_op_b_negate = 1'b0;
    
    case (operator_i)
      // Adder OPs
      ALU_SUB,
      // Comparator OPs
      ALU_EQ,   ALU_NE,
      ALU_GE,   ALU_GEU,
      ALU_LT,   ALU_LTU,
      ALU_SLT,  ALU_SLTU,
      // MinMax OPs (RV32B Ops)
      ALU_MIN,  ALU_MINU,
      ALU_MAX,  ALU_MAXU: adder_op_b_negate = 1'b1;

      // Address Calculation OPs (RV32B Ops)
      ALU_SH1ADD: if (RV32B != 0) adder_op_a_shift1 = 1'b1;
      ALU_SH2ADD: if (RV32B != 0) adder_op_a_shift2 = 1'b1;
      ALU_SH3ADD: if (RV32B != 0) adder_op_a_shift3 = 1'b1;

      default:;
    endcase
  end

  // prepare operand a
  always_comb begin
    case (1'b1)
      multdiv_sel_i:     adder_in_a = multdiv_operand_a_i;
      adder_op_a_shift1: adder_in_a = {operand_a_i[30:0],2'b01};
      adder_op_a_shift2: adder_in_a = {operand_a_i[29:0],3'b001};
      adder_op_a_shift3: adder_in_a = {operand_a_i[28:0],4'b0001};
      default:           adder_in_a = {operand_a_i,1'b1};
    endcase
  end

  // prepare operand b
  assign operand_b_neg = {operand_b_i,1'b0} ^ {33{1'b1}};
  always_comb begin
    case (1'b1)
      multdiv_sel_i:     adder_in_b = multdiv_operand_b_i;
      adder_op_b_negate: adder_in_b = operand_b_neg;
      default:           adder_in_b = {operand_b_i, 1'b0};
    endcase
  end

  // actual adder
  assign adder_result_ext_o = $unsigned(adder_in_a) + $unsigned(adder_in_b);
  assign adder_result       = adder_result_ext_o[32:1];
  assign adder_result_o     = adder_result;

  ////////////////
  // Comparison //
  ////////////////

  logic is_equal;
  logic is_greater_equal;  // handles both signed and unsigned forms
  logic cmp_signed;

  always_comb begin
    case (operator_i)
      ALU_GE,
      ALU_LT,
      ALU_SLT,
      // RV32B only
      ALU_MIN,
      ALU_MAX: cmp_signed = 1'b1;
      default: cmp_signed = 1'b0;
    endcase
  end

  assign is_equal = (adder_result == 32'b0);
  assign is_equal_result_o = is_equal;

  // Is greater equal
  always_comb begin
    if ((operand_a_i[31] ^ operand_b_i[31]) == 1'b0) begin
      is_greater_equal = (adder_result[31] == 1'b0);
    end else begin
      is_greater_equal = operand_a_i[31] ^ (cmp_signed);
    end
  end

  // generate comparison result
  logic cmp_result;

  always_comb begin
    case (operator_i)
      ALU_EQ:             cmp_result =  is_equal;
      ALU_NE:             cmp_result = ~is_equal;
      ALU_GE,   ALU_GEU,
      ALU_MAX,  ALU_MAXU: cmp_result = is_greater_equal; // RV32B only
      ALU_LT,   ALU_LTU,
      ALU_MIN,  ALU_MINU, //RV32B only
      ALU_SLT,  ALU_SLTU: cmp_result = ~is_greater_equal;
      default: cmp_result = is_equal;
    endcase
  end

  assign comparison_result_o = cmp_result;

  ///////////
  // Shift //
  ///////////

  logic       shift_left;
  logic       shift_ones;
  logic       shift_arith;
  logic       shift_funnel;
  logic       shift_sbmode;
  logic [5:0] shift_amt;
  logic [5:0] shift_amt_compl;

  logic        [31:0] shift_operand;
  logic signed [32:0] shift_result_ext_signed;
  logic        [32:0] shift_result_ext;
  logic               unused_shift_result_ext;
  logic        [31:0] shift_result;
  logic        [31:0] shift_result_rev;

  // zbf
  logic bfp_op;
  logic [4:0]  bfp_len;
  logic [4:0]  bfp_off;
  logic [31:0] bfp_mask;
  logic [31:0] bfp_mask_rev;
  logic [31:0] bfp_result;

  assign bfp_op = (RV32B != 0) ? (operator_i == ALU_BFP) : 1'b0;
  assign bfp_len = {~(|operand_b_i[27:24]), operand_b_i[27:24]}; 
  assign bfp_off = operand_b_i[20:16];
  assign bfp_mask = (RV32B != 0) ? ~(32'hffff_ffff << bfp_len) : '0;
  
  for (genvar i = 0; i < 32; i++) begin : gen_rev_bfp_mask
    assign bfp_mask_rev[i] = bfp_mask[31-i];
  end

  assign bfp_result =(RV32B != 0) ?
      (~shift_result & operand_a_i) | ((operand_b_i & bfp_mask) << bfp_off) : '0;

  assign shift_amt_compl = 32 - operand_b_i[4:0];

  always_comb begin
    shift_amt[5] = operand_b_i[5] & shift_funnel;

    if (bfp_op) begin
      shift_amt[4:0] = bfp_off; 
    end else begin
      shift_amt[4:0] = instr_first_cycle_i ?
          (operand_b_i[5] && shift_funnel ? shift_amt_compl[4:0] : operand_b_i[4:0]) :
          (operand_b_i[5] && shift_funnel ? operand_b_i[4:0] : shift_amt_compl[4:0]);
    end
  end

  // single-bit mode: shift
  assign shift_sbmode = (RV32B != 0) ?
      (operator_i == ALU_BSET) | (operator_i == ALU_BCLR) | (operator_i == ALU_BINV) : 1'b0;

  always_comb begin
    case (operator_i)
      ALU_SLL: shift_left = 1'b1;
      ALU_SLO: shift_left = (RV32B == 2 || RV32B == 3) ? 1'b1 : 1'b0;
      ALU_BFP: shift_left = (RV32B != 0) ? 1'b1 : 1'b0;
      ALU_ROL: shift_left = (RV32B != 0) ? instr_first_cycle_i : 0;
      ALU_ROR: shift_left = (RV32B != 0) ? ~instr_first_cycle_i : 0;
      ALU_FSL: shift_left = (RV32B != 0) ?
        (shift_amt[5] ? ~instr_first_cycle_i : instr_first_cycle_i) : 1'b0;
      ALU_FSR: shift_left = (RV32B != 0) ?
          (shift_amt[5] ? instr_first_cycle_i : ~instr_first_cycle_i) : 1'b0;
      default: shift_left = 1'b0;
    endcase
    if (shift_sbmode) begin
      shift_left = 1'b1;
    end
  end

  assign shift_arith  = (operator_i == ALU_SRA);
  assign shift_ones   = (RV32B == 2 || RV32B == 3) ?
      (operator_i == ALU_SLO) | (operator_i == ALU_SRO) : 1'b0;
  assign shift_funnel = (RV32B != 0) ?
      (operator_i == ALU_FSL) | (operator_i == ALU_FSR) : 1'b0;

  // shifter structure.
  always_comb begin
    if (RV32B == 0) begin
      shift_operand = shift_left ? operand_a_rev : operand_a_i;
    end else begin
      case (1'b1)
        bfp_op:       shift_operand = bfp_mask_rev;
        shift_sbmode: shift_operand = 32'h8000_0000;
        default:      shift_operand = shift_left ? operand_a_rev : operand_a_i;
      endcase
    end

    shift_result_ext_signed =
        $signed({shift_ones | (shift_arith & shift_operand[31]), shift_operand}) >>> shift_amt[4:0];
    shift_result_ext = $unsigned(shift_result_ext_signed);

    shift_result            = shift_result_ext[31:0];
    unused_shift_result_ext = shift_result_ext[32];

    for (int unsigned i = 0; i < 32; i++) begin
      shift_result_rev[i] = shift_result[31-i];
    end

    shift_result = shift_left ? shift_result_rev : shift_result;
  end

  ///////////////////
  // Bitwise Logic //
  ///////////////////

  logic bwlogic_or;
  logic bwlogic_and;
  logic [31:0] bwlogic_operand_b;
  logic [31:0] bwlogic_or_result;
  logic [31:0] bwlogic_and_result;
  logic [31:0] bwlogic_xor_result;
  logic [31:0] bwlogic_result;

  logic bwlogic_op_b_negate;

  always_comb begin
    case (operator_i)
      ALU_XNOR,
      ALU_ORN,
      ALU_ANDN: bwlogic_op_b_negate = (RV32B != 0) ? 1'b1 : 1'b0;
      ALU_CMIX: bwlogic_op_b_negate = (RV32B != 0) ? ~instr_first_cycle_i : 1'b0;
      default:  bwlogic_op_b_negate = 1'b0;
    endcase
  end

  assign bwlogic_operand_b = bwlogic_op_b_negate ? operand_b_neg[32:1] : operand_b_i;

  assign bwlogic_or_result  = operand_a_i | bwlogic_operand_b;
  assign bwlogic_and_result = operand_a_i & bwlogic_operand_b;
  assign bwlogic_xor_result = operand_a_i ^ bwlogic_operand_b;

  assign bwlogic_or  = (operator_i == ALU_OR)  | (operator_i == ALU_ORN);
  assign bwlogic_and = (operator_i == ALU_AND) | (operator_i == ALU_ANDN);

  always_comb begin
    case (1'b1)
      bwlogic_or:  bwlogic_result = bwlogic_or_result;
      bwlogic_and: bwlogic_result = bwlogic_and_result;
      default:     bwlogic_result = bwlogic_xor_result;
    endcase
  end

  logic [5:0]  bitcnt_result;
  logic [31:0] minmax_result;
  logic [31:0] pack_result;
  logic [31:0] sext_result;
  logic [31:0] singlebit_result;
  logic [31:0] rev_result;
  logic [31:0] shuffle_result;
  logic [31:0] xperm_result;
  logic [31:0] butterfly_result;
  logic [31:0] invbutterfly_result;
  logic [31:0] clmul_result;
  logic [31:0] multicycle_result;

  assign bitcnt_result       = '0;
  assign minmax_result       = '0;
  assign pack_result         = '0;
  assign sext_result         = '0;
  assign singlebit_result    = '0;
  assign rev_result          = '0;
  assign shuffle_result      = '0;
  assign xperm_result        = '0;
  assign butterfly_result    = '0;
  assign invbutterfly_result = '0;
  assign clmul_result        = '0;
  assign multicycle_result   = 32'b0;

  // Vivado-Native: Direct packed array assignment
  assign imd_val_d_o = '{default: '0};
  assign imd_val_we_o = 2'b0;

  ////////////////
  // Result mux //
  ////////////////

  always_comb begin
    result_o = 32'b0;

    case (operator_i)
      // Bitwise Logic Operations
      ALU_XOR,  ALU_XNOR,
      ALU_OR,   ALU_ORN,
      ALU_AND,  ALU_ANDN: result_o = bwlogic_result;

      // Adder Operations
      ALU_ADD,  ALU_SUB,
      ALU_SH1ADD, ALU_SH2ADD,
      ALU_SH3ADD: result_o = adder_result;

      // Shift Operations
      ALU_SLL,  ALU_SRL,
      ALU_SRA,
      ALU_SLO,  ALU_SRO: result_o = shift_result;

      // Shuffle Operations
      ALU_SHFL, ALU_UNSHFL: result_o = shuffle_result;

      // Crossbar Permutation
      ALU_XPERM_N, ALU_XPERM_B, ALU_XPERM_H: result_o = xperm_result;

      // Comparison Operations
      ALU_EQ,   ALU_NE,
      ALU_GE,   ALU_GEU,
      ALU_LT,   ALU_LTU,
      ALU_SLT,  ALU_SLTU: result_o = {31'h0, cmp_result};

      // MinMax Operations
      ALU_MIN,  ALU_MAX,
      ALU_MINU, ALU_MAXU: result_o = minmax_result;

      // Bitcount Operations
      ALU_CLZ, ALU_CTZ,
      ALU_CPOP: result_o = {26'h0, bitcnt_result};

      // Pack Operations
      ALU_PACK, ALU_PACKH,
      ALU_PACKU: result_o = pack_result;

      // Sign-Extend
      ALU_SEXTB, ALU_SEXTH: result_o = sext_result;

      // Ternary & Other Operations
      ALU_CMIX, ALU_CMOV,
      ALU_FSL,  ALU_FSR,
      ALU_ROL, ALU_ROR,
      ALU_CRC32_W, ALU_CRC32C_W,
      ALU_CRC32_H, ALU_CRC32C_H,
      ALU_CRC32_B, ALU_CRC32C_B,
      ALU_BCOMPRESS, ALU_BDECOMPRESS: result_o = multicycle_result;

      // Single-Bit Operations
      ALU_BSET, ALU_BCLR,
      ALU_BINV, ALU_BEXT: result_o = singlebit_result;

      // General Reverse
      ALU_GREV, ALU_GORC: result_o = rev_result;

      // Bit Field Place
      ALU_BFP: result_o = bfp_result;

      // Carry-less Multiply
      ALU_CLMUL, ALU_CLMULR,
      ALU_CLMULH: result_o = clmul_result;

      default: ;
    endcase
  end

  logic unused_shift_amt_compl;
  assign unused_shift_amt_compl = shift_amt_compl[5];

endmodule
