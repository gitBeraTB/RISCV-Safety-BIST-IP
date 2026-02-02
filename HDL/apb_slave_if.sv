// File: HDL/apb_slave_if.sv
// Description: Generic APB Slave Interface.
//              Converts APB transactions into simple Register Read/Write signals.

module apb_slave_if #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input  logic                  clk,
    input  logic                  rst_n,

    // --- APB Interface (Standard) ---
    input  logic [ADDR_WIDTH-1:0] paddr,
    input  logic                  psel,
    input  logic                  penable,
    input  logic                  pwrite,
    input  logic [DATA_WIDTH-1:0] pwdata,
    output logic [DATA_WIDTH-1:0] prdata,
    output logic                  pready,
    output logic                  pslverr,

    // --- Backend Register Interface (To Core) ---
    output logic [7:0]            reg_addr,     // Simplified address (byte offset)
    output logic [DATA_WIDTH-1:0] reg_wdata,    // Data to be written
    output logic                  reg_write_en, // 1 = Write Request
    output logic                  reg_read_en,  // 1 = Read Request
    input  logic [DATA_WIDTH-1:0] reg_rdata     // Data read from Core
);

    // APB Protocol Logic
    // Access happens when PSEL is high and PENABLE goes high (Setup -> Access phase)
    
    assign pready  = 1'b1; // We are always fast enough (no wait states)
    assign pslverr = 1'b0; // No error support for now

    // Write Logic
    assign reg_write_en = psel & penable & pwrite;
    assign reg_wdata    = pwdata;
    
    // Read Logic
    assign reg_read_en  = psel & !pwrite; // Read happens during setup or access
    assign prdata       = reg_rdata;      // Direct feedthrough from register file

    // Address Decoding (Masking to get register index)
    assign reg_addr     = paddr[7:0];

endmodule