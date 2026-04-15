//---------------------------------------------------------------------------
// Author: Ababakar Okieh
// Date  : April 4th, 2026
//
// Module: row_decoder_macro
// Description: 
//  Central spine wrapper for the Phase-Gated Neuromorphic Readout Controller.
//  Instantiates the 50MHz Micro-Sequencer (FSM) and Row Scanner.
//  Exports synchronization states to the peripheral column readout macros.
//---------------------------------------------------------------------------

module row_decoder_macro (
    `ifdef USE_POWER_PINS
        inout vccd1, // OpenLane Power  
        inout vssd1, // OpenLane Ground 
    `endif
    
    // System Inputs
    input  logic        sys_clk,      // 50MHz Master Clock
    input  logic        rst_n,        // Asynchronous Active-Low Reset

    // Control Plane (From RegFile/Processor)
    input  logic        sm_enable,    // Global Enable (Play/Pause)
    input  logic [7:0]  program_bits, // Sets state duration

    // -----------------------------------------------------------
    // Analog Array Control Plane (To Pixel Rows)
    // -----------------------------------------------------------
    output logic [1:0]  pre_charge_global, // Active LOW
    output logic [63:0] row_on_detect,
    output logic [63:0] row_off_detect,

    // -----------------------------------------------------------
    // Cross-Chip Digital Control (To col_readout_macro)
    // -----------------------------------------------------------
    output logic        sm_on_detect,
    output logic        sm_off_detect,
    output logic [1:0]  sm_detect_pulse,
    output logic        sm_pixel_rst,
    output logic        sm_next_row,

    // FIFO Write Triggers and Metadata
    output logic [5:0]  row_addr,    // Binary tag for the FIFO data
    output logic        fifo_wr_en,  // Automatically triggers on Read phases
    output logic [1:0]  event_mode   // 2'b10 = ON Event, 2'b01 = OFF Event
);

// -----------------------------------------------------------------
    // Internal Interconnects & Fanout
    // -----------------------------------------------------------------
    logic int_pre_charge;
    logic int_detect_pulse;

    // Explicitly duplicate the 1-bit FSM signals to the 2-bit quadrant buses
    assign pre_charge_global = {2{int_pre_charge}};
    assign sm_detect_pulse   = {2{int_detect_pulse}};

    // -----------------------------------------------------------------
    // 1. Continuous Pacing Micro-Sequencer
    // -----------------------------------------------------------------
    roic_sm i_roic_sm (
        `ifdef USE_POWER_PINS
            .vccd1             (vccd1),
            .vssd1             (vssd1),
        `endif
        
        .sys_clk           (sys_clk),
        .rst_n             (rst_n),
        .sm_enable         (sm_enable),
        .program_bits      (program_bits),
        
        // Analog Pulses (Using internal wires for 2-bit fanout)
        .pre_charge_global (int_pre_charge),
        .on_detect         (sm_on_detect),
        .off_detect        (sm_off_detect),
        .detect_pulse      (int_detect_pulse),
        .pixel_rst         (sm_pixel_rst),
        
        // Digital Backend Controls
        .sm_next_row       (sm_next_row),
        .row_addr          (row_addr),
        .fifo_wr_en        (fifo_wr_en),
        .event_flag        (event_mode) 
    );

    // -----------------------------------------------------------------
    // 2. Physical Row Scanner (Shift Token & Drivers)
    // -----------------------------------------------------------------
    row_scanner i_row_scanner (
        `ifdef USE_POWER_PINS
            .vccd1          (vccd1),
            .vssd1          (vssd1),
        `endif
        
        .div_clk        (sys_clk),     
        .rst_n          (rst_n),
        
        .sm_enable      (sm_enable),
        .sm_on_detect   (sm_on_detect),
        .sm_off_detect  (sm_off_detect),
        .sm_next_row    (sm_next_row),
        
        .row_on_detect  (row_on_detect),
        .row_off_detect (row_off_detect)
    );

endmodule : row_decoder_macro