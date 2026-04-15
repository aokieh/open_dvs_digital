//---------------------------------------------------------------------------
// Author: Ababakar Okieh
// Date  : April 3rd, 2026
//
// Module: col_event_rst
//
// Description: 
//  Behavioral reset for analog column peripherals in OpenDVS.
//---------------------------------------------------------------------------


module col_event_rst0 (
    `ifdef USE_POWER_PINS
        inout vccd1, // OpenLane Power  
        inout vssd1, // OpenLane Ground 
    `endif

    input  logic        div_clk,
    input  logic        rst_n,

    // Global Control Pulses (From roic_sm)
    input  logic        sm_on_detect,
    input  logic        sm_off_detect,
    input  logic        sm_pixel_rst,
    input  logic        sm_next_row,          // To wipe the slate clean
    input  logic        sm_detect_pulse,      // Mid-read column trigger

    // Data FROM the Pixel Array
    // input  logic [`IMAGER_COL_WIDTH-1:0] array_col_out,
    input  logic        array_col_out, 

    // Output TO the Pixel Array
    // output logic [`IMAGER_COL_WIDTH-1:0] col_pixel_rst
    output logic        col_pixel_rst
);

    // -----------------------------------------------------------------
    // 1. Continuously Running Bus Synchronizer
    // -----------------------------------------------------------------
    logic   col_out_m1;
    logic  col_out_m2;

    always_ff @(posedge div_clk or negedge rst_n) begin
        if (!rst_n) begin
            col_out_m1 <= 1'd0;
            col_out_m2 <= 1'd0;
        end else begin
            // This runs EVERY cycle. Metastability resolves here safely.
            col_out_m1 <= array_col_out;
            col_out_m2 <= col_out_m1;
        end
    end

    // -----------------------------------------------------------------
    // 2. Gated Latching & Logic
    // -----------------------------------------------------------------
    logic  on_pixels_reg;
    logic  off_pixels_reg;

    always_ff @(posedge div_clk or negedge rst_n) begin
        if (!rst_n) begin
            on_pixels_reg  <= 1'd0;
            off_pixels_reg <= 1'd0;
            col_pixel_rst  <= 1'd0;
        end else begin
            // A. The Defensive Clear
            // Wipe the registers when moving to a new row
            if (sm_next_row) begin
                on_pixels_reg  <= 1'd0;
                off_pixels_reg <= 1'd0;
            end 
            else begin
                // B. Capture ON events from the clean, synchronized bus
                if (sm_on_detect && sm_detect_pulse) begin
                    on_pixels_reg  <= col_out_m2;
                end
                
                // C. Capture OFF events from the clean, synchronized bus
                if (sm_off_detect && sm_detect_pulse) begin
                    off_pixels_reg <= col_out_m2;
                end
            end

            // D. Compute Reset (Independent of the data capture flow)
            if (sm_pixel_rst) begin
                col_pixel_rst <= on_pixels_reg | off_pixels_reg;
            end else begin
                col_pixel_rst <= 1'd0;
            end
        end
    end

endmodule : col_event_rst0