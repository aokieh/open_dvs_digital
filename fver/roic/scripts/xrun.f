# PDK specific cell library and design primitives - needed for gate level sims
// -v /LinuxRAID/home/aokieh1/projects/digital_top_hardened_macro/dependencies/pdks/sky130A/libs.ref/sky130_fd_sc_hd/verilog/sky130_fd_sc_hd.v
// -v /LinuxRAID/home/aokieh1/projects/digital_top_hardened_macro/dependencies/pdks/sky130A/libs.ref/sky130_fd_sc_hd/verilog/primitives.v

# Netlist of synthesized design - needed for gate level sims
// /tmp/aokieh1/openlane_test/caravel_user/openlane/sync_fifo/runs/26_01_30_12_21/final/pnl/sync_fifo.pnl.v

# contains helper class for tb spi instruction set
../../common/pkg_spi_fver.sv

# contains values for regfile macros, data sizes
../../../source/design/common/defines.sv


# Testbench & DUT files for clk divider
// ../../../source/design/roic/clk_div.sv
// ../clk_div_tb.sv

# Testbench & DUT files for ROIC FSM
// ../../../source/design/roic/roic_sm.sv
// ../roic_sm_tb.sv


# Testbench & DUT files for ROIC Top
../../../source/design/roic/roic_top.sv
../../../source/design/roic/roic_sm.sv
../../../source/design/roic/row_scanner.sv
../../../source/design/roic/col_event_rst.sv
// ../roic_top_tb_128.sv
../roic_top_tb_64.sv

# Testbench & DUT files for ROIC Top - Ryan analog test files
// ../../../source/design/roic/roic_top0.sv
// ../../../source/design/roic/roic_sm0.sv
// ../../../source/design/roic/row_scanner0.sv
// ../../../source/design/roic/col_event_rst0.sv
// ../roic_top_tb_2x1.sv