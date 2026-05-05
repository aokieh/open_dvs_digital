# PDK specific cell library and design primitives - needed for gate level sims
// -v /LinuxRAID/home/aokieh1/projects/digital_top_hardened_macro/dependencies/pdks/sky130A/libs.ref/sky130_fd_sc_hd/verilog/sky130_fd_sc_hd.v
// -v /LinuxRAID/home/aokieh1/projects/digital_top_hardened_macro/dependencies/pdks/sky130A/libs.ref/sky130_fd_sc_hd/verilog/primitives.v

# Netlist of synthesized design - needed for gate level sims
// /tmp/aokieh1/openlane_test/caravel_user/openlane/sync_fifo/runs/26_01_30_12_21/final/pnl/sync_fifo.pnl.v
// /tmp/aokieh1/openlane_test/caravel_user/openlane/final_top/runs/26_04_21_21_33/final/pnl/final_top.pnl.v
// /tmp/aokieh1/openlane_test/caravel_user/openlane/final_top/runs/26_04_21_21_33/final/nl/final_top.nl.v

# contains helper class for tb spi instruction set
// ../../common/pkg_spi_fver.sv

# contains values for regfile macros, data sizes
../../../source/design/common/defines.sv
../verilog/user_defines.sv


# Testbench & DUT files for clk divider
// ../../../source/design/roic/clk_div.sv
// ../clk_div_tb.sv

# Testbench & DUT files for ROIC FSM
// ../../../source/design/roic/roic_sm.sv
// ../roic_sm_tb.sv


# Testbench & DUT files for Digital Top (SPI Slave + Register File)
../../../source/design/regfile/regfile_final.sv
../../../source/design/regfile/spi_peripheral_re.sv
// ../../../source/design/regfile/spi_peripheral_final.sv
// ../../../source/design/regfile/spi_peripheral.sv
// ../../../source/design/final_macros/digital_top.sv
// ../../digital_top/self_check_tb.sv

# Testbench & DUT files for Column Readout Macro (FIFO + Event Reset)
../../../source/design/sync_fifo/sync_fifo.sv
../../../source/design/sync_fifo/fifo_intf3.sv
../../../source/design/sync_fifo/sync_fifo_top3.sv
../../../source/design/final_macros/col_readout_macro.sv


// ../col_readout_macro_tb.sv

# Testbench & DUT files for Row Decoder Macro (FSM + Row Scanner)
// ../../../source/design/roic/roic_sm.sv
../../../source/design/roic/roic_sm2.sv
../../../source/design/roic/row_scanner.sv
// ../../../source/design/final_macros/row_decoder_macro.sv
../../../source/design/final_macros/row_decoder_macro2.sv
// ../row_decoder_macro_tb.sv
// ../row_decoder_macro2_tb.sv

# Testbench & DUT files for DVS FSM (Column Readout + Row Decoder)
// ../../../source/design/final_macros/fifo_rows_cols_macro.sv
../../../source/design/final_macros/fifo_rows_cols_macro2.sv
// ../../../source/design/final_macros/final_top.sv
// ../../../source/design/final_macros/final_top2.sv
// ../../../source/design/final_macros/final_top2_final.sv <-- prev final
../../../source/design/final_macros/final_top3.sv
// ../fifo_rows_cols_macro_tb.sv
// ../fifo_rows_cols_macro2_tb.sv
../verilog/user_project_wrapper.sv
../verilog/blackboxes.sv

# Testbench & DUT for Final Top Level (Col, Row, SPI, Regfile)
// ../../../source/design/final_macros/final_top.sv
// ../final_top_tb.sv
// ../final_top_tb2.sv
// ../final_top_tb3.sv
// ../final_top_tb_gls.sv
../verilog/user_project_wrapper_tb.sv