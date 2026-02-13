`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/03/2026 02:15:59 AM
// Design Name: 
// Module Name: edn_pkg
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


// File: edn_pkg.sv
// Description: Dummy Entropy Distribution Network Package (FIXED with Parameters)

package edn_pkg;

  
  parameter int ENDPOINT_BUS_WIDTH = 32;

  typedef struct packed {
    logic edn_req;
  } edn_req_t;

  typedef struct packed {
    logic        edn_ack;
    logic        edn_fips;
    logic [ENDPOINT_BUS_WIDTH-1:0] edn_bus; 
  } edn_rsp_t;

endpackage