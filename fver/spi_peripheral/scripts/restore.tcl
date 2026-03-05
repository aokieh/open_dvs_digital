
# XM-Sim Command File
# TOOL:	xmsim(64)	25.03-s002
#
#
# You can restore this configuration with:
#
#      xrun -64bit -timescale 1ns/1ps +gui +access+rwc -sv -DUNIT_DELAY -DFUNCTIONAL +define+USE_POWER_PINS +nospecify +nowarnNODNTW -f ../scripts/xrun.f -s -input /LinuxRAID/home/aokieh1/projects/open_dvs_digital/fver/spi_peripheral/scripts/restore.tcl
#

set tcl_prompt1 {puts -nonewline "xcelium> "}
set tcl_prompt2 {puts -nonewline "> "}
set vlog_format %h
set vhdl_format %v
set real_precision 6
set display_unit auto
set time_unit module
set heap_garbage_size -200
set heap_garbage_time 0
set assert_report_level note
set assert_stop_level error
set autoscope yes
set assert_1164_warnings yes
set pack_assert_off {}
set severity_pack_assert_off {note warning}
set assert_output_stop_level failed
set tcl_debug_level 0
set relax_path_name 1
set vhdl_vcdmap XX01ZX01X
set intovf_severity_level ERROR
set probe_screen_format 0
set rangecnst_severity_level ERROR
set textio_severity_level ERROR
set vital_timing_checks_on 1
set vlog_code_show_force 0
set assert_count_attempts 1
set tcl_all64 false
set tcl_runerror_exit false
set assert_report_incompletes 0
set show_force 1
set force_reset_by_reinvoke 0
set tcl_relaxed_literal 0
set probe_exclude_patterns {}
set probe_packed_limit 4k
set probe_unpacked_limit 16k
set assert_internal_msg no
set svseed 1
set assert_reporting_mode 0
set vcd_compact_mode 0
set vhdl_forgen_loopindex_enum_pos 0
set xmreplay_dc_debug 0
set tcl_runcmd_interrupt next_command
set tcl_sigval_prefix {#}
set gate_loop_warn_size 1
alias . run
alias indago verisium
alias quit exit
database -open -shm -into waves.shm waves -default
probe -create -database waves tb.CIPO tb.COPI tb.CS_N tb.SCK tb.addr_reg tb.clk tb.rdata_reg tb.rdata_spi_0 tb.rdata_spi_1 tb.rst_n tb.shift_en_fifo tb.spi_ctrl tb.wdata_reg tb.we_reg tb.wmask_reg -all -depth  2
probe -create -database waves tb.i_spi_peripheral.addr_valid tb.i_spi_peripheral.cycle_count tb.i_spi_peripheral.en_rx_addr tb.i_spi_peripheral.en_rx_opcode tb.i_spi_peripheral.en_rx_rdata
probe -create -database waves tb.i_spi_peripheral.rx_data_0 tb.i_spi_peripheral.rx_data_1 tb.i_spi_peripheral.rx_data_2 tb.i_spi_peripheral.rx_data_3
probe -create -database waves tb.i_spi_peripheral.mem_write_next_re

simvision -input restore.tcl.svcf
