// Vivado-Native Version: ibex_alu_bist_wrapper
// Uses packed arrays and proper module-scoped import.

module ibex_alu_bist_wrapper import ibex_pkg::*; #(
    parameter integer RV32B = 0
) (
    input  logic              clk_i,
    input  logic              rst_ni,
    
    // Inputs
    input  logic [6:0]        operator_i,
    input  logic [31:0]       operand_a_i,
    input  logic [31:0]       operand_b_i,
    input  logic              instr_first_cycle_i,
    input  logic              multdiv_en_i,
    
    // Vivado-Native: Packed array ports
    input  logic [1:0][31:0]  imd_val_q_i,
    input  logic [1:0]        imd_val_we_i,
    
    // Outputs
    output logic [31:0]       adder_result_o,
    output logic [31:0]       result_o,
    output logic              comparison_result_o,
    output logic              is_equal_result_o,
    
    // BIST Signals
    input  logic              core_sleep_i, 
    input  logic [31:0]       paddr_i,
    input  logic              psel_i,
    input  logic              penable_i,
    input  logic              pwrite_i,
    input  logic [31:0]       pwdata_i,
    output logic [31:0]       prdata_o,
    output logic              pready_o,
    output logic              bist_error_irq_o,
    input  logic              sim_fault_inject_i 
);

    // --- Internal Signals ---
    logic        bist_active;
    logic [31:0] bist_pattern;
    
    // MUX Signals
    logic [6:0]  alu_operator_mux;
    logic [31:0] alu_operand_a_mux;
    logic [31:0] alu_operand_b_mux;
    
    // ALU Outputs
    logic [31:0] alu_result_raw;
    
    //  INPUT MUX
    always_comb begin
        if (bist_active) begin
            // BIST Mode: Force ADD operation
            alu_operand_a_mux = bist_pattern;
            alu_operand_b_mux = ~bist_pattern; 
            alu_operator_mux  = ALU_ADD;       
        end else begin
            // Normal Mode: Pass through
            alu_operand_a_mux = operand_a_i;
            alu_operand_b_mux = operand_b_i;
            alu_operator_mux  = operator_i;
        end
    end

    //  IBEX ALU INSTANCE (Vivado-Native: Direct packed array connection)
    ibex_alu #(
        .RV32B(RV32B)
    ) u_real_alu (
        .clk_i              (clk_i),
        .rst_ni             (rst_ni),
        .operator_i         (alu_operator_mux),
        .operand_a_i        (alu_operand_a_mux),
        .operand_b_i        (alu_operand_b_mux),
        .instr_first_cycle_i(instr_first_cycle_i),
        
        // Vivado-Native: Direct packed array connection
        .imd_val_q_i        (imd_val_q_i),
        .imd_val_d_o        (), // Open
        .imd_val_we_o       (), // Open
        
        // Other connections
        .adder_result_o     (adder_result_o),
        .adder_result_ext_o (),
        .result_o           (alu_result_raw),
        .comparison_result_o(comparison_result_o),
        .is_equal_result_o  (is_equal_result_o),

        // Unused inputs zeroed
        .multdiv_operand_a_i (32'b0),
        .multdiv_operand_b_i (32'b0),
        .multdiv_sel_i       (1'b0)
    );

    // Fault injection: XOR bit[0] of result during BIST when sim_fault_inject_i is active
    wire [31:0] alu_result_fault = alu_result_raw ^ {31'b0, (sim_fault_inject_i & bist_active)};
    assign result_o = alu_result_raw;

    // RUNTIME BIST CONTROLLER  
    runtime_bist_controller #(
        .DATA_WIDTH(32)
    ) u_bist_ctrl (
        .clk              (clk_i),
        .rst_n            (rst_ni),
        .sys_req_valid    (!core_sleep_i), 
        .bist_active_mode (bist_active),
        .dut_result_in    (alu_result_fault),
        .bist_pattern_out (bist_pattern),
        .paddr(paddr_i), .psel(psel_i), .penable(penable_i), 
        .pwrite(pwrite_i), .pwdata(pwdata_i), .prdata(prdata_o), .pready(pready_o),
        .error_irq        (bist_error_irq_o)
    );

endmodule
