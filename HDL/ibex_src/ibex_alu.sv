module ibex_alu import ibex_pkg::*; #(
    parameter bit RV32B = 0
)(
    input  alu_op_e           operator_i,
    input  logic [31:0]       operand_a_i,
    input  logic [31:0]       operand_b_i,
    input  logic              instr_first_cycle_i, // Real port
    input  logic              multdiv_en_i,        // Real port
    input  logic [31:0]       imd_val_q_i,         // Real port
    input  logic [1:0]        imd_val_we_i,        // Real port
    
    input  logic              inject_fault_i, 

    output logic [31:0]       adder_result_o,
    output logic [31:0]       result_o,
    output logic              comparison_result_o,
    output logic              is_equal_result_o
);

    logic [31:0] result_raw;

    // Simplified ALU Logic
    always_comb begin
        case (operator_i)
            ALU_ADD: result_raw = operand_a_i + operand_b_i;
            ALU_SUB: result_raw = operand_a_i - operand_b_i;
            ALU_AND: result_raw = operand_a_i & operand_b_i;
            ALU_OR:  result_raw = operand_a_i | operand_b_i;
            ALU_XOR: result_raw = operand_a_i ^ operand_b_i;
            default: result_raw = '0;
        endcase
    end

    // Fault Injection Logic (Bit Flip)
    logic [31:0] final_result;
    assign final_result = (inject_fault_i) ? (result_raw ^ 32'h1) : result_raw;

    // Outputs
    assign result_o          = final_result;
    assign adder_result_o    = final_result; // Dummy assignment
    assign comparison_result_o = 0;
    assign is_equal_result_o   = (operand_a_i == operand_b_i);

endmodule