module idle_detector #(
    parameter TIMER_WIDTH = 16
)(
    input  logic                   clk,
    input  logic                   rst_n,
    input  logic                   system_valid, // High if system is using the module
    input  logic [TIMER_WIDTH-1:0] threshold,    // AI-Optimized threshold value
    output logic                   idle_trigger  // High when safe to BIST
);

    logic [TIMER_WIDTH-1:0] idle_counter;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            idle_counter <= '0;
            idle_trigger <= 1'b0;
        end else begin
            if (system_valid) begin
                // System is active, reset counter immediately!
                idle_counter <= '0;
                idle_trigger <= 1'b0;
            end else begin
                // System is quiet, increment counter
                if (idle_counter < threshold) begin
                    idle_counter <= idle_counter + 1;
                    idle_trigger <= 1'b0;
                end else begin
                    // Threshold reached, safe to inject test
                    idle_trigger <= 1'b1;
                end
            end
        end
    end

endmodule