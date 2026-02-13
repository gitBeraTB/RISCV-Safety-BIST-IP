`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/03/2026 02:23:33 AM
// Design Name: 
// Module Name: flash_ctrl_top_specific_pkg
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


// File: flash_ctrl_top_specific_pkg.sv
// Description: Dummy Flash Control Package for Synthesis

package flash_ctrl_top_specific_pkg;

  // Flash Programming Type Enum
  typedef enum logic [1:0] {
    FlashProgNormal = 2'h0,
    FlashProgRepair = 2'h1
  } flash_prog_e;

  // Flash Partition Type Enum
  typedef enum logic [1:0] {
    FlashPartData = 2'h0,
    FlashPartInfo = 2'h1
  } flash_part_e;

endpackage
