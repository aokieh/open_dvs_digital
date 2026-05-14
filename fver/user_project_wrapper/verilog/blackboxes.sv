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
    
    // input [10:0] dac_config_0, dac_config_1, dac_config_2, dac_config_3, dac_config_4,
    // input [10:0] dac_config_5, dac_config_6, dac_config_7, dac_config_8, dac_config_9,
    input [ 9:0] dac_bias,

    input pix_rst_global_top_left,
    input pix_rst_global_bot_left,
    input pix_rst_global_top_right,
    input pix_rst_global_bot_right
);
endmodule : Imager_Top_no_m5

// giorgos_bias_gen blackbox
(* blackbox *)
module giorgos_bias_gen (
    inout vdda1, 
    inout vssa1, 
    
    // Input/Output Control for Bias Gen
    output [9:0] dac_bias,
    input  [9:0] pad_bias_enable,
    input  [9:0] pad_bias_disable,
    
    // Inputs (Driven by Digital Top / Regfile)
    input [7:0] fine_code_0, fine_code_1, fine_code_2, fine_code_3, fine_code_4,
    input [7:0] fine_code_5, fine_code_6, fine_code_7, fine_code_8, fine_code_9,
    
    input [7:0] nfine_code_0, nfine_code_1, nfine_code_2, nfine_code_3, nfine_code_4,
    input [7:0] nfine_code_5, nfine_code_6, nfine_code_7, nfine_code_8, nfine_code_9,
    
    input [7:0] coarse_code_0, coarse_code_1, coarse_code_2, coarse_code_3, coarse_code_4,
    input [7:0] coarse_code_5, coarse_code_6, coarse_code_7, coarse_code_8, coarse_code_9,
    
    input [9:0] LowBiasInterfaceEn,
    input [9:0] nLowBiasInterfaceEn,
    input [9:0] CoarseOneHotLowBiasEn,
    input [9:0] LowBiasBuffEn,
    input [9:0] nLowBiasBuffEn,
    input [9:0] nBiasEn,
    input [9:0] pBiasEn,
    input [9:0] BiasEnable,
    input [9:0] BiasDisable
);
endmodule : giorgos_bias_gen