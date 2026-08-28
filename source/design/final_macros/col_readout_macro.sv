//---------------------------------------------------------------------------
// Module: col_readout_macro
// Description: 
//  Hardened column-wise digital macro for 2x2 Quadrant Split-Bitline architecture.
//  Includes 2-stage metastability synchronizers, gated event latches, 
//  targeted pixel resets, and the FWFT FIFO / QSPI bridge.
//---------------------------------------------------------------------------

module col_readout_macro (
    `ifdef USE_POWER_PINS
        inout vccd1,
        inout vssd1,
    `endif

    input  logic                   clk,
    input  logic                   rst_n,
    input  logic                   stream_abort,

    // -----------------------------------------------------------
    // Interface to Analog Array (Quadrant Column-Wise)
    // -----------------------------------------------------------
    input  logic [63:0]            array_col_left,
    input  logic [63:0]            array_col_right,

    output logic [63:0]            col_event_rst_left,
    output logic [63:0]            col_event_rst_right,

    // -----------------------------------------------------------
    // Interface to Row FSM Macro (Central Spine Control)
    // -----------------------------------------------------------
    input  logic                   sm_enable,
    input  logic                   sm_on_detect,
    input  logic                   sm_off_detect,
    input  logic                   sm_pixel_rst,
    input  logic                   sm_next_row,     
    input  logic                   sm_detect_pulse, 

    // FIFO Write Triggers and Metadata
    input  logic                   fifo_wr_en,
    input  logic [5:0]             row_addr,
    input  logic [1:0]             event_mode, 

    output logic                   source_record_valid_o,
    output logic [135:0]           source_record_o,

    // -----------------------------------------------------------
    // Interface to Q-SPI Peripheral (Near I/O Pads)
    // -----------------------------------------------------------
    input  logic                   shift_en_fifo,
    output logic [15:0]            rdata_spi,
    
    output logic                   empty_fifo,
    output logic                   full_fifo,
    output logic [`FIFO_AWIDTH-1:0] numel_fifo
);

    // -----------------------------------------------------------------
    // 1. Continuously Running Bus Synchronizer (Metastability Shield)
    // -----------------------------------------------------------------
    //TODO: add metastability reg prefix for synthesizer
    logic [63:0] col_left_m1, col_left_m2;
    logic [63:0] col_right_m1, col_right_m2;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            col_left_m1  <= 64'd0;
            col_left_m2  <= 64'd0;
            col_right_m1 <= 64'd0;
            col_right_m2 <= 64'd0;
        end else begin
            // Resolve metastability for both quadrants simultaneously
            col_left_m1  <= array_col_left;
            col_left_m2  <= col_left_m1;
            
            col_right_m1 <= array_col_right;
            col_right_m2 <= col_right_m1;
        end
    end

    // -----------------------------------------------------------------
    // 2. Gated Latching & Targeted Reset Logic
    // -----------------------------------------------------------------
    logic [63:0] on_pixels_left, off_pixels_left;
    logic [63:0] on_pixels_right, off_pixels_right;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            on_pixels_left      <= 64'd0;
            off_pixels_left     <= 64'd0;
            col_event_rst_left  <= 64'd0;
            
            on_pixels_right     <= 64'd0;
            off_pixels_right    <= 64'd0;
            col_event_rst_right <= 64'd0;
        end else if (sm_enable) begin
            // A. The Defensive Clear
            if (sm_next_row) begin
                on_pixels_left   <= 64'd0;
                off_pixels_left  <= 64'd0;
                on_pixels_right  <= 64'd0;
                off_pixels_right <= 64'd0;
            end 
            else begin
                // B. Capture ON events from the clean, synchronized bus
                if (sm_on_detect && sm_detect_pulse) begin
                    on_pixels_left  <= col_left_m2;
                    on_pixels_right <= col_right_m2;
                end
                
                // C. Capture OFF events from the clean, synchronized bus
                if (sm_off_detect && sm_detect_pulse) begin
                    off_pixels_left  <= col_left_m2;
                    off_pixels_right <= col_right_m2;
                end
            end

            // D. Compute Reset (Fires only on pixels that actually latched an event)
            if (sm_pixel_rst) begin
                col_event_rst_left  <= on_pixels_left | off_pixels_left;
                col_event_rst_right <= on_pixels_right | off_pixels_right;
            end else begin
                col_event_rst_left  <= 64'd0;
                col_event_rst_right <= 64'd0;
            end
        end else begin
            col_event_rst_left  <= 64'd0;
            col_event_rst_right <= 64'd0;
        end
    end

    // -----------------------------------------------------------------
    // 3. FIFO Data Formatting (Using the Synchronized Bus)
    // -----------------------------------------------------------------
    logic [135:0] internal_wdata_fifo;

    // Mapping Left and Right quadrants into the 136-bit word
    assign internal_wdata_fifo = {event_mode, row_addr, col_left_m2, col_right_m2};
    assign source_record_valid_o = fifo_wr_en;
    assign source_record_o = {event_mode, row_addr, col_left_m2, col_right_m2};

    // -----------------------------------------------------------------
    // 4. Synchronous FWFT FIFO & Q-SPI Bridge
    // -----------------------------------------------------------------
    sync_fifo_top3 i_sync_fifo_top (
        `ifdef USE_POWER_PINS
            .vccd1         (vccd1),
            .vssd1         (vssd1),
        `endif
        .clk           (clk),
        .rst_n         (rst_n),
        .stream_abort  (stream_abort),
        
        // Write Interface 
        .wr_en_fifo    (fifo_wr_en),
        .wdata_fifo    (internal_wdata_fifo),
        .empty_fifo    (empty_fifo),
        .full_fifo     (full_fifo),
        .numel_fifo    (numel_fifo),
        
        // Read Interface
        .shift_en_fifo (shift_en_fifo),
        .rdata_spi     (rdata_spi)
    );

endmodule : col_readout_macro
