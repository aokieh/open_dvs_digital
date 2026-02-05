# PDK specific cell library and design primitives
-v /LinuxRAID/home/aokieh1/projects/digital_top_hardened_macro/dependencies/pdks/sky130A/libs.ref/sky130_fd_sc_hd/verilog/sky130_fd_sc_hd.v
-v /LinuxRAID/home/aokieh1/projects/digital_top_hardened_macro/dependencies/pdks/sky130A/libs.ref/sky130_fd_sc_hd/verilog/primitives.v

# Netlist of synthesized design
/tmp/aokieh1/openlane_test/caravel_user/openlane/spi_peripheral/runs/26_02_03_17_06/final/pnl/spi_peripheral.pnl.v

# contains helper class for tb spi instruction set
../../common/pkg_spi_fver.sv

# contains values for regfile macros, data sizes
../../../source/design/common/defines.sv


# Design files
../../../source/design/regfile/spi_peripheral.sv

# Testbench DUT file
../tb.sv