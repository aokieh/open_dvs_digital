# -v /LinuxRAID/home/aokieh1/projects/digital_top_hardened_macro/dependencies/pdks/sky130A/libs.ref/sky130_fd_sc_hd/verilog/sky130_fd_sc_hd.v
# -v /LinuxRAID/home/aokieh1/projects/digital_top_hardened_macro/dependencies/pdks/sky130A/libs.ref/sky130_fd_sc_hd/verilog/primitives.v
# /LinuxRAID/home/aokieh1/projects/digital_top_hardened_macro/openlane/digital_top/runs/antenna_clean/final/pnl/digital_top.pnl.v

# contains helper class for tb spi instruction set
../../common/pkg_spi_fver.sv

# contains values for regfile macros, data sizes
../../../source/design/common/defines.sv

# Design files in a bottom-up manner

# FIFO
../../../source/design/sync_fifo/sync_fifo.sv
../../../source/design/sync_fifo/fifo_intf.sv
../../../source/design/sync_fifo/sync_fifo_top.sv

# SPI, Register file
../../../source/design/regfile/regfile.sv
../../../source/design/regfile/spi_peripheral.sv

# Top level wrapper
../../../source/design/spi_fifo_reg/spi_fifo_regfile.sv

# testbench DUT file
../spi_fifo_reg_tb.sv