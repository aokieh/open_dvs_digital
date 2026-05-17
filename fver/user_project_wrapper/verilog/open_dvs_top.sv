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

    inout logic [9:0] pad_bias,
    inout logic       rx
);

    // =======================================================
    // 1. INTERNAL INTERCONNECTS (The "Sealed" Crossbar)
    // =======================================================

    // A. Imager Data <-> Digital Top
    wire [63:0] array_col_top_left, array_col_top_right, array_col_bot_left, array_col_bot_right;
    wire [63:0] col_event_rst_top_left, col_event_rst_top_right, col_event_rst_bot_left, col_event_rst_bot_right;
    wire [63:0] row_on_detect_top, row_off_detect_top, row_on_detect_bot, row_off_detect_bot;
    wire [1:0]  detect_pulse_global_top, pre_charge_global_top, detect_pulse_global_bot, pre_charge_global_bot;
    wire        detect_pulse_global_top_left, detect_pulse_global_bot_left;
    wire        ndetect_pulse_global_top_left, ndetect_pulse_global_bot_left;
    wire        pre_charge_global_top_left, pre_charge_global_bot_left;

    // B. Digital Top <-> Bias Generator (Configurations)
    wire [9:0]  pad_bias_enable;
    wire [9:0]  pad_bias_disable;

    wire [`FINE_CODE_WIDTH-1:0]   fine_code_0, fine_code_1, fine_code_2, fine_code_3, fine_code_4;
    wire [`FINE_CODE_WIDTH-1:0]   fine_code_5, fine_code_6, fine_code_7, fine_code_8, fine_code_9, fine_code_10;

    wire [`nFINE_CODE_WIDTH-1:0]  nfine_code_0, nfine_code_1, nfine_code_2, nfine_code_3, nfine_code_4;
    wire [`nFINE_CODE_WIDTH-1:0]  nfine_code_5, nfine_code_6, nfine_code_7, nfine_code_8, nfine_code_9, nfine_code_10;

    wire [`COARSE_CODE_WIDTH-1:0] coarse_code_0, coarse_code_1, coarse_code_2, coarse_code_3, coarse_code_4;
    wire [`COARSE_CODE_WIDTH-1:0] coarse_code_5, coarse_code_6, coarse_code_7, coarse_code_8, coarse_code_9, coarse_code_10;

    wire [`BIAS_COMBINED_WIDTH-1:0] LowBiasInterfaceEn, nLowBiasInterfaceEn, CoarseOneHotLowBiasEn;
    wire [`BIAS_COMBINED_WIDTH-1:0] NBiasEn, PBiasEn, BiasEnable, BiasDisabled;
    wire [`BIAS_COMBINED_WIDTH-1:0] BIT0, PowerDown;
    
    wire [`FINE_CODE_WIDTH-1:0]  FineCodeBuffer;
    wire [`nFINE_CODE_WIDTH-1:0] nFineCodeBuffer;
    wire [`COARSE_CODE_WIDTH-1:0] CoarseOneHotBuffer;
    
    wire LowBiasInterfaceEnBuffer, nLowBiasInterfaceEnBuffer, CoarseOneHotLowBiasEnBuffer;

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
        .fine_code_5(fine_code_5), .fine_code_6(fine_code_6), .fine_code_7(fine_code_7), .fine_code_8(fine_code_8), .fine_code_9(fine_code_9), .fine_code_10(fine_code_10),
        
        .nfine_code_0(nfine_code_0), .nfine_code_1(nfine_code_1), .nfine_code_2(nfine_code_2), .nfine_code_3(nfine_code_3), .nfine_code_4(nfine_code_4),
        .nfine_code_5(nfine_code_5), .nfine_code_6(nfine_code_6), .nfine_code_7(nfine_code_7), .nfine_code_8(nfine_code_8), .nfine_code_9(nfine_code_9), .nfine_code_10(nfine_code_10),
        
        .coarse_code_0(coarse_code_0), .coarse_code_1(coarse_code_1), .coarse_code_2(coarse_code_2), .coarse_code_3(coarse_code_3), .coarse_code_4(coarse_code_4),
        .coarse_code_5(coarse_code_5), .coarse_code_6(coarse_code_6), .coarse_code_7(coarse_code_7), .coarse_code_8(coarse_code_8), .coarse_code_9(coarse_code_9), .coarse_code_10(coarse_code_10),
        
        .LowBiasInterfaceEn(LowBiasInterfaceEn), .nLowBiasInterfaceEn(nLowBiasInterfaceEn), .CoarseOneHotLowBiasEn(CoarseOneHotLowBiasEn),
        .NBiasEn(NBiasEn), .PBiasEn(PBiasEn), .BiasEnable(BiasEnable), .BiasDisabled(BiasDisabled),
        
        .BIT0(BIT0), .PowerDown(PowerDown),
        .FineCodeBuffer(FineCodeBuffer), .nFineCodeBuffer(nFineCodeBuffer), .CoarseOneHotBuffer(CoarseOneHotBuffer),
        .LowBiasInterfaceEnBuffer(LowBiasInterfaceEnBuffer), .nLowBiasInterfaceEnBuffer(nLowBiasInterfaceEnBuffer), .CoarseOneHotLowBiasEnBuffer(CoarseOneHotLowBiasEnBuffer)
    );

    // -------------------------------------------------------
    // B. The Bias Generator (Digital In -> Analog Out)
    // -------------------------------------------------------
    BiasBranchnMasterx11 i_bias_gen (
        `ifdef USE_POWER_PINS
            .VddA18(vdda1), 
            .GndA(vssa1),   
        `endif
        
        // Analog Shared Interconnects
        .rx(rx),           // <--- We will add this to the top level next!
        .VMasterBiasP(), 
        .VMasterBiasN(),   
        .Bias_fake(),
        .BufferP(),
        .BufferN(),

        // Pure Analog Output -> Routed to Imager
        .Bias(dac_bias),   

        // 11-bit Control Inputs (1:1 mapping from Regfile)
        .BiasDisabled(BiasDisabled),
        .PowerDown(PowerDown),
        .PBiasEn(PBiasEn),
        .NBiasEn(NBiasEn),
        .LowBiasInterfaceEn(LowBiasInterfaceEn),
        .nLowBiasInterfaceEn(nLowBiasInterfaceEn),
        .CoarseOneHotLowBiasEn(CoarseOneHotLowBiasEn),
        .BIT0(BIT0),
        
        // 88-bit Code Inputs (Concatenate 10 down to 0)
        .FineCode({
            fine_code_10, fine_code_9, fine_code_8, fine_code_7, fine_code_6, 
            fine_code_5, fine_code_4, fine_code_3, fine_code_2, fine_code_1, fine_code_0
        }),
        
        .nFineCode({
            nfine_code_10, nfine_code_9, nfine_code_8, nfine_code_7, nfine_code_6, 
            nfine_code_5, nfine_code_4, nfine_code_3, nfine_code_2, nfine_code_1, nfine_code_0
        }),
        
        .CoarseOneHot({
            coarse_code_10, coarse_code_9, coarse_code_8, coarse_code_7, coarse_code_6, 
            coarse_code_5, coarse_code_4, coarse_code_3, coarse_code_2, coarse_code_1, coarse_code_0
        }),

        // 8-bit Buffer Inputs
        .FineCodeBuffer(FineCodeBuffer),
        .nFineCodeBuffer(nFineCodeBuffer),
        .CoarseOneHotBuffer(CoarseOneHotBuffer),
        
        // 1-bit Buffer Enables
        .LowBiasInterfaceEnBuffer(LowBiasInterfaceEnBuffer),
        .nLowBiasInterfaceEnBuffer(nLowBiasInterfaceEnBuffer),
        .CoarseOneHotLowBiasEnBuffer(CoarseOneHotLowBiasEnBuffer)
    );

    // -------------------------------------------------------
    // C. The Physical Array
    // -------------------------------------------------------
    (* keep *)
    pixel_4tile analog_imager_inst (
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
        
        // Split Global Arrays (Left side only)
        .pre_charge_global_top_left(pre_charge_global_top[0]),
        .detect_pulse_global_top_left(detect_pulse_global_top[0]),
        .ndetect_pulse_global_top_left(ndetect_pulse_global_top_left),
        .pre_charge_global_bot_left(pre_charge_global_bot[0]),
        .detect_pulse_global_bot_left(detect_pulse_global_bot[0]),
        .ndetect_pulse_global_bot_left(ndetect_pulse_global_bot_left),
        
        // Analog Power Bias (Tailored EXACTLY to the 5 pins in the LEF)
        .dac_config_0(dac_bias[0]),
        .dac_config_1(dac_bias[1]),
        .dac_config_2(dac_bias[2]),
        .dac_config_3(dac_bias[3]),
        .dac_config_4(dac_bias[4]),
        .dac_config_5(dac_bias[5]),
        .dac_config_6(dac_bias[6]),

        // Synchronized reset
        .pix_rst_global_top_left  (pix_rst_global_in),
        .pix_rst_global_bot_left  (pix_rst_global_in),
        .pix_rst_global_top_right (pix_rst_global_in),
        .pix_rst_global_bot_right (pix_rst_global_in)
    );

endmodule : open_dvs_top