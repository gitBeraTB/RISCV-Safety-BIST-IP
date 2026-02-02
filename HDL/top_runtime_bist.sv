module top_runtime_bist #(
    parameter DATA_WIDTH = 32
)(
    input  logic        clk,
    input  logic        rst_n,

    // --- System Interface (Normal Operation) ---
    input  logic [DATA_WIDTH-1:0] sys_data_a,
    input  logic [DATA_WIDTH-1:0] sys_data_b,
    input  logic                  sys_req_valid, // "I need the ALU now!"
    output logic [DATA_WIDTH-1:0] sys_result_out,

    // --- APB Slave Interface (Configuration) ---
    input  logic [31:0] paddr,
    input  logic        psel,
    input  logic        penable,
    input  logic        pwrite,
    input  logic [31:0] pwdata,
    output logic [31:0] prdata,
    output logic        pready,

    // --- Interrupt Output ---
    output logic        irq_error
);

    // Internal Signals
    logic [DATA_WIDTH-1:0] bist_pattern;
    logic [DATA_WIDTH-1:0] dut_result;
    logic                  bist_active;
    
    // MUX Signals (The inputs that actually go into the ALU)
    logic [DATA_WIDTH-1:0] alu_in_a;
    logic [DATA_WIDTH-1:0] alu_in_b;
    
    // 1. INPUT MULTIPLEXER (Isolation Logic)
   
    // If BIST is active, feed the LFSR pattern to the ALU.
    // If System is active, feed the System Data.
    // NOTE: In a real ALU, we split the 32-bit pattern into two 16-bit inputs or similar.
    assign alu_in_a = (bist_active) ? bist_pattern : sys_data_a;
    assign alu_in_b = (bist_active) ? ~bist_pattern : sys_data_b; // Just to make it interesting

    
    // 2. DEVICE UNDER TEST (ALU)
    
   
    always_comb begin
        dut_result = alu_in_a + alu_in_b; 
    end
    assign sys_result_out = dut_result;

    // 3. BIST CONTROLLER INSTANCE
    runtime_bist_controller #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_controller (
        .clk(clk),
        .rst_n(rst_n),
        // System Side
        .sys_req_valid(sys_req_valid),
        .bist_active_mode(bist_active),
        .dut_result_in(dut_result),
        // BIST Side
        .bist_pattern_out(bist_pattern),
        // APB Side
        .paddr(paddr),
        .psel(psel),
        .penable(penable),
        .pwrite(pwrite),
        .pwdata(pwdata),
        .prdata(prdata),
        .pready(pready),
        // Interrupt
        .error_irq(irq_error)
    );

endmodule