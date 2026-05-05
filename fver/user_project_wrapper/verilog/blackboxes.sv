/* verilator lint_off UNUSEDSIGNAL */
/* verilator lint_off UNDRIVEN */

// blackboxes.sv - ONLY for macros NOT fully defined in config.json

// blackboxes.sv
(* blackbox *)
module Imager_Top_no_m5 (
    inout vdda1, 
    inout vssa1, 
    // Outputs (Driven by Imager to Digital)
    output [63:0] array_col_top_left, array_col_top_right,
    output [63:0] array_col_bot_left, array_col_bot_right,
    
    // Inputs (Driven by Digital to Imager)
    input [63:0] col_event_rst_top_left, col_event_rst_top_right,
    input [63:0] col_event_rst_bot_left, col_event_rst_bot_right,
    
    input [63:0] row_on_detect_top, row_off_detect_top,
    input [63:0] row_on_detect_bot, row_off_detect_bot,
    
    input pre_charge_global_top_left, pre_charge_global_top_right,
    input detect_pulse_global_top_left, detect_pulse_global_top_right,
    input pre_charge_global_bot_left, pre_charge_global_bot_right,
    input detect_pulse_global_bot_left, detect_pulse_global_bot_right,
    
    input [10:0] dac_config_0, dac_config_1, dac_config_2, dac_config_3, dac_config_4,
    input [10:0] dac_config_5, dac_config_6, dac_config_7, dac_config_8, dac_config_9,

    input pix_rst_global_top_left,
    input pix_rst_global_bot_left,
    input pix_rst_global_top_right,
    input pix_rst_global_bot_right
);
endmodule