/* verilator lint_off UNUSEDSIGNAL */
/* verilator lint_off UNDRIVEN */

// blackboxes.sv - ONLY for macros NOT fully defined in config.json

// blackboxes.sv
// Imager Blackbox (Mapped strictly to physical LEF)
(* blackbox *)
module pixel_4tile (
`ifdef USE_POWER_PINS
    inout vdda1, 
    inout vssa1, 
`endif
    
    // Outputs (Driven by Imager to Digital)
    output [63:0] array_col_top_left, array_col_top_right,
    output [63:0] array_col_bot_left, array_col_bot_right,
    
    // Inputs (Driven by Digital to Imager)
    input [63:0] col_event_rst_top_left, col_event_rst_top_right,
    input [63:0] col_event_rst_bot_left, col_event_rst_bot_right,
    
    input [63:0] row_on_detect_top, row_off_detect_top,
    input [63:0] row_on_detect_bot, row_off_detect_bot,
    
    // Globals - ONLY LEFT SIDE PRESENT IN LEF
    input pre_charge_global_top_left,
    input detect_pulse_global_top_left,
    input ndetect_pulse_global_top_left,
    input pre_charge_global_bot_left,
    input detect_pulse_global_bot_left,
    input ndetect_pulse_global_bot_left,
    
    // Analog Bias Inputs (ONLY the 5 pins present in LEF)
    input dac_config_0,
    input dac_config_1,
    input dac_config_2,
    input dac_config_3,
    input dac_config_4,
    input dac_config_5,
    input dac_config_6,

    // Resets
    input pix_rst_global_top_left,
    input pix_rst_global_bot_left,
    input pix_rst_global_top_right,
    input pix_rst_global_bot_right
);
endmodule : pixel_4tile

// giorgos_bias_gen blackbox
// Bias Gen Blackbox (Mapped strictly to physical LEF)
(* blackbox *)
module BiasBranchnMasterx11 (
`ifdef USE_POWER_PINS
    inout VddA18, 
    inout GndA, 
`endif
    
    // Analog / Shared Interconnects
    inout VMasterBiasP,
    inout VMasterBiasN,
    inout rx,
    inout Bias_fake,
    inout BufferP,
    inout BufferN,

    // Output Bias
    output [10:0] Bias,
    
    // 11-bit Control Inputs
    input [10:0] BiasDisabled,
    input [10:0] PowerDown,
    input [10:0] PBiasEn,
    input [10:0] NBiasEn,
    input [10:0] LowBiasInterfaceEn,
    input [10:0] nLowBiasInterfaceEn,
    input [10:0] CoarseOneHotLowBiasEn,
    input [10:0] BIT0,
    
    // 88-bit Code Inputs (Matches LEF [87:0])
    input [87:0] CoarseOneHot,
    input [87:0] FineCode,
    input [87:0] nFineCode,
    
    // 8-bit Buffer Inputs
    input [7:0] FineCodeBuffer,
    input [7:0] nFineCodeBuffer,
    input [7:0] CoarseOneHotBuffer,
    
    // 1-bit Buffer Enables
    input LowBiasInterfaceEnBuffer,
    input nLowBiasInterfaceEnBuffer,
    input CoarseOneHotLowBiasEnBuffer
);
endmodule : BiasBranchnMasterx11