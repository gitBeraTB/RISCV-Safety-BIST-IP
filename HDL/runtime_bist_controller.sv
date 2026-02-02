module runtime_bist_controller #(
    parameter DATA_WIDTH = 32
)(
    input  logic        clk,
    input  logic        rst_n,

    // --- System Interface ---
    input  logic        sys_req_valid,
    output logic        bist_active_mode,
    input  logic [DATA_WIDTH-1:0] dut_result_in,

    // --- BIST Interface ---
    output logic [DATA_WIDTH-1:0] bist_pattern_out,

    // --- APB Interface ---
    input  logic [31:0] paddr,
    input  logic        psel,
    input  logic        penable,
    input  logic        pwrite,
    input  logic [31:0] pwdata,
    output logic [31:0] prdata,
    output logic        pready,
    
    output logic        error_irq
);

    // --- ANSI Colors ---
    localparam string STR_RED    = "\033[31m";
    localparam string STR_RESET  = "\033[0m";

    // --- Internal Signals ---
    logic [7:0]  reg_addr;
    logic [31:0] reg_wdata;
    logic        reg_write_en;
    logic [31:0] reg_rdata_mux;

    // --- Registers ---
    logic [31:0] reg_ctrl;
    logic [31:0] reg_status;
    logic [31:0] reg_threshold;
    logic [31:0] reg_golden_sig;
    
    logic        idle_detected;
    logic        lfsr_en, misr_en, misr_clear;
    logic [31:0] misr_signature;
    logic [7:0]  test_cycle_cnt;

    // --- FSM States ---
    typedef enum logic [2:0] {
        IDLE,
        WAIT_FOR_SLOT,
        RUN_TEST,
        CHECK_RESULT,
        ABORT
    } state_t;

    state_t state, next_state;

    // 1. APB INSTANCE
    apb_slave_if #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) u_apb_if (
        .clk(clk), .rst_n(rst_n),
        .paddr(paddr), .psel(psel), .penable(penable),
        .pwrite(pwrite), .pwdata(pwdata), .prdata(prdata), .pready(pready), .pslverr(),
        .reg_addr(reg_addr), .reg_wdata(reg_wdata), .reg_write_en(reg_write_en),
        .reg_read_en(), .reg_rdata(reg_rdata_mux)
    );

    // 2. REGISTERS
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            reg_ctrl <= '0;
            reg_threshold <= 32'd100;
            reg_golden_sig <= 32'hFFFF_FFFF; 
        end else if (reg_write_en) begin
            case(reg_addr)
                8'h00: reg_ctrl <= reg_wdata;
                8'h08: reg_threshold <= reg_wdata;
                8'h0C: reg_golden_sig <= reg_wdata;
            endcase
        end
    end

    // READ MUX
    always_comb begin
        case(reg_addr)
            8'h00: reg_rdata_mux = reg_ctrl;
            8'h04: reg_rdata_mux = reg_status;
            8'h08: reg_rdata_mux = reg_threshold;
            8'h0C: reg_rdata_mux = reg_golden_sig;
            8'h10: reg_rdata_mux = misr_signature;
            default: reg_rdata_mux = 32'h0;
        endcase
    end

    // 3. SUB-MODULES
    idle_detector #(.TIMER_WIDTH(32)) u_idle_det (
        .clk(clk), .rst_n(rst_n), .system_valid(sys_req_valid),
        .threshold(reg_threshold), .idle_trigger(idle_detected)
    );

    lfsr_gen u_lfsr (
        .clk(clk), .rst_n(rst_n), .enable(lfsr_en),
        .seed_load(1'b0), .seed_data(32'h0), .pattern_out(bist_pattern_out)
    );

    misr_analyzer u_misr (
        .clk(clk), .rst_n(rst_n), .enable(misr_en), .clear(misr_clear),
        .dut_response(dut_result_in), .signature(misr_signature)
    );

    // 4. FSM 
    // State Reg
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else state <= next_state;
    end

    // Counter
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) test_cycle_cnt <= 0;
        else if (state == RUN_TEST) test_cycle_cnt <= test_cycle_cnt + 1;
        else if (state == IDLE) test_cycle_cnt <= 0;
    end

    // Next State & Output Logic
    always_comb begin
        next_state = state;
        lfsr_en = 0;
        misr_en = 0;
        misr_clear = 0;
        bist_active_mode = 0; 
        
        case(state)
            IDLE: begin
                if (reg_ctrl[0]) next_state = WAIT_FOR_SLOT;
            end

            WAIT_FOR_SLOT: begin
                if (sys_req_valid) begin
                    // Wait
                end else if (idle_detected) begin
                    next_state = RUN_TEST;
                end
            end

            RUN_TEST: begin
                bist_active_mode = 1;
                lfsr_en = 1;
                misr_en = 1;
                if (test_cycle_cnt == 0) begin
                    misr_clear = 1;
                end

                if (sys_req_valid) begin
                    next_state = ABORT;
                end else if (test_cycle_cnt == 8'hFF) begin
                    next_state = CHECK_RESULT;
                end
            end

            CHECK_RESULT: begin
                next_state = IDLE; 
            end
            
            ABORT: begin
                bist_active_mode = 0; 
                next_state = WAIT_FOR_SLOT; 
            end
        endcase
    end

    // Status Logic (CRITICAL FIX: Sticky Status)
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            reg_status <= 0;
            error_irq <= 0;
        end else begin
            reg_status[0] <= (state == RUN_TEST); // Bit 0: Busy
            
            if (state == CHECK_RESULT) begin
                if (misr_signature == reg_golden_sig) begin
                    reg_status[2] <= 1; // Bit 2: Pass
                end else begin
                    reg_status[1] <= 1; // Bit 1: Fail
                    error_irq <= 1;
                    // synthesis translate_off
                    $display("%s[FAIL] Signature Mismatch! Exp: %h, Got: %h%s", STR_RED, reg_golden_sig, misr_signature, STR_RESET);
                    // synthesis translate_on
                end
            end
            if (state == RUN_TEST && test_cycle_cnt == 0) begin
                reg_status[2:1] <= 0;
                error_irq <= 0;
            end
        end
    end

    // =========================================================================
    // 5. SYSTEMVERILOG ASSERTIONS (Vivado/Questa Only)
    // =========================================================================
`ifndef __ICARUS__
    // synthesis translate_off
    property p_safety_interruption;
        @(posedge clk) disable iff (!rst_n)
        (sys_req_valid) |=> (!bist_active_mode);
    endproperty

    a_safety_check: assert property (p_safety_interruption)
        else $error("%s[SVA ERROR] Safety Violation!%s", STR_RED, STR_RESET);

    // synthesis translate_on
`endif

endmodule