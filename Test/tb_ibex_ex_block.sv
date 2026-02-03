`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/03/2026 03:05:25 AM
// Design Name: 
// Module Name: tb_ibex_ex_block
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

module tb_ibex_ex_block;

  // -------------------------------------------------------------------------
  // 1. Parametreler ve Sinyaller
  // -------------------------------------------------------------------------
  import ibex_pkg::*; // Ibex türlerini (ALU_ADD, MD_OP_MULL vb.) kullanmak için

  // Clock ve Reset
  logic clk_i;
  logic rst_ni;

  // Girişler (Inputs)
  logic [31:0] alu_operand_a_i;
  logic [31:0] alu_operand_b_i;
  alu_op_e     alu_operator_i;
  logic        alu_instr_first_cycle_i;

  logic [31:0] multdiv_operand_a_i;
  logic [31:0] multdiv_operand_b_i;
  md_op_e      multdiv_operator_i;
  logic        mult_en_i;
  logic        div_en_i;
  logic        mult_sel_i;
  logic        div_sel_i;
  logic [1:0]  multdiv_signed_mode_i;
  logic        multdiv_ready_id_i;
  logic        data_ind_timing_i;

  // Ara Değer (Intermediate Value) Loopback
  // Ex_Block bir çıktı verip bir sonraki döngüde onu geri ister.
  logic [31:0] imd_val_q_i[2];
  logic [31:0] imd_val_d_o[2];
  logic [1:0]  imd_val_we_o;

  // Çıkışlar (Outputs)
  logic [31:0] result_ex_o;
  logic        ex_valid_o;
  logic        branch_decision_o; // Kullanılmayacak ama bağlayalım

  // Diğer Kullanılmayanlar (Hata almamak için 0'a bağlayacağız)
  logic core_sleep_i = 0;
  logic sim_fault_inject_i = 0;
  logic [31:0] paddr_i = 0;
  logic psel_i = 0;
  logic penable_i = 0;
  logic pwrite_i = 0;
  logic [31:0] pwdata_i = 0;
  logic [31:0] bt_a_operand_i = 0;
  logic [31:0] bt_b_operand_i = 0;

  // -------------------------------------------------------------------------
  // 2. Modül Bağlantısı (DUT - Device Under Test)
  // -------------------------------------------------------------------------
  ibex_ex_block #(
    .RV32M(RV32MFast), // Hızlı çarpıcıyı test ediyoruz
    .RV32B(RV32BNone)
  ) u_dut (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    
    // ALU Bağlantıları
    .alu_operator_i(alu_operator_i),
    .alu_operand_a_i(alu_operand_a_i),
    .alu_operand_b_i(alu_operand_b_i),
    .alu_instr_first_cycle_i(alu_instr_first_cycle_i),
    
    // MultDiv Bağlantıları
    .multdiv_operator_i(multdiv_operator_i),
    .mult_en_i(mult_en_i),
    .div_en_i(div_en_i),
    .mult_sel_i(mult_sel_i),
    .div_sel_i(div_sel_i),
    .multdiv_signed_mode_i(multdiv_signed_mode_i),
    .multdiv_operand_a_i(multdiv_operand_a_i),
    .multdiv_operand_b_i(multdiv_operand_b_i),
    .multdiv_ready_id_i(multdiv_ready_id_i),
    .data_ind_timing_i(data_ind_timing_i),
    
    // Intermediate Val (Kendi kuyruğunu ısıran yılan gibi bağlıyoruz)
    .imd_val_q_i(imd_val_q_i),
    .imd_val_d_o(imd_val_d_o),
    .imd_val_we_o(imd_val_we_o),
    
    // Çıkışlar
    .result_ex_o(result_ex_o),
    .ex_valid_o(ex_valid_o),
    .branch_decision_o(branch_decision_o),
    
    // Diğer (Dummy) Bağlantılar
    .core_sleep_i(core_sleep_i),
    .sim_fault_inject_i(sim_fault_inject_i),
    .bist_error_irq_o(), // Boş bıraktık
    .paddr_i(paddr_i), .psel_i(psel_i), .penable_i(penable_i), 
    .pwrite_i(pwrite_i), .pwdata_i(pwdata_i), .prdata_o(), .pready_o(),
    .bt_a_operand_i(bt_a_operand_i), .bt_b_operand_i(bt_b_operand_i),
    .branch_target_o()
  );

  // -------------------------------------------------------------------------
  // 3. Clock Generation ve Loopback Mantığı
  // -------------------------------------------------------------------------
  
  // 10ns Clock (100 MHz)
  always #5 clk_i = ~clk_i;

  // IMD Register Loopback (Çarpma işlemi çok turlu olduğu için hafızaya ihtiyaç duyar)
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      imd_val_q_i[0] <= 32'b0;
      imd_val_q_i[1] <= 32'b0;
    end else begin
      if (imd_val_we_o[0]) imd_val_q_i[0] <= imd_val_d_o[0];
      if (imd_val_we_o[1]) imd_val_q_i[1] <= imd_val_d_o[1];
    end
  end

  // -------------------------------------------------------------------------
  // 4. TEST SENARYOLARI
  // -------------------------------------------------------------------------
  initial begin
    // Başlangıç Değerleri
    clk_i = 0;
    rst_ni = 0; // Reset basılı
    alu_operand_a_i = 0; alu_operand_b_i = 0;
    multdiv_operand_a_i = 0; multdiv_operand_b_i = 0;
    mult_en_i = 0; div_en_i = 0;
    mult_sel_i = 0; div_sel_i = 0;
    alu_instr_first_cycle_i = 0;
    multdiv_ready_id_i = 1;
    data_ind_timing_i = 0;
    multdiv_signed_mode_i = 2'b00;

    $display("### SIMULASYON BASLIYOR ###");
    
    // Reset'i bırak
    #20 rst_ni = 1;
    #10;

    // --- TEST 1: ALU TOPLAMA (ADD) ---
    $display("TEST 1: ALU Toplama (15 + 25)");
    alu_operator_i = ALU_ADD;
    alu_operand_a_i = 32'd15;
    alu_operand_b_i = 32'd25;
    mult_sel_i = 0; // ALU seçili
    
    #10; // Bir clock bekle
    if (result_ex_o == 32'd40) 
      $display("  -> BASARILI: Sonuc = %d", result_ex_o);
    else 
      $display("  -> HATA: Beklenen 40, Gelen %d", result_ex_o);

    // --- TEST 2: ALU CIKARMA (SUB) ---
    #20;
    $display("TEST 2: ALU Cikarma (100 - 30)");
    alu_operator_i = ALU_SUB;
    alu_operand_a_i = 32'd100;
    alu_operand_b_i = 32'd30;
    
    #10;
    if (result_ex_o == 32'd70) 
      $display("  -> BASARILI: Sonuc = %d", result_ex_o);
    else 
      $display("  -> HATA: Beklenen 70, Gelen %d", result_ex_o);

    // --- TEST 3: MULTDIV CARPMA (MULT) ---
    // Burası kritik! Kestiğimiz 33-34. bitler burayı bozdu mu?
    #20;
    $display("TEST 3: MULT Carpma (12 * 12)");
    
    multdiv_operator_i = MD_OP_MULL; // Çarpmanın alt 32 biti
    multdiv_operand_a_i = 32'd12;
    multdiv_operand_b_i = 32'd12;
    multdiv_signed_mode_i = 2'b00; // Unsigned
    
    mult_en_i = 1;  // Çarpıcıyı başlat
    mult_sel_i = 1; // Çıkışta Çarpıcıyı seç (Mux)
    
    // İşlemin bitmesini bekle (Valid sinyali gelene kadar)
    wait(ex_valid_o == 1);
    
    if (result_ex_o == 32'd144) 
      $display("  -> BASARILI: Sonuc = %d", result_ex_o);
    else 
      $display("  -> HATA: Beklenen 144, Gelen %d", result_ex_o);

    mult_en_i = 0; // Enable kapat

    // --- TEST 4: BUYUK SAYI CARPIMI ---
    #40;
    $display("TEST 4: Buyuk Sayi Carpimi (1000 * 500)");
    
    multdiv_operand_a_i = 32'd1000;
    multdiv_operand_b_i = 32'd500;
    mult_en_i = 1;
    
    wait(ex_valid_o == 0); // Önceki işlem bitsin
    wait(ex_valid_o == 1); // Yeni işlem sonucu gelsin

    if (result_ex_o == 32'd500000) 
      $display("  -> BASARILI: Sonuc = %d", result_ex_o);
    else 
      $display("  -> HATA: Beklenen 500000, Gelen %d", result_ex_o);

    $display("### SIMULASYON BITTI ###");
    $finish;
  end

endmodule
