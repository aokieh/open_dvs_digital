//---------------------------------------------------------------------------
// Module: final_top
// Description: 
//  Top-level digital wrapper. Integrates the RegFile, SPI Peripheral, 
//  and the Dual-Spine DVS Core (fifo_rows_cols_macro).
//---------------------------------------------------------------------------

module final_top3 (
    `ifdef USE_POWER_PINS
        inout vccd1, 
        inout vssd1, 
    `endif
    
    input  logic clk,     // sys_clk (50MHz)
    input  logic rst_n,

    // -----------------------------------------------------------
    // SPI Interface
    // -----------------------------------------------------------
    input  logic       CS_N,
    // input  logic       SCK, // Driven internally by clk
    input  logic [3:0] COPI,
    output logic [3:0] CIPO,
    
    // -----------------------------------------------------------
    // Analog / Peripheral Configurations
    // -----------------------------------------------------------
    // output logic [`DAC_WIDTH-1:0] dac_config_0, dac_config_1, dac_config_2, dac_config_3,
    // output logic [`DAC_WIDTH-1:0] dac_config_4, dac_config_5, dac_config_6, dac_config_7,
    // output logic [`DAC_WIDTH-1:0] dac_config_8, dac_config_9,

    // Analog BGR Pads
    output logic [9:0]  pad_bias_enable,
    output logic [9:0]  pad_bias_disable,

    // Rui Analog Registers
    output logic [`FINE_CODE_WIDTH-1:0]   fine_code_0, fine_code_1, fine_code_2, fine_code_3, fine_code_4,
    output logic [`FINE_CODE_WIDTH-1:0]   fine_code_5, fine_code_6, fine_code_7, fine_code_8, fine_code_9, fine_code_10,

    output logic [`nFINE_CODE_WIDTH-1:0]  nfine_code_0, nfine_code_1, nfine_code_2, nfine_code_3, nfine_code_4,
    output logic [`nFINE_CODE_WIDTH-1:0]  nfine_code_5, nfine_code_6, nfine_code_7, nfine_code_8, nfine_code_9, nfine_code_10,

    output logic [`COARSE_CODE_WIDTH-1:0] coarse_code_0, coarse_code_1, coarse_code_2, coarse_code_3, coarse_code_4,
    output logic [`COARSE_CODE_WIDTH-1:0] coarse_code_5, coarse_code_6, coarse_code_7, coarse_code_8, coarse_code_9, coarse_code_10,

    output logic [`BIAS_COMBINED_WIDTH-1:0] LowBiasInterfaceEn,
    output logic [`BIAS_COMBINED_WIDTH-1:0] nLowBiasInterfaceEn,
    output logic [`BIAS_COMBINED_WIDTH-1:0] CoarseOneHotLowBiasEn,
    output logic [`BIAS_COMBINED_WIDTH-1:0] NBiasEn,
    output logic [`BIAS_COMBINED_WIDTH-1:0] PBiasEn,
    output logic [`BIAS_COMBINED_WIDTH-1:0] BiasEnable,
    output logic [`BIAS_COMBINED_WIDTH-1:0] BiasDisabled,

    output logic [`BIAS_COMBINED_WIDTH-1:0] BIT0,
    output logic [`BIAS_COMBINED_WIDTH-1:0] PowerDown,
    output logic [`FINE_CODE_WIDTH-1:0]  FineCodeBuffer,
    output logic [`nFINE_CODE_WIDTH-1:0]  nFineCodeBuffer,
    output logic [`COARSE_CODE_WIDTH-1:0]  CoarseOneHotBuffer,

    output logic LowBiasInterfaceEnBuffer,
    output logic nLowBiasInterfaceEnBuffer,
    output logic CoarseOneHotLowBiasEnBuffer,

    // -----------------------------------------------------------
    // DVS Core: Analog Array Interfaces (128x128 Grid)
    // -----------------------------------------------------------
    // Top Tier (Quadrants 0 & 1)
    input  logic [63:0]  array_col_top_left,
    input  logic [63:0]  array_col_top_right,
    output logic [63:0]  col_event_rst_top_left,
    output logic [63:0]  col_event_rst_top_right,
    output logic [1:0]   detect_pulse_global_top,
    output logic [1:0]   pre_charge_global_top,
    output logic [63:0]  row_on_detect_top,
    output logic [63:0]  row_off_detect_top,

    // Bottom Tier (Quadrants 2 & 3)
    input  logic [63:0]  array_col_bot_left,
    input  logic [63:0]  array_col_bot_right,
    output logic [63:0]  col_event_rst_bot_left,
    output logic [63:0]  col_event_rst_bot_right,
    output logic [1:0]   detect_pulse_global_bot,
    output logic [1:0]   pre_charge_global_bot,
    output logic [63:0]  row_on_detect_bot,
    output logic [63:0]  row_off_detect_bot,

    // Added for SPI Continuous Read Mode
    output logic data_ready_top,

    // TODO: Route these from regfile in the future
    input  logic         sm_enable,            // Comes from io_pad
    input  logic         pix_rst_global_in     // Comes from io_pad
);

    // ---------------------------------------------------
    // Internal Crossbar Routing
    // ---------------------------------------------------
    // SPI <-> RegFile
    logic                  we_reg;
    logic [`RF_AWIDTH-1:0] addr_reg;
    logic [ `RF_WIDTH-1:0] wdata_reg;
    logic [  `RF_MASK-1:0] wmask_reg;
    logic [ `RF_WIDTH-1:0] rdata_reg;
    
    // Internal Debug Wires (Read-only via Testbench)
    logic                  we_out;
    logic [7:0]            opcode_0_reg;
    logic [7:0]            addr_0_reg;
    logic [`RF_WIDTH-1:0]  spi_last_read_data_reg;

    // RegFile <-> Core (Resets and Metadata)
    logic                  fifo_rst_n_reg;
    logic                  fsm_rst_n_reg;
    logic [7:0]            event_rate_reg;
    logic [13:0]           p_pre_charge;
    logic [13:0]           p_buffer;
    logic [13:0]           p_detect;
    logic [13:0]           p_on_detect;
    logic [13:0]           p_off_detect;
    logic [13:0]           p_rst;

    // SPI <-> Core (FIFO Readout)
    logic [15:0] rdata_spi_0; // Top Tier
    logic [15:0] rdata_spi_1; // Bottom Tier
    logic [1:0]  shift_en_fifo;

    // Core FIFO Status Flags
    logic empty_fifo_top, full_fifo_top;
    logic empty_fifo_bot, full_fifo_bot;
    logic data_ready_fifo;

    logic [`FIFO_AWIDTH-1:0] numel_fifo_top;
    logic [`FIFO_AWIDTH-1:0] numel_fifo_bot;
    logic [7:0] fifo_debug_top_wire;
    logic [7:0] fifo_debug_bot_wire;
    logic [7:0] fsm_ctrl_byte_top_wire;
    logic [7:0] fsm_ctrl_byte_bot_wire;


    // assign fifo_numel_combined = numel_fifo_top | numel_fifo_bot;
    assign fifo_debug_top_wire = {2'b00, empty_fifo_top, full_fifo_top, numel_fifo_top};
    assign fifo_debug_bot_wire = {2'b00, empty_fifo_bot, full_fifo_bot, numel_fifo_bot};
    
    // Aggregate the data ready mode (EXACT same gate delays)
    assign data_ready_fifo = ~empty_fifo_top & ~empty_fifo_bot;
    assign data_ready_top  = ~empty_fifo_top & ~empty_fifo_bot;


    // ---------------------------------------------------
    // 1. SPI Peripheral
    // ---------------------------------------------------
    spi_peripheral_re i_spi_peripheral (
        `ifdef USE_POWER_PINS
            .vccd1 (vccd1), .vssd1 (vssd1),
        `endif
        .CS_N(CS_N), 
        .SCK(clk), 
        .COPI(COPI), 
        .CIPO(CIPO),
        
        // Mem I/O
        .addr_reg, 
        .we_reg, 
        .we_out, 
        .wdata_reg, 
        .wmask_reg, 
        .rdata_reg,

        // Debug I/O
        .opcode_0_reg(opcode_0_reg),
        .addr_0_reg(addr_0_reg),
        .spi_last_read_data_reg(spi_last_read_data_reg),

        // FIFO I/O
        .rdata_spi_0   (rdata_spi_0),
        .rdata_spi_1   (rdata_spi_1),
        .shift_en_fifo (shift_en_fifo),
        .data_ready_spi(data_ready_fifo)
    );

    // ---------------------------------------------------
    // 2. Register File
    // ---------------------------------------------------
    regfile i_regfile(
        `ifdef USE_POWER_PINS
            .vccd1 (vccd1), .vssd1 (vssd1),
        `endif
        .clk(clk),
        .rst_n(rst_n),

        // Memory Interface (SPI <-> Mem)
        .addr_reg, .we_reg, .wdata_reg, .wmask_reg, .rdata_reg,

        // SPI Debug Wires
        .opcode_0_reg(opcode_0_reg),
        .addr_0_reg(addr_0_reg),
        .spi_last_read_data_reg(spi_last_read_data_reg),

        // FIFO & FSM Resets
        .fifo_rst_n_reg(fifo_rst_n_reg),
        .fsm_rst_n_reg(fsm_rst_n_reg),
        .fifo_debug_top(fifo_debug_top_wire),       
        .fifo_debug_bot(fifo_debug_bot_wire),       

        // Analog BGR Pads
        .pad_bias_enable(pad_bias_enable),
        .pad_bias_disable(pad_bias_disable),

        // DAC
        // .dac_config_0, .dac_config_1, .dac_config_2, .dac_config_3, .dac_config_4, 
        // .dac_config_5, .dac_config_6, .dac_config_7, .dac_config_8, .dac_config_9,             

        // FSM
        .fsm_ctrl_byte_top(fsm_ctrl_byte_top_wire),    
        .fsm_ctrl_byte_bot(fsm_ctrl_byte_bot_wire),    

        // Programmable Imager Speed & Timing (14-BIT)
        .event_rate_reg(event_rate_reg),
        .p_pre_charge(p_pre_charge),           
        .p_buffer(p_buffer),
        .p_detect(p_detect),
        .p_on_detect(p_on_detect),
        .p_off_detect(p_off_detect),
        .p_rst(p_rst),

        // Rui Analog Registers
        .fine_code_0, .fine_code_1, .fine_code_2, .fine_code_3, .fine_code_4,
        .fine_code_5, .fine_code_6, .fine_code_7, .fine_code_8, .fine_code_9, .fine_code_10,

        .nfine_code_0, .nfine_code_1, .nfine_code_2, .nfine_code_3, .nfine_code_4,
        .nfine_code_5, .nfine_code_6, .nfine_code_7, .nfine_code_8, .nfine_code_9, .nfine_code_10,

        .coarse_code_0, .coarse_code_1, .coarse_code_2, .coarse_code_3, .coarse_code_4,
        .coarse_code_5, .coarse_code_6, .coarse_code_7, .coarse_code_8, .coarse_code_9, .coarse_code_10,

        .LowBiasInterfaceEn, .nLowBiasInterfaceEn, .CoarseOneHotLowBiasEn,
        .NBiasEn, .PBiasEn, .BiasEnable, .BiasDisabled,

        .BIT0, .PowerDown, .FineCodeBuffer, .nFineCodeBuffer, .CoarseOneHotBuffer,
        .LowBiasInterfaceEnBuffer, .nLowBiasInterfaceEnBuffer, .CoarseOneHotLowBiasEnBuffer
    );

    // ---------------------------------------------------
    // 3. Dual-Spine DVS Core
    // ---------------------------------------------------
    fifo_rows_cols_macro2 i_dvs_core (
        `ifdef USE_POWER_PINS
            .vccd1 (vccd1), .vssd1 (vssd1),
        `endif
        
        .sys_clk      (clk),
        .rst_n        (rst_n),
        
        // Connect Resets internally from Regfile
        .fifo_rst_n   (fifo_rst_n_reg),
        .fsm_rst_n    (fsm_rst_n_reg),
        
        .sm_enable    (sm_enable),
        .program_bits (event_rate_reg),
        .p_pre_charge (p_pre_charge),
        .p_buffer     (p_buffer),
        .p_detect     (p_detect),
        .p_on_detect  (p_on_detect),
        .p_off_detect (p_off_detect),
        .p_rst        (p_rst),

        // Top Tier Analog
        .array_col_top_left      (array_col_top_left),
        .array_col_top_right     (array_col_top_right),
        .col_event_rst_top_left  (col_event_rst_top_left),
        .col_event_rst_top_right (col_event_rst_top_right),
        .detect_pulse_global_top (detect_pulse_global_top),
        .pre_charge_global_top   (pre_charge_global_top),
        .row_on_detect_top       (row_on_detect_top),
        .row_off_detect_top      (row_off_detect_top),

        // Bottom Tier Analog
        .array_col_bot_left      (array_col_bot_left),
        .array_col_bot_right     (array_col_bot_right),
        .col_event_rst_bot_left  (col_event_rst_bot_left),
        .col_event_rst_bot_right (col_event_rst_bot_right),
        .detect_pulse_global_bot (detect_pulse_global_bot),
        .pre_charge_global_bot   (pre_charge_global_bot),
        .row_on_detect_bot       (row_on_detect_bot),
        .row_off_detect_bot      (row_off_detect_bot),

        // Q-SPI Readout Interconnects
        .shift_en_top   (shift_en_fifo[0]),
        .rdata_spi_top  (rdata_spi_0),
        .empty_fifo_top (empty_fifo_top),
        .full_fifo_top  (full_fifo_top),
        .numel_fifo_top (numel_fifo_top),

        .shift_en_bot   (shift_en_fifo[1]),
        .rdata_spi_bot  (rdata_spi_1),
        .empty_fifo_bot (empty_fifo_bot),
        .full_fifo_bot  (full_fifo_bot),
        .numel_fifo_bot (numel_fifo_bot),

        // FSM Debug Outputs
        .fsm_ctrl_byte_top (fsm_ctrl_byte_top_wire),
        .fsm_ctrl_byte_bot (fsm_ctrl_byte_bot_wire)
    );

endmodule : final_top3