## ============================================================================
## RISC-V BIST IP — Vivado Project Creation Script
## 
## Usage:
##   1. Open Vivado
##   2. In Tcl Console: cd <path-to-RISCV-Safety-BIST-IP>/Vivado/scripts
##   3. source create_project.tcl
##
## Or from command line:
##   vivado -mode batch -source create_project.tcl
## ============================================================================

# --- Configuration ---
set project_name  "riscv_bist_ip"
set part          "xc7a35tcpg236-1"       ;# Artix-7 35T (Basys3 / Arty compatible)
set top_module    "fpga_top"               ;# FPGA wrapper (reduces I/O count)

# Paths (relative to this script's location)
set script_dir    [file dirname [info script]]
set proj_root     [file normalize "$script_dir/.."]
set rtl_dir       "$proj_root/rtl"
set pkg_dir       "$proj_root/rtl/packages"
set sim_dir       "$proj_root/sim"
set xdc_dir       "$proj_root/constraints"
set proj_dir      "$proj_root/project"

# --- Create Project ---
puts "============================================"
puts " Creating Vivado Project: $project_name"
puts " Target FPGA: $part"
puts "============================================"

create_project $project_name $proj_dir -part $part -force

# --- Add Package Files (must be added first for compilation order) ---
puts "\n--- Adding Package Files ---"
set pkg_files [glob -nocomplain "$pkg_dir/*.sv"]
if {[llength $pkg_files] > 0} {
    add_files -fileset sources_1 $pkg_files
    foreach f $pkg_files {
        puts "  + [file tail $f]"
    }
}

# --- Add RTL Source Files ---
puts "\n--- Adding RTL Source Files ---"
set rtl_files [glob -nocomplain "$rtl_dir/*.sv"]
if {[llength $rtl_files] > 0} {
    add_files -fileset sources_1 $rtl_files
    foreach f $rtl_files {
        puts "  + [file tail $f]"
    }
}

# --- Add Constraint Files ---
puts "\n--- Adding Constraint Files ---"
set xdc_files [glob -nocomplain "$xdc_dir/*.xdc"]
if {[llength $xdc_files] > 0} {
    add_files -fileset constrs_1 $xdc_files
    foreach f $xdc_files {
        puts "  + [file tail $f]"
    }
}

# --- Add Simulation Sources ---
puts "\n--- Adding Simulation Sources ---"
set sim_files [glob -nocomplain "$sim_dir/*.sv"]
if {[llength $sim_files] > 0} {
    add_files -fileset sim_1 $sim_files
    foreach f $sim_files {
        puts "  + [file tail $f]"
    }
}

# --- Set Properties ---
set_property top $top_module [current_fileset]
set_property top tb_ibex_ex_block [get_filesets sim_1]
set_property -name {xsim.simulate.runtime} -value {1000ns} -objects [get_filesets sim_1]

# Set SystemVerilog file type for all .sv files
foreach f [get_files -of_objects [get_filesets sources_1] *.sv] {
    set_property file_type SystemVerilog $f
}
foreach f [get_files -of_objects [get_filesets sim_1] *.sv] {
    set_property file_type SystemVerilog $f
}

# --- Set Package Compilation Order (packages must compile first) ---
puts "\n--- Setting Compilation Order ---"
# Force ibex_pkg.sv to compile first
set ibex_pkg_file [get_files -of_objects [get_filesets sources_1] "ibex_pkg.sv"]
if {$ibex_pkg_file ne ""} {
    set_property is_global_include true $ibex_pkg_file
}

# Auto-update compile order
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

# --- Summary ---
puts "\n============================================"
puts " Project created successfully!"
puts "============================================"
puts " Location: $proj_dir"
puts " Top Module: $top_module"
puts " Target Part: $part"
puts ""
puts " Next steps:"
puts "   1. Run Synthesis:      launch_runs synth_1 -jobs 4"
puts "   2. Run Implementation: launch_runs impl_1 -jobs 4"
puts "   3. Run Simulation:     launch_simulation"
puts "============================================"
