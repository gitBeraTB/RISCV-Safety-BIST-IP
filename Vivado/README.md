# Vivado Synthesis & Implementation — RISC-V BIST IP

Bu dizin, RISC-V Ibex Core BIST IP projesinin **Xilinx Vivado** ile doğrudan Synthesis ve Implementation yapılabilecek versiyonunu içerir.

## 📁 Dizin Yapısı

```text
Vivado/
├── rtl/                    # Sentez kaynakları
│   ├── packages/           # SystemVerilog paketleri
│   │   ├── ibex_pkg.sv
│   │   ├── edn_pkg.sv
│   │   ├── prim_mubi_pkg.sv
│   │   ├── flash_ctrl_top_specific_pkg.sv
│   │   └── top_racl_pkg.sv
│   ├── ibex_alu.sv         # ALU (Vivado-native packed arrays)
│   ├── ibex_multdiv_fast.sv # Çarpıcı/Bölücü (Vivado-native)
│   ├── ibex_ex_block.sv    # Execution Block (Vivado-native)
│   ├── ibex_alu_bist_wrapper.sv
│   ├── runtime_bist_controller.sv
│   ├── top_runtime_bist.sv
│   ├── lfsr_gen.sv
│   ├── misr_analyzer.sv
│   ├── idle_detector.sv
│   ├── apb_slave_if.sv
│   └── prim_assert.sv
├── sim/
│   └── tb_ibex_ex_block.sv # Vivado Behavioral Simulation testbench
├── constraints/
│   └── timing.xdc          # 100 MHz, Artix-7 timing constraints
├── scripts/
│   └── create_project.tcl  # Otomatik proje oluşturma scripti
└── README.md
```

## 🚀 Hızlı Başlangıç

### Yöntem 1: TCL Script ile Otomatik

```bash
# Vivado'yu aç ve Tcl Console'da:
cd <proje-yolu>/RISCV-Safety-BIST-IP/Vivado/scripts
source create_project.tcl
```

### Yöntem 2: Komut Satırından

```bash
vivado -mode batch -source Vivado/scripts/create_project.tcl
```

### Yöntem 3: Manuel

1. Vivado'da yeni proje oluştur → Part: `xc7a35tcpg236-1`
2. `rtl/packages/*.sv` dosyalarını **Design Sources** olarak ekle
3. `rtl/*.sv` dosyalarını **Design Sources** olarak ekle
4. `constraints/timing.xdc` dosyasını **Constraints** olarak ekle
5. `sim/tb_ibex_ex_block.sv` dosyasını **Simulation Sources** olarak ekle
6. Top Module → `ibex_ex_block`

## 🔧 Synthesis & Implementation

```tcl
# Synthesis çalıştır
launch_runs synth_1 -jobs 4
wait_on_run synth_1

# Implementation çalıştır
launch_runs impl_1 -jobs 4
wait_on_run impl_1

# Raporları aç
open_run impl_1
report_utilization
report_timing_summary
```

## 🧪 Behavioral Simulation

```tcl
launch_simulation
```

**Test Senaryoları:**

| Test | İşlem | Giriş | Beklenen Sonuç |
|------|-------|-------|----------------|
| 1 | ALU ADD | 15 + 25 | 40 |
| 2 | ALU SUB | 100 - 30 | 70 |
| 3 | MULT | 12 × 12 | 144 |
| 4 | MULT (Stress) | 1000 × 500 | 500,000 |

## 📌 HDL/ vs Vivado/ Farkı

| Özellik | `HDL/` (Icarus) | `Vivado/` |
|---------|-----------------|-----------|
| Array Portları | Flat (`_0`, `_1`) | Packed (`[1:0][31:0]`) |
| Import | Top-level `import` | Module-scoped `import` |
| Assertions | `ifdef` korumalı | Tam SVA desteği |
| Hedef | Cocotb + CI simülasyonu | FPGA sentezi |

## 🎯 Hedef FPGA

- **Varsayılan**: Artix-7 `xc7a35tcpg236-1` (Basys3 / Arty uyumlu)
- **Değiştirmek için**: `create_project.tcl` içinde `set part` satırını düzenle
