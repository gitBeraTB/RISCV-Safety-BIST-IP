`ifndef PRIM_ASSERT_SV
`define PRIM_ASSERT_SV

// ----------------------------------------------------------------
// VIVADO SYNTHESIS STUB (FINAL VERSION)
// Argüman hatalarını çözen, varsayılan değerli makrolar.
// ----------------------------------------------------------------

// 1. Standart Assertionlar (Varsayılan argümanlı - Hata Çözücü Kısım)
//    clk ve rst verilmezse hata verme, 0 kabul et.

`define ASSERT_I(name, expr)
`define ASSERT_INIT(name, expr)
`define ASSERT_FINAL(name, expr)

// HATAYI ÇÖZEN SATIRLAR BURADA: " = 0 " ekledik.
`define ASSERT(name, expr, clk = 0, rst = 0)
`define ASSERT_NEVER(name, expr, clk = 0, rst = 0)
`define ASSERT_KNOWN(name, signal, clk = 0, rst = 0)
`define ASSERT_KNOWN_IF(name, signal, cond, clk = 0, rst = 0)
`define ASSUME(name, expr, clk = 0, rst = 0)
`define ASSUME_FPV(name, expr, clk = 0, rst = 0)
`define COVER(name, expr, clk = 0, rst = 0)

// 2. Diğerleri
`define ASSUME_I(name, expr)
`define ASSERT_IF(name, expr, cond)
`define ASSERT_INIT_NET(name, expr)

// 3. Coverage (Syntax hatası yaratanlar)
`define DV_FCOV_SIGNAL(type, name, expr)
`define DV_FCOV_SIGNAL_GEN_IF(type, name, expr, cond)
`define ASSERT_STATIC_IN_PACKAGE(name, expr)
`endif