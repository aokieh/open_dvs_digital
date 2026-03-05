# PDK specific cell library and design primitives
// -v /LinuxRAID/home/aokieh1/projects/digital_top_hardened_macro/dependencies/pdks/sky130A/libs.ref/sky130_fd_sc_hd/verilog/sky130_fd_sc_hd.v
// -v /LinuxRAID/home/aokieh1/projects/digital_top_hardened_macro/dependencies/pdks/sky130A/libs.ref/sky130_fd_sc_hd/verilog/primitives.v

# Netlist of synthesized design
// /LinuxRAID/home/aokieh1/projects/digital_top_hardened_macro/openlane/digital_top/runs/antenna_clean/final/pnl/digital_top.pnl.v

# contains helper class for tb spi instruction set
../../common/pkg_spi_fver.sv

# contains values for regfile macros, data sizes
../../../source/design/common/defines.sv

# SPI, Register file
../../../source/design/digital_top/digital_top.sv
../../../source/design/regfile/spi_peripheral.sv
../../../source/design/regfile/regfile.sv

# testbench DUT file
../self_check_tb.sv
//  ../tb.sv
