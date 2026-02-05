# PDK specific cell library and design primitives
-v /LinuxRAID/home/aokieh1/projects/digital_top_hardened_macro/dependencies/pdks/sky130A/libs.ref/sky130_fd_sc_hd/verilog/sky130_fd_sc_hd.v
-v /LinuxRAID/home/aokieh1/projects/digital_top_hardened_macro/dependencies/pdks/sky130A/libs.ref/sky130_fd_sc_hd/verilog/primitives.v

# Netlist of synthesized design
/tmp/aokieh1/openlane_test/caravel_user/openlane/regfile/runs/26_02_04_11_19/final/pnl/regfile.pnl.v

# contains helper class for tb spi instruction set
../../common/pkg_spi_fver.sv

# contains values for regfile macros, data sizes
../../../source/design/common/defines.sv


# SPI, Register file
../../../source/design/regfile/regfile.sv

# testbench DUT file
../tb.sv