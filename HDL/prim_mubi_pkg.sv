// File: prim_mubi_pkg.sv
// Description: Multi-Bit Boolean Package (ALL WIDTHS: 4, 8, 12, 16, 20, 24, 28, 32)

package prim_mubi_pkg;

  // --------------------------------------------------------------------------
  // Width Parameters
  // --------------------------------------------------------------------------
  parameter int MuBi4Width  = 4;
  parameter int MuBi8Width  = 8;
  parameter int MuBi12Width = 12;
  parameter int MuBi16Width = 16;
  parameter int MuBi20Width = 20;
  parameter int MuBi24Width = 24;
  parameter int MuBi28Width = 28; // YENİ EKLENDİ (28-Bit)
  parameter int MuBi32Width = 32;

  // --------------------------------------------------------------------------
  // Enum Definitions
  // --------------------------------------------------------------------------
  typedef enum logic [MuBi4Width-1:0] {
    MuBi4True  = 4'h6,
    MuBi4False = 4'h9,
    MuBi4Inval = 4'h0 
  } mubi4_t;

  typedef enum logic [MuBi8Width-1:0] {
    MuBi8True  = 8'h69,
    MuBi8False = 8'h96,
    MuBi8Inval = 8'h00
  } mubi8_t;

  typedef enum logic [MuBi12Width-1:0] {
    MuBi12True  = 12'h696,
    MuBi12False = 12'h969,
    MuBi12Inval = 12'h000
  } mubi12_t;

  typedef enum logic [MuBi16Width-1:0] {
    MuBi16True  = 16'h6969,
    MuBi16False = 16'h9696,
    MuBi16Inval = 16'h0000
  } mubi16_t;

  typedef enum logic [MuBi20Width-1:0] {
    MuBi20True  = 20'h69696,
    MuBi20False = 20'h96969,
    MuBi20Inval = 20'h00000
  } mubi20_t;

  typedef enum logic [MuBi24Width-1:0] {
    MuBi24True  = 24'h696969,
    MuBi24False = 24'h969696,
    MuBi24Inval = 24'h000000
  } mubi24_t;

  // --- 28-BIT (YENİ) ---
  typedef enum logic [MuBi28Width-1:0] {
    MuBi28True  = 28'h6969696,
    MuBi28False = 28'h9696969,
    MuBi28Inval = 28'h0000000
  } mubi28_t;

  typedef enum logic [MuBi32Width-1:0] {
    MuBi32True  = 32'h69696969,
    MuBi32False = 32'h96969696,
    MuBi32Inval = 32'h00000000
  } mubi32_t;

  // --------------------------------------------------------------------------
  // Checkers (True/False/Invalid)
  // --------------------------------------------------------------------------
  
  // 4-BIT
  function automatic logic mubi4_test_true_strict(mubi4_t val); return (val == MuBi4True); endfunction
  function automatic logic mubi4_test_true_loose(mubi4_t val); return (val == MuBi4True); endfunction
  function automatic logic mubi4_test_false_strict(mubi4_t val); return (val == MuBi4False); endfunction
  function automatic logic mubi4_test_false_loose(mubi4_t val); return (val != MuBi4True); endfunction
  function automatic logic mubi4_test_invalid(mubi4_t val); return (val != MuBi4True && val != MuBi4False); endfunction

  // 8-BIT
  function automatic logic mubi8_test_true_strict(mubi8_t val); return (val == MuBi8True); endfunction
  function automatic logic mubi8_test_true_loose(mubi8_t val); return (val == MuBi8True); endfunction
  function automatic logic mubi8_test_invalid(mubi8_t val); return (val != MuBi8True && val != MuBi8False); endfunction
  
  // 12-BIT
  function automatic logic mubi12_test_true_strict(mubi12_t val); return (val == MuBi12True); endfunction
  function automatic logic mubi12_test_true_loose(mubi12_t val); return (val == MuBi12True); endfunction
  function automatic logic mubi12_test_invalid(mubi12_t val); return (val != MuBi12True && val != MuBi12False); endfunction

  // 16-BIT
  function automatic logic mubi16_test_true_strict(mubi16_t val); return (val == MuBi16True); endfunction
  function automatic logic mubi16_test_true_loose(mubi16_t val); return (val == MuBi16True); endfunction
  function automatic logic mubi16_test_invalid(mubi16_t val); return (val != MuBi16True && val != MuBi16False); endfunction

  // 20-BIT
  function automatic logic mubi20_test_true_strict(mubi20_t val); return (val == MuBi20True); endfunction
  function automatic logic mubi20_test_true_loose(mubi20_t val); return (val == MuBi20True); endfunction
  function automatic logic mubi20_test_invalid(mubi20_t val); return (val != MuBi20True && val != MuBi20False); endfunction

  // 24-BIT
  function automatic logic mubi24_test_true_strict(mubi24_t val); return (val == MuBi24True); endfunction
  function automatic logic mubi24_test_true_loose(mubi24_t val); return (val == MuBi24True); endfunction
  function automatic logic mubi24_test_invalid(mubi24_t val); return (val != MuBi24True && val != MuBi24False); endfunction

  // 28-BIT (YENİ)
  function automatic logic mubi28_test_true_strict(mubi28_t val); return (val == MuBi28True); endfunction
  function automatic logic mubi28_test_true_loose(mubi28_t val); return (val == MuBi28True); endfunction
  function automatic logic mubi28_test_invalid(mubi28_t val); return (val != MuBi28True && val != MuBi28False); endfunction

  // 32-BIT
  function automatic logic mubi32_test_true_strict(mubi32_t val); return (val == MuBi32True); endfunction
  function automatic logic mubi32_test_true_loose(mubi32_t val); return (val == MuBi32True); endfunction
  function automatic logic mubi32_test_invalid(mubi32_t val); return (val != MuBi32True && val != MuBi32False); endfunction

  // --------------------------------------------------------------------------
  // Logic Functions (OR / AND / Convert)
  // --------------------------------------------------------------------------
  
  // 4-bit
  function automatic mubi4_t mubi4_or_hi(mubi4_t a, mubi4_t b);
    return (a == MuBi4True || b == MuBi4True) ? MuBi4True : MuBi4False;
  endfunction
  function automatic mubi4_t mubi4_and_hi(mubi4_t a, mubi4_t b);
    return (a == MuBi4True && b == MuBi4True) ? MuBi4True : MuBi4False;
  endfunction
  function automatic mubi4_t mubi4_bool_to_mubi(logic b);
    return b ? MuBi4True : MuBi4False;
  endfunction

  // 8-bit
  function automatic mubi8_t mubi8_or_hi(mubi8_t a, mubi8_t b);
    return (a == MuBi8True || b == MuBi8True) ? MuBi8True : MuBi8False;
  endfunction
  function automatic mubi8_t mubi8_and_hi(mubi8_t a, mubi8_t b);
    return (a == MuBi8True && b == MuBi8True) ? MuBi8True : MuBi8False;
  endfunction
  function automatic mubi8_t mubi8_bool_to_mubi(logic b);
    return b ? MuBi8True : MuBi8False;
  endfunction

  // 12-bit
  function automatic mubi12_t mubi12_or_hi(mubi12_t a, mubi12_t b);
    return (a == MuBi12True || b == MuBi12True) ? MuBi12True : MuBi12False;
  endfunction
  function automatic mubi12_t mubi12_and_hi(mubi12_t a, mubi12_t b);
    return (a == MuBi12True && b == MuBi12True) ? MuBi12True : MuBi12False;
  endfunction
  function automatic mubi12_t mubi12_bool_to_mubi(logic b);
    return b ? MuBi12True : MuBi12False;
  endfunction

  // 16-bit
  function automatic mubi16_t mubi16_or_hi(mubi16_t a, mubi16_t b);
    return (a == MuBi16True || b == MuBi16True) ? MuBi16True : MuBi16False;
  endfunction
  function automatic mubi16_t mubi16_and_hi(mubi16_t a, mubi16_t b);
    return (a == MuBi16True && b == MuBi16True) ? MuBi16True : MuBi16False;
  endfunction
  function automatic mubi16_t mubi16_bool_to_mubi(logic b);
    return b ? MuBi16True : MuBi16False;
  endfunction

  // 20-bit
  function automatic mubi20_t mubi20_or_hi(mubi20_t a, mubi20_t b);
    return (a == MuBi20True || b == MuBi20True) ? MuBi20True : MuBi20False;
  endfunction
  function automatic mubi20_t mubi20_and_hi(mubi20_t a, mubi20_t b);
    return (a == MuBi20True && b == MuBi20True) ? MuBi20True : MuBi20False;
  endfunction
  function automatic mubi20_t mubi20_bool_to_mubi(logic b);
    return b ? MuBi20True : MuBi20False;
  endfunction

  // 24-bit
  function automatic mubi24_t mubi24_or_hi(mubi24_t a, mubi24_t b);
    return (a == MuBi24True || b == MuBi24True) ? MuBi24True : MuBi24False;
  endfunction
  function automatic mubi24_t mubi24_and_hi(mubi24_t a, mubi24_t b);
    return (a == MuBi24True && b == MuBi24True) ? MuBi24True : MuBi24False;
  endfunction
  function automatic mubi24_t mubi24_bool_to_mubi(logic b);
    return b ? MuBi24True : MuBi24False;
  endfunction

  // 28-bit 
  function automatic mubi28_t mubi28_or_hi(mubi28_t a, mubi28_t b);
    return (a == MuBi28True || b == MuBi28True) ? MuBi28True : MuBi28False;
  endfunction
  function automatic mubi28_t mubi28_and_hi(mubi28_t a, mubi28_t b);
    return (a == MuBi28True && b == MuBi28True) ? MuBi28True : MuBi28False;
  endfunction
  function automatic mubi28_t mubi28_bool_to_mubi(logic b);
    return b ? MuBi28True : MuBi28False;
  endfunction

  // 32-bit
  function automatic mubi32_t mubi32_or_hi(mubi32_t a, mubi32_t b);
    return (a == MuBi32True || b == MuBi32True) ? MuBi32True : MuBi32False;
  endfunction
  function automatic mubi32_t mubi32_and_hi(mubi32_t a, mubi32_t b);
    return (a == MuBi32True && b == MuBi32True) ? MuBi32True : MuBi32False;
  endfunction
  function automatic mubi32_t mubi32_bool_to_mubi(logic b);
    return b ? MuBi32True : MuBi32False;
  endfunction

endpackage