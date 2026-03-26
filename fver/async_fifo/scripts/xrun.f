# PDK specific cell library and design primitives
// -v /LinuxRAID/home/aokieh1/projects/digital_top_hardened_macro/dependencies/pdks/sky130A/libs.ref/sky130_fd_sc_hd/verilog/sky130_fd_sc_hd.v
// -v /LinuxRAID/home/aokieh1/projects/digital_top_hardened_macro/dependencies/pdks/sky130A/libs.ref/sky130_fd_sc_hd/verilog/primitives.v

# Netlist of synthesized design
// /tmp/aokieh1/openlane_test/caravel_user/openlane/sync_fifo/runs/26_01_30_12_21/final/pnl/sync_fifo.pnl.v

# contains helper class for tb spi instruction set
../../common/pkg_spi_fver.sv

# contains values for regfile macros, data sizes
../../../source/design/common/defines.sv


# Design file
../../../source/design/async_fifo/async_fifo.sv
../../../source/design/async_fifo/async_fifo_top.sv
../../../source/design/async_fifo/async_write_intf.sv

# Testbench DUT file
../async_fifo_top_tb.sv