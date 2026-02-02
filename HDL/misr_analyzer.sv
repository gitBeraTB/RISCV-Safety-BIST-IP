// Module: misr_analyzer.sv
// Description: Compresses the output of the DUT (Device Under Test) into a signature.

module misr_analyzer #(
    parameter WIDTH = 32
)(
    input  logic             clk,
    input  logic             rst_n,
    input  logic             enable,
    input  logic             clear,
    input  logic [WIDTH-1:0] dut_response, // Data coming from the ALU/Hardware being tested
    output logic [WIDTH-1:0] signature
);

    logic [WIDTH-1:0] misr_reg;

    // Polynomial for signature analysis
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            misr_reg <= '0;
        end else if (clear) begin
            misr_reg <= '0;
        end else if (enable) begin
            // Simple MISR logic: Shift and XOR with input
            misr_reg <= {misr_reg[WIDTH-2:0], misr_reg[31]} ^ dut_response;
        end
    end

    assign signature = misr_reg;

    // synthesis translate_off
    always @(posedge clk) begin
        if (enable)
            $display("[DEBUG][MISR] Capturing Data: 0x%h | Current Sig: 0x%h", dut_response, misr_reg);
    end
    // synthesis translate_on

endmodule