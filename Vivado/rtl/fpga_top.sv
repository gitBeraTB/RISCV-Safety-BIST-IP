// ============================================================================
// FPGA Top Wrapper for Vivado Implementation
// 
// Problem: ibex_ex_block has 406 I/O ports, but Artix-7 has only 106 pins.
// Solution: This wrapper reduces I/O by using registered inputs and
//           serialized test interface. Only essential pins are exposed.
// ============================================================================

module fpga_top import ibex_pkg::*; (
    input  logic        clk_i,          // Board clock
    input  logic        rst_ni,         // Active-low reset (button)
    
    // --- Minimal Test Interface ---
    input  logic [3:0]  sw_i,           // 4 switches for control
    input  logic [3:0]  btn_i,          // 4 buttons for triggers
    output logic [3:0]  led_o,          // 4 LEDs for status
    output logic [7:0]  led_result_o    // 8 LEDs for result preview
);

    // =========================================================================
    // Internal Signals
    // =========================================================================
    
    // ALU
    logic [6:0]  alu_operator;
    logic [31:0] alu_operand_a, alu_operand_b;
    logic        alu_instr_first_cycle;
    
    // MultDiv
    logic [1:0]  multdiv_operator;
    logic        mult_sel, div_sel, div_en;
    logic [1:0]  multdiv_signed_mode;
    logic [31:0] multdiv_operand_a, multdiv_operand_b;
    logic        data_ind_timing;
    
    // IMD Loopback
    logic [1:0][31:0] imd_val_q, imd_val_d;
    logic [1:0]       imd_val_we;
    
    // Outputs
    logic [31:0] alu_adder_result;
    logic [31:0] result_ex;
    logic [31:0] branch_target;
    logic        branch_decision;
    logic        ex_valid;
    
    // BIST (Dummy)
    logic        bist_error_irq;
    logic [31:0] prdata;
    logic        pready;

    // =========================================================================
    // Test Pattern Generator (Button-Driven)
    // =========================================================================
    
    // Test state machine
    logic [2:0] test_sel;
    logic       test_trigger, test_trigger_prev;
    logic       test_running;
    logic [31:0] test_result_reg;
    logic        test_pass;
    
    assign test_trigger = btn_i[0];
    assign test_sel     = sw_i[2:0];
    
    // Edge detect for button press
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            test_trigger_prev <= 1'b0;
        else
            test_trigger_prev <= test_trigger;
    end
    
    wire test_start = test_trigger & ~test_trigger_prev;
    
    // Test pattern selection
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            alu_operator        <= ALU_ADD;
            alu_operand_a       <= 32'd0;
            alu_operand_b       <= 32'd0;
            alu_instr_first_cycle <= 1'b0;
            mult_sel            <= 1'b0;
            div_sel             <= 1'b0;
            div_en              <= 1'b0;
            multdiv_operator    <= 2'b00;
            multdiv_operand_a   <= 32'd0;
            multdiv_operand_b   <= 32'd0;
            multdiv_signed_mode <= 2'b00;
            data_ind_timing     <= 1'b0;
            test_running        <= 1'b0;
            test_result_reg     <= 32'd0;
            test_pass           <= 1'b0;
        end else begin
            if (test_start) begin
                test_running <= 1'b1;
                mult_sel <= 1'b0;
                div_sel  <= 1'b0;
                div_en   <= 1'b0;
                
                case (test_sel)
                    3'd0: begin // ALU ADD: 15 + 25 = 40
                        alu_operator  <= ALU_ADD;
                        alu_operand_a <= 32'd15;
                        alu_operand_b <= 32'd25;
                    end
                    3'd1: begin // ALU SUB: 100 - 30 = 70
                        alu_operator  <= ALU_SUB;
                        alu_operand_a <= 32'd100;
                        alu_operand_b <= 32'd30;
                    end
                    3'd2: begin // ALU AND: 0xFF00 & 0x0FF0
                        alu_operator  <= ALU_AND;
                        alu_operand_a <= 32'hFF00;
                        alu_operand_b <= 32'h0FF0;
                    end
                    3'd3: begin // ALU OR: 0xF000 | 0x000F
                        alu_operator  <= ALU_OR;
                        alu_operand_a <= 32'hF000;
                        alu_operand_b <= 32'h000F;
                    end
                    3'd4: begin // ALU XOR
                        alu_operator  <= ALU_XOR;
                        alu_operand_a <= 32'hAAAA_AAAA;
                        alu_operand_b <= 32'h5555_5555;
                    end
                    3'd5: begin // MULT: 12 * 12 = 144
                        mult_sel <= 1'b1;
                        multdiv_operator  <= MD_OP_MULL;
                        multdiv_operand_a <= 32'd12;
                        multdiv_operand_b <= 32'd12;
                    end
                    3'd6: begin // MULT: 1000 * 500 = 500000
                        mult_sel <= 1'b1;
                        multdiv_operator  <= MD_OP_MULL;
                        multdiv_operand_a <= 32'd1000;
                        multdiv_operand_b <= 32'd500;
                    end
                    default: begin // ALU ADD: 0 + 0
                        alu_operator  <= ALU_ADD;
                        alu_operand_a <= 32'd0;
                        alu_operand_b <= 32'd0;
                    end
                endcase
            end
            
            // Capture result
            if (test_running && ex_valid) begin
                test_result_reg <= result_ex;
                test_running    <= 1'b0;
                
                // Auto-check known results
                case (test_sel)
                    3'd0: test_pass <= (result_ex == 32'd40);
                    3'd1: test_pass <= (result_ex == 32'd70);
                    3'd2: test_pass <= (result_ex == 32'h0F00);
                    3'd3: test_pass <= (result_ex == 32'hF00F);
                    3'd4: test_pass <= (result_ex == 32'hFFFF_FFFF);
                    3'd5: test_pass <= (result_ex == 32'd144);
                    3'd6: test_pass <= (result_ex == 32'd500000);
                    default: test_pass <= 1'b0;
                endcase
            end
        end
    end
    
    // =========================================================================
    // IMD Register Loopback (Required for multi-cycle multiply)
    // =========================================================================
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            imd_val_q <= '{default: '0};
        end else begin
            if (imd_val_we[0]) imd_val_q[0] <= imd_val_d[0];
            if (imd_val_we[1]) imd_val_q[1] <= imd_val_d[1];
        end
    end

    // =========================================================================
    // DUT: ibex_ex_block
    // =========================================================================
    ibex_ex_block #(
        .RV32M(RV32MFast),
        .RV32B(RV32BNone),
        .MultiplierImplementation(0),
        .BranchTargetALU(0)
    ) u_ex_block (
        .clk_i                   (clk_i),
        .rst_ni                  (rst_ni),
        
        // ALU
        .alu_operator_i          (alu_operator),
        .alu_operand_a_i         (alu_operand_a),
        .alu_operand_b_i         (alu_operand_b),
        .alu_instr_first_cycle_i (alu_instr_first_cycle),
        
        // MultDiv
        .multdiv_operator_i      (multdiv_operator),
        .mult_sel_i              (mult_sel),
        .div_en_i                (div_en),
        .div_sel_i               (div_sel),
        .multdiv_signed_mode_i   (multdiv_signed_mode),
        .multdiv_operand_a_i     (multdiv_operand_a),
        .multdiv_operand_b_i     (multdiv_operand_b),
        .multdiv_ready_id_i      (1'b1),
        .data_ind_timing_i       (data_ind_timing),
        
        // Branch (unused)
        .bt_a_operand_i          (32'b0),
        .bt_b_operand_i          (32'b0),
        
        // IMD Loopback
        .imd_val_q_i             (imd_val_q),
        .imd_val_d_o             (imd_val_d),
        .imd_val_we_o            (imd_val_we),
        
        // Outputs
        .alu_adder_result_ex_o   (alu_adder_result),
        .result_ex_o             (result_ex),
        .branch_target_o         (branch_target),
        .branch_decision_o       (branch_decision),
        .ex_valid_o              (ex_valid),
        
        // BIST (dormant)
        .core_sleep_i            (1'b0),
        .sim_fault_inject_i      (1'b0),
        .bist_error_irq_o        (bist_error_irq),
        .paddr_i                 (32'b0),
        .psel_i                  (1'b0),
        .penable_i               (1'b0),
        .pwrite_i                (1'b0),
        .pwdata_i                (32'b0),
        .prdata_o                (prdata),
        .pready_o                (pready)
    );

    // =========================================================================
    // Output Assignment
    // =========================================================================
    
    // Status LEDs
    assign led_o[0] = ex_valid;       // Execution valid
    assign led_o[1] = test_running;   // Test in progress
    assign led_o[2] = test_pass;      // Last test passed
    assign led_o[3] = bist_error_irq; // BIST error
    
    // Result preview (lower 8 bits of last result)
    assign led_result_o = test_result_reg[7:0];

endmodule
