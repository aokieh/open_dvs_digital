//---------------------------------------------------------------------------
// Module: final_top
// Description: 
//  Top-level digital wrapper. Integrates the RegFile, SPI Peripheral, 
//  and the Dual-Spine DVS Core (fifo_rows_cols_macro).
//---------------------------------------------------------------------------

module final_top (
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
    // input  logic       SCK,
    input  logic [3:0] COPI,
    output logic [3:0] CIPO,
    
    // -----------------------------------------------------------
    // Analog / Peripheral Configurations
    // -----------------------------------------------------------
    // output logic [23:0] bias_0, bias_1, bias_2, bias_3,
    output logic [`DAC_WIDTH-1:0] dac_config_0, dac_config_1, dac_config_2, dac_config_3,
    output logic [`DAC_WIDTH-1:0] dac_config_4, dac_config_5, dac_config_6, dac_config_7,
    output logic [`DAC_WIDTH-1:0] dac_config_8, dac_config_9,
    // -----------------------------------------------------------
    // DVS Core: Analog Array Interfaces (128x128 Grid)
    // -----------------------------------------------------------
    // Top Tier (Quadrants 0 & 1)
    input  logic [63:0]  array_col_top_left,
    input  logic [63:0]  array_col_top_right,
    output logic [63:0]  col_event_rst_top_left,
    output logic [63:0]  col_event_rst_top_right,
    output logic [1:0]   pre_charge_global_top,
    output logic [63:0]  row_on_detect_top,
    output logic [63:0]  row_off_detect_top,

    // Bottom Tier (Quadrants 2 & 3)
    input  logic [63:0]  array_col_bot_left,
    input  logic [63:0]  array_col_bot_right,
    output logic [63:0]  col_event_rst_bot_left,
    output logic [63:0]  col_event_rst_bot_right,
    output logic [1:0]   pre_charge_global_bot,
    output logic [63:0]  row_on_detect_bot,
    output logic [63:0]  row_off_detect_bot,

    // Added for SPI Continuous Read Mode
    output logic data_ready_top,

    // TODO: Route these from regfile in the future
    input  logic         sm_enable         // Comes from io_pad
    // input  logic [7:0]   program_bits       // set with register
);

    // ---------------------------------------------------
    // Internal Crossbar Routing
    // ---------------------------------------------------
    // SPI <-> RegFile
    logic                  we_reg;
    logic                  we_out;
    logic [`RF_AWIDTH-1:0] addr_reg;
    logic [ `RF_WIDTH-1:0] wdata_reg;
    logic [  `RF_MASK-1:0] wmask_reg;
    logic [ `RF_WIDTH-1:0] rdata_reg;

    // RegFile <-> Core (IRQs and Metadata)
    logic [`FIFO_AWIDTH-1:0] irq_deassert_thresh_reg;
    logic [`FIFO_AWIDTH-1:0] irq_assert_thresh_reg;
    logic                    fifo_rd_en_reg;
    logic                    fifo_rst_n_reg;
    logic [7:0]              event_rate_reg;

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

    // Aggregate numel for the RegFile (or map them independently)
    logic [`FIFO_AWIDTH-1:0] fifo_numel_combined;
    assign fifo_numel_combined = numel_fifo_top | numel_fifo_bot; 
    // Aggregate the data ready mode (EXACT same gate delays)
    assign data_ready_fifo = ~empty_fifo_top & ~empty_fifo_bot;
    assign data_ready_top  = ~empty_fifo_top & ~empty_fifo_bot;

    // assign event_rate = event_rate_reg;

    // ---------------------------------------------------
    // 1. SPI Peripheral
    // ---------------------------------------------------
    spi_peripheral i_spi_peripheral (
        `ifdef USE_POWER_PINS
            .vccd1 (vccd1), .vssd1 (vssd1),
        `endif
        .CS_N(CS_N), .SCK(clk), .COPI(COPI), .CIPO(CIPO),
        
        // Mem I/O
        .addr_reg, .we_reg, .we_out, .wdata_reg, .wmask_reg, .rdata_reg,
        
        // FIFO I/O
        .rdata_spi_0   (rdata_spi_0),
        .rdata_spi_1   (rdata_spi_1),
        .shift_en_fifo (shift_en_fifo),
        .data_ready_spi(data_ready_fifo) // TODO: added safety for scanning imager
    );

    // ---------------------------------------------------
    // 2. Register File
    // ---------------------------------------------------
    regfile i_regfile (
        `ifdef USE_POWER_PINS
            .vccd1 (vccd1), .vssd1 (vssd1),
        `endif
        .clk   (clk), 
        .rst_n (rst_n),

        // Mem I/O
        .addr_reg, .we_reg, .wdata_reg, .wmask_reg, .rdata_reg,

        // FIFO Controls
        .fifo_rst_n_reg (fifo_rst_n_reg),
        .fifo_rd_en_reg (fifo_rd_en_reg),
        .fifo_numel_reg (fifo_numel_combined),

        // IRQ
        .irq_deassert_thresh_reg (irq_deassert_thresh_reg),
        .irq_assert_thresh_reg   (irq_assert_thresh_reg),

        // Configuration
        .dac_config_0, .dac_config_1, .dac_config_2, .dac_config_3, .dac_config_4, 
        .dac_config_5, .dac_config_6, .dac_config_7, .dac_config_8, .dac_config_9,
        // .bias_0, .bias_1, .bias_2, .bias_3,
        .event_rate_reg
    );

    // assign event_rate = event_rate_reg;
    // ---------------------------------------------------
    // 3. Dual-Spine DVS Core
    // ---------------------------------------------------
    fifo_rows_cols_macro i_dvs_core (
        `ifdef USE_POWER_PINS
            .vccd1 (vccd1), .vssd1 (vssd1),
        `endif
        
        .sys_clk      (clk),
        .rst_n        (rst_n),
        .sm_enable    (sm_enable),
        .program_bits (event_rate_reg),

        // Top Tier Analog
        .array_col_top_left      (array_col_top_left),
        .array_col_top_right     (array_col_top_right),
        .col_event_rst_top_left  (col_event_rst_top_left),
        .col_event_rst_top_right (col_event_rst_top_right),
        .pre_charge_global_top   (pre_charge_global_top),
        .row_on_detect_top       (row_on_detect_top),
        .row_off_detect_top      (row_off_detect_top),

        // Bottom Tier Analog
        .array_col_bot_left      (array_col_bot_left),
        .array_col_bot_right     (array_col_bot_right),
        .col_event_rst_bot_left  (col_event_rst_bot_left),
        .col_event_rst_bot_right (col_event_rst_bot_right),
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
        .numel_fifo_bot (numel_fifo_bot)
    );

endmodule : final_top