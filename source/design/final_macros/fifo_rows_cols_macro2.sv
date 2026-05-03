//---------------------------------------------------------------------------
// Module: fifo_rows_cols_macro
// Description: 
//  Top-level digital integration of the 128x128 split-bitline architecture.
//  Utilizes a Dual-Spine layout: Independent Row Decoders and Column Readouts 
//  for the Top and Bottom tiers to maximize parallel throughput.
//  Upgraded to support 14-bit programmable phase tunings.
//---------------------------------------------------------------------------

module fifo_rows_cols_macro2 (
    `ifdef USE_POWER_PINS
        inout vccd1,
        inout vssd1,
    `endif

    input  logic         sys_clk,
    input  logic         rst_n,

    // Control Plane (From RegFile)
    input  logic         sm_enable,
    input  logic [7:0]   program_bits,

    // Programmable Timing Inputs (14-BIT TUNING)
    input  logic [13:0]  p_pre_charge,
    input  logic [13:0]  p_buffer,
    input  logic [13:0]  p_detect,
    input  logic [13:0]  p_on_detect,
    input  logic [13:0]  p_off_detect,
    input  logic [13:0]  p_rst,

    // -----------------------------------------------------------
    // Analog Array Interfaces (128x128 Grid)
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

    // -----------------------------------------------------------
    // Q-SPI Readout Interfaces
    // -----------------------------------------------------------
    // Top Tier FIFO
    input  logic                        shift_en_top,
    output logic [15:0]                 rdata_spi_top,
    output logic                        empty_fifo_top,
    output logic                        full_fifo_top,
    output logic [`FIFO_AWIDTH-1:0]     numel_fifo_top,
    
    // Bottom Tier FIFO
    input  logic                        shift_en_bot,
    output logic [15:0]                 rdata_spi_bot,
    output logic                        empty_fifo_bot,
    output logic                        full_fifo_bot,
    output logic [`FIFO_AWIDTH-1:0]     numel_fifo_bot
);

    // -----------------------------------------------------------------
    // Internal Cross-Chip Control Routing (Top Tier)
    // -----------------------------------------------------------------
    logic       sm_on_detect_top;
    logic       sm_off_detect_top;
    logic [1:0] sm_detect_pulse_top;
    logic       sm_detect_pulse_top_int;
    logic       sm_pixel_rst_top;
    logic       sm_next_row_top;

    logic [5:0] row_addr_top;
    logic       fifo_wr_en_top;
    logic [1:0] event_mode_top;

    // -----------------------------------------------------------------
    // Internal Cross-Chip Control Routing (Bottom Tier)
    // -----------------------------------------------------------------
    logic       sm_on_detect_bot;
    logic       sm_off_detect_bot;
    logic [1:0] sm_detect_pulse_bot;
    logic       sm_detect_pulse_bot_int;
    logic       sm_pixel_rst_bot;
    logic       sm_next_row_bot;

    logic [5:0] row_addr_bot;
    logic       fifo_wr_en_bot;
    logic [1:0] event_mode_bot;

    // =================================================================
    // TOP TIER INSTANTIATIONS (Rows 0-63)
    // =================================================================
    
    row_decoder_macro2 i_row_decoder_top (
        `ifdef USE_POWER_PINS
            .vccd1             (vccd1),
            .vssd1             (vssd1),
        `endif

        .sys_clk           (sys_clk),
        .rst_n             (rst_n),
        .sm_enable         (sm_enable),
        .program_bits      (program_bits),

        // New 14-bit Phase Tunings
        .p_pre_charge      (p_pre_charge),
        .p_buffer          (p_buffer),
        .p_detect          (p_detect),
        .p_on_detect       (p_on_detect),
        .p_off_detect      (p_off_detect),
        .p_rst             (p_rst),
        
        .pre_charge_global (pre_charge_global_top),
        .row_on_detect     (row_on_detect_top),
        .row_off_detect    (row_off_detect_top),
        
        .sm_on_detect      (sm_on_detect_top),
        .sm_off_detect     (sm_off_detect_top),
        .detect_pulse_global   (sm_detect_pulse_top),
        .sm_pixel_rst      (sm_pixel_rst_top),
        .sm_next_row       (sm_next_row_top),
        
        .row_addr          (row_addr_top),
        .fifo_wr_en        (fifo_wr_en_top),
        .event_mode        (event_mode_top)
    );

    assign sm_detect_pulse_top_int = sm_detect_pulse_top[0];
    assign detect_pulse_global_top = sm_detect_pulse_top;

    col_readout_macro i_col_readout_top (
        `ifdef USE_POWER_PINS
            .vccd1             (vccd1),
            .vssd1             (vssd1),
        `endif

        .clk                 (sys_clk),
        .rst_n               (rst_n),
        
        .array_col_left      (array_col_top_left),
        .array_col_right     (array_col_top_right),
        .col_event_rst_left  (col_event_rst_top_left),
        .col_event_rst_right (col_event_rst_top_right),
        
        .sm_enable           (sm_enable),
        .sm_on_detect        (sm_on_detect_top),
        .sm_off_detect       (sm_off_detect_top),
        .sm_pixel_rst        (sm_pixel_rst_top),
        .sm_next_row         (sm_next_row_top),
        .sm_detect_pulse     (sm_detect_pulse_top_int), 
        
        .fifo_wr_en          (fifo_wr_en_top),
        .row_addr            (row_addr_top),
        .event_mode          (event_mode_top),
        
        .shift_en_fifo       (shift_en_top),
        .rdata_spi           (rdata_spi_top),
        .empty_fifo          (empty_fifo_top),
        .full_fifo           (full_fifo_top), 
        .numel_fifo          (numel_fifo_top)
    );

    // =================================================================
    // BOTTOM TIER INSTANTIATIONS (Rows 64-127)
    // =================================================================
    
    row_decoder_macro2 i_row_decoder_bot (
        `ifdef USE_POWER_PINS
            .vccd1             (vccd1),
            .vssd1             (vssd1),
        `endif

        .sys_clk           (sys_clk),
        .rst_n             (rst_n),
        .sm_enable         (sm_enable),
        .program_bits      (program_bits),

        // New 14-bit Phase Tunings
        .p_pre_charge      (p_pre_charge),
        .p_buffer          (p_buffer),
        .p_detect          (p_detect),
        .p_on_detect       (p_on_detect),
        .p_off_detect      (p_off_detect),
        .p_rst             (p_rst),
        
        .pre_charge_global (pre_charge_global_bot),
        .row_on_detect     (row_on_detect_bot),
        .row_off_detect    (row_off_detect_bot),
        
        .sm_on_detect      (sm_on_detect_bot),
        .sm_off_detect     (sm_off_detect_bot),
        .detect_pulse_global   (sm_detect_pulse_bot),
        .sm_pixel_rst      (sm_pixel_rst_bot),
        .sm_next_row       (sm_next_row_bot),
        
        .row_addr          (row_addr_bot),
        .fifo_wr_en        (fifo_wr_en_bot),
        .event_mode        (event_mode_bot)
    );

    assign sm_detect_pulse_bot_int = sm_detect_pulse_bot[0];
    assign detect_pulse_global_bot = sm_detect_pulse_bot;

    col_readout_macro i_col_readout_bot (
        `ifdef USE_POWER_PINS
            .vccd1             (vccd1),
            .vssd1             (vssd1),
        `endif
        
        .clk                 (sys_clk),
        .rst_n               (rst_n),
        
        .array_col_left      (array_col_bot_left),
        .array_col_right     (array_col_bot_right),
        .col_event_rst_left  (col_event_rst_bot_left),
        .col_event_rst_right (col_event_rst_bot_right),
        
        .sm_enable           (sm_enable),
        .sm_on_detect        (sm_on_detect_bot),
        .sm_off_detect       (sm_off_detect_bot),
        .sm_pixel_rst        (sm_pixel_rst_bot),
        .sm_next_row         (sm_next_row_bot),
        .sm_detect_pulse     (sm_detect_pulse_bot_int), 
        
        .fifo_wr_en          (fifo_wr_en_bot),
        .row_addr            (row_addr_bot),
        .event_mode          (event_mode_bot),
        
        .shift_en_fifo       (shift_en_bot),
        .rdata_spi           (rdata_spi_bot),
        .empty_fifo          (empty_fifo_bot),
        .full_fifo           (full_fifo_bot),
        .numel_fifo          (numel_fifo_bot)
    );

endmodule : fifo_rows_cols_macro2