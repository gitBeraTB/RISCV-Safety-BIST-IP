`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/03/2026 02:21:41 AM
// Design Name: 
// Module Name: top_racl_pkg
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


// File: top_racl_pkg.sv
// Description: Dummy RACL Package for Synthesis

package top_racl_pkg;

  // RACL Error Log Structure
  // İçeriği çok önemli değil, Vivado bir struct görsün yeter.
  typedef struct packed {
    logic [31:0]  read_addr;
    logic         valid;
    logic         overflow;
  } racl_error_log_t;

  // İhtiyaç duyarsa diye RACL Policy vektörü
  typedef logic [3:0] racl_policy_vec_t;

endpackage
