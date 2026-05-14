/* verilator lint_off UNUSEDSIGNAL */
/* verilator lint_off UNUSEDPARAM */
`default_nettype none

//---------------------------------------------------------------------------
// Module: open_dvs_top
// Description: 
//  Intermediate Mixed-Signal Wrapper. 
//  Seals the Digital Top, Bias Generator, and Analog Imager into one block.
//  Only exposes Caravel-facing IOs, isolating all internal data/analog buses.
//---------------------------------------------------------------------------

module open_dvs_top (
    `ifdef USE_POWER_PINS
        inout vdda1,    // Analog 3.3V supply
        inout vssa1,    // Analog ground
        inout vccd1,    // Digital 1.8V supply
        inout vssd1,    // Digital ground
    `endif

    // System Control
    input  logic       clk,
    input  logic       rst_n,
    input  logic       sm_enable,         // From Caravel IO pad
    input  logic       pix_rst_global_in, // From Caravel IO pad

    // SPI Interface
    input  logic       CS_N,
    input  logic [3:0] COPI,
    output logic [3:0] CIPO,

    // Status Flags
    output logic       data_ready_top,
    
    // NOTE: If the external analog override voltage for the BGR comes from 
    // an external pin, it would be added here as an `inout` port and routed 
    // down to the bias_gen block in the future.

    inout logic [9:0] pad_bias
);

    // =======================================================
    // 1. INTERNAL INTERCONNECTS (The "Sealed" Crossbar)
    // =======================================================

    // A. Imager Data <-> Digital Top
    wire [63:0] array_col_top_left, array_col_top_right, array_col_bot_left, array_col_bot_right;
    wire [63:0] col_event_rst_top_left, col_event_rst_top_right, col_event_rst_bot_left, col_event_rst_bot_right;
    wire [63:0] row_on_detect_top, row_off_detect_top, row_on_detect_bot, row_off_detect_bot;
    wire [1:0]  detect_pulse_global_top, pre_charge_global_top, detect_pulse_global_bot, pre_charge_global_bot;
    wire        ndetect_pulse_global_top_left, ndetect_pulse_global_bot_left;
    wire        pre_charge_global_top_left, pre_charge_global_bot_left;

    // B. Digital Top <-> Bias Generator (Configurations)
    wire [9:0]  pad_bias_enable;
    wire [9:0]  pad_bias_disable;

    wire [`FINE_CODE_WIDTH-1:0]   fine_code_0, fine_code_1, fine_code_2, fine_code_3, fine_code_4;
    wire [`FINE_CODE_WIDTH-1:0]   fine_code_5, fine_code_6, fine_code_7, fine_code_8, fine_code_9;
    
    wire [`nFINE_CODE_WIDTH-1:0]  nfine_code_0, nfine_code_1, nfine_code_2, nfine_code_3, nfine_code_4;
    wire [`nFINE_CODE_WIDTH-1:0]  nfine_code_5, nfine_code_6, nfine_code_7, nfine_code_8, nfine_code_9;
    
    wire [`COARSE_CODE_WIDTH-1:0] coarse_code_0, coarse_code_1, coarse_code_2, coarse_code_3, coarse_code_4;
    wire [`COARSE_CODE_WIDTH-1:0] coarse_code_5, coarse_code_6, coarse_code_7, coarse_code_8, coarse_code_9;

    wire [`BIAS_COMBINED_WIDTH-1:0] LowBiasInterfaceEn, nLowBiasInterfaceEn, CoarseOneHotLowBiasEn;
    wire [`BIAS_COMBINED_WIDTH-1:0] LowBiasBuffEn, nLowBiasBuffEn, nBiasEn, pBiasEn;
    wire [`BIAS_COMBINED_WIDTH-1:0] BiasEnable, BiasDisable;

    // C. Bias Generator <-> Analog Imager (Pure Analog DC Lines)
    wire [9:0] dac_bias;

    assign detect_pulse_global_top_left  =  detect_pulse_global_top[0];
    assign ndetect_pulse_global_top_left = ~detect_pulse_global_top[0];

    assign detect_pulse_global_bot_left  =  detect_pulse_global_bot[0];
    assign ndetect_pulse_global_bot_left = ~detect_pulse_global_bot[0];

    assign pre_charge_global_top_left    = pre_charge_global_top[0];
    assign pre_charge_global_bot_left    = pre_charge_global_bot[0];
    
    // =======================================================
    // 2. MACRO INSTANTIATIONS
    // =======================================================

    // -------------------------------------------------------
    // A. The Digital Brain (Contains RegFile + SPI + FSM)
    // -------------------------------------------------------
    final_top3 i_digital_top (
        `ifdef USE_POWER_PINS
            .vccd1(vccd1),
            .vssd1(vssd1),
        `endif
        
        .clk(clk),
        .rst_n(rst_n),
        .sm_enable(sm_enable),
        .pix_rst_global_in(pix_rst_global_in),
        
        .CS_N(CS_N),
        .COPI(COPI),
        .CIPO(CIPO),
        .data_ready_top(data_ready_top),

        // Array Control & Data
        .array_col_top_left(array_col_top_left),           .array_col_top_right(array_col_top_right),
        .col_event_rst_top_left(col_event_rst_top_left),   .col_event_rst_top_right(col_event_rst_top_right),
        .array_col_bot_left(array_col_bot_left),           .array_col_bot_right(array_col_bot_right),
        .col_event_rst_bot_left(col_event_rst_bot_left),   .col_event_rst_bot_right(col_event_rst_bot_right),
        
        .row_on_detect_top(row_on_detect_top),             .row_off_detect_top(row_off_detect_top),
        .row_on_detect_bot(row_on_detect_bot),             .row_off_detect_bot(row_off_detect_bot),
        .pre_charge_global_top(pre_charge_global_top),     .detect_pulse_global_top(detect_pulse_global_top),
        .pre_charge_global_bot(pre_charge_global_bot),     .detect_pulse_global_bot(detect_pulse_global_bot),

        // Bias Config Outputs -> Routed to Bias Gen
        .pad_bias_enable(pad_bias_enable),
        .pad_bias_disable(pad_bias_disable),
        
        .fine_code_0(fine_code_0), .fine_code_1(fine_code_1), .fine_code_2(fine_code_2), .fine_code_3(fine_code_3), .fine_code_4(fine_code_4),
        .fine_code_5(fine_code_5), .fine_code_6(fine_code_6), .fine_code_7(fine_code_7), .fine_code_8(fine_code_8), .fine_code_9(fine_code_9),
        
        .nfine_code_0(nfine_code_0), .nfine_code_1(nfine_code_1), .nfine_code_2(nfine_code_2), .nfine_code_3(nfine_code_3), .nfine_code_4(nfine_code_4),
        .nfine_code_5(nfine_code_5), .nfine_code_6(nfine_code_6), .nfine_code_7(nfine_code_7), .nfine_code_8(nfine_code_8), .nfine_code_9(nfine_code_9),
        
        .coarse_code_0(coarse_code_0), .coarse_code_1(coarse_code_1), .coarse_code_2(coarse_code_2), .coarse_code_3(coarse_code_3), .coarse_code_4(coarse_code_4),
        .coarse_code_5(coarse_code_5), .coarse_code_6(coarse_code_6), .coarse_code_7(coarse_code_7), .coarse_code_8(coarse_code_8), .coarse_code_9(coarse_code_9),
        
        .LowBiasInterfaceEn(LowBiasInterfaceEn), .nLowBiasInterfaceEn(nLowBiasInterfaceEn), .CoarseOneHotLowBiasEn(CoarseOneHotLowBiasEn),
        .LowBiasBuffEn(LowBiasBuffEn), .nLowBiasBuffEn(nLowBiasBuffEn), .nBiasEn(nBiasEn), .pBiasEn(pBiasEn),
        .BiasEnable(BiasEnable), .BiasDisable(BiasDisable)
    );

    // -------------------------------------------------------
    // B. The Bias Generator (Digital In -> Analog Out)
    // -------------------------------------------------------
    giorgos_bias_gen i_bias_gen (
        `ifdef USE_POWER_PINS
            .vdda1(vdda1),
            .vssa1(vssa1),
        `endif
        
        // Digital Configuration Inputs (From final_top3)
        .pad_bias_enable(pad_bias_enable),
        .pad_bias_disable(pad_bias_disable),
        
        .fine_code_0(fine_code_0), .fine_code_1(fine_code_1), .fine_code_2(fine_code_2), .fine_code_3(fine_code_3), .fine_code_4(fine_code_4),
        .fine_code_5(fine_code_5), .fine_code_6(fine_code_6), .fine_code_7(fine_code_7), .fine_code_8(fine_code_8), .fine_code_9(fine_code_9),
        
        .nfine_code_0(nfine_code_0), .nfine_code_1(nfine_code_1), .nfine_code_2(nfine_code_2), .nfine_code_3(nfine_code_3), .nfine_code_4(nfine_code_4),
        .nfine_code_5(nfine_code_5), .nfine_code_6(nfine_code_6), .nfine_code_7(nfine_code_7), .nfine_code_8(nfine_code_8), .nfine_code_9(nfine_code_9),
        
        .coarse_code_0(coarse_code_0), .coarse_code_1(coarse_code_1), .coarse_code_2(coarse_code_2), .coarse_code_3(coarse_code_3), .coarse_code_4(coarse_code_4),
        .coarse_code_5(coarse_code_5), .coarse_code_6(coarse_code_6), .coarse_code_7(coarse_code_7), .coarse_code_8(coarse_code_8), .coarse_code_9(coarse_code_9),
        
        .LowBiasInterfaceEn(LowBiasInterfaceEn), .nLowBiasInterfaceEn(nLowBiasInterfaceEn), .CoarseOneHotLowBiasEn(CoarseOneHotLowBiasEn),
        .LowBiasBuffEn(LowBiasBuffEn), .nLowBiasBuffEn(nLowBiasBuffEn), .nBiasEn(nBiasEn), .pBiasEn(pBiasEn),
        .BiasEnable(BiasEnable), .BiasDisable(BiasDisable),

        // Pure Analog Output -> Routed to Imager
        .dac_bias(dac_bias)
    );

    // -------------------------------------------------------
    // C. The Physical Array
    // -------------------------------------------------------
    (* keep *)
    Imager_Top_no_m5 analog_imager_inst (
        `ifdef USE_POWER_PINS
            .vdda1(vdda1),
            .vssa1(vssa1),
        `endif
        
        // North/South Columns
        .array_col_top_left(array_col_top_left),           .array_col_top_right(array_col_top_right),
        .col_event_rst_top_left(col_event_rst_top_left),   .col_event_rst_top_right(col_event_rst_top_right),
        .array_col_bot_left(array_col_bot_left),           .array_col_bot_right(array_col_bot_right),
        .col_event_rst_bot_left(col_event_rst_bot_left),   .col_event_rst_bot_right(col_event_rst_bot_right),
        
        // West Rows
        .row_on_detect_top(row_on_detect_top),             .row_off_detect_top(row_off_detect_top),
        .row_on_detect_bot(row_on_detect_bot),             .row_off_detect_bot(row_off_detect_bot),
        
        // Split Global Arrays [0]=Left, [1]=Right
        .pre_charge_global_top_left(pre_charge_global_top[0]),     .pre_charge_global_top_right(pre_charge_global_top[1]),
        .detect_pulse_global_top_left(detect_pulse_global_top[0]), .detect_pulse_global_top_right(detect_pulse_global_top[1]),
        .pre_charge_global_bot_left(pre_charge_global_bot[0]),     .pre_charge_global_bot_right(pre_charge_global_bot[1]),
        .detect_pulse_global_bot_left(detect_pulse_global_bot[0]), .detect_pulse_global_bot_right(detect_pulse_global_bot[1]),
        
        // Analog Power Bias (From Bias Gen)
        .dac_bias(dac_bias),

        // Synchronized reset (Passed directly from Wrapper Port into all 4 quadrants)
        .pix_rst_global_top_left  (pix_rst_global_in),
        .pix_rst_global_bot_left  (pix_rst_global_in),
        .pix_rst_global_top_right (pix_rst_global_in),
        .pix_rst_global_bot_right (pix_rst_global_in)
    );

endmodule : open_dvs_top