module lfsr_gen #(
    parameter WIDTH = 32,
    parameter INITIAL_SEED = 32'hDEAD_BEEF
  )(
    input  logic             clk,
    input  logic             rst_n,
    input  logic             enable,
    input  logic             seed_load,
    input  logic [WIDTH-1:0] seed_data,
    output logic [WIDTH-1:0] pattern_out
  );

  logic [WIDTH-1:0] lfsr_reg;

  // Polynomial: x^32 + x^22 + x^2 + x^1 + 1 (Xilinx Standard)
  logic feedback;
  assign feedback = lfsr_reg[31] ^ lfsr_reg[21] ^ lfsr_reg[1] ^ lfsr_reg[0];

  always_ff @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      lfsr_reg <= INITIAL_SEED;
    end
    else if (seed_load)
    begin
      lfsr_reg <= seed_data;
      // synthesis translate_off
      $display("[DEBUG][LFSR] Seed loaded: 0x%h at time %0t", seed_data, $time);
      // synthesis translate_on
    end
    else if (enable)
    begin
      lfsr_reg <= {lfsr_reg[WIDTH-2:0], feedback};
    end
  end

  assign pattern_out = lfsr_reg;

endmodule
