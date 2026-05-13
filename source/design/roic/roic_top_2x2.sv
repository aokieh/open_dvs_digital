//---------------------------------------------------------------------------
// Author: Ababakar Okieh
// Date  : April 4th, 2026 (Updated for 2x1 Array)
//
// Module: roic_top0
// Description: 
//  Top-level wrapper for the Phase-Gated Neuromorphic Readout Controller.
//  Instantiates the 50MHz Micro-Sequencer (FSM), Row Scanner, and Column Event Logic
//  configured strictly for a 2-row, 1-column test array.
//---------------------------------------------------------------------------

module roic_top0 (
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

    // Programmable Timing Inputs (Ticks)
    input  logic [13:0]  p_pre_charge,
    input  logic [13:0]  p_buffer,
    input  logic [13:0]  p_detect,
    input  logic [13:0]  p_on_detect,
    input  logic [13:0]  p_off_detect,
    input  logic [13:0]  p_rst,

    // Data FROM the Pixel Array (1 Column)
    input  logic [1:0]  array_col_out, 

    // Analog Array Control Plane (2 Rows)
    output logic        pre_charge_global, // Active LOW
    output logic [1:0]  row_on_detect,
    output logic [1:0]  row_off_detect,

    // Analog Array Control Plane (1 Column)
    output logic [1:0]  col_pixel_rst,

    // Digital Backend Data Plane (To FIFOs)
    output logic        row_addr,    // 1-bit address for 2 rows
    output logic        fifo_wr_en,  // Automatically triggers on Read phases
    output logic [1:0]  event_flag,  // 2'b10 = ON Event, 2'b01 = OFF Event
    
    // Condensed FIFO write data: {col_data(1), event(2), row_addr(1)} = 4 bits
    // output logic [3:0]  wdata_to_fifo  
    output logic        detect,
    output logic        ndetect
);

    // -----------------------------------------------------------------
    // Internal Interconnects
    // -----------------------------------------------------------------
    logic               sm_on_detect;
    logic               sm_off_detect;
    logic               sm_detect_pulse;
    logic               sm_pixel_rst;
    logic               sm_next_row;
    

    assign detect  = sm_detect_pulse;
    assign ndetect = ~sm_detect_pulse;
    // logic [3:0]         evt_to_fifo;

    // Concatenate the single bit signals into a 4-bit bus for backend logging
    // assign evt_to_fifo   = {array_col_out, event_flag, row_addr}; 
    // assign wdata_to_fifo = evt_to_fifo;

    // -----------------------------------------------------------------
    // 1. Continuous Pacing Micro-Sequencer (roic_sm0)
    // -----------------------------------------------------------------
    roic_sm2_2x2 i_roic_sm (
        `ifdef USE_POWER_PINS
            .vccd1             (vccd1),
            .vssd1             (vssd1),
        `endif
        
        .sys_clk           (sys_clk),
        .rst_n             (rst_n),
        .sm_enable         (sm_enable),
        .program_bits      (program_bits),
        
        // Programmable Timing Inputs
        .p_pre_charge(p_pre_charge),
        .p_buffer(p_buffer),
        .p_detect(p_detect),
        .p_on_detect(p_on_detect),
        .p_off_detect(p_off_detect),
        .p_rst(p_rst),

        // Analog Pulses
        .pre_charge_global (pre_charge_global),
        .on_detect         (sm_on_detect),
        .off_detect        (sm_off_detect),
        .detect_pulse      (sm_detect_pulse),
        .pixel_rst         (sm_pixel_rst),
        
        // Digital Backend Controls
        .sm_next_row       (sm_next_row),
        .row_addr          (row_addr),
        .fifo_wr_en        (fifo_wr_en),
        .event_flag        (event_flag)
    );

    // -----------------------------------------------------------------
    // 2. Physical Row Scanner (Shift Token & Drivers)
    // -----------------------------------------------------------------
    row_scanner0 i_row_scanner (
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
        
        // 2-bit outputs to the analog array
        .row_on_detect  (row_on_detect),
        .row_off_detect (row_off_detect)
    );

    // -----------------------------------------------------------------
    // 3. Column Event Reset Block (Pixel Latch & Wipe)
    // -----------------------------------------------------------------
    col_event_rst0 i_col_event_rst (
        `ifdef USE_POWER_PINS
            .vccd1          (vccd1),
            .vssd1          (vssd1),
        `endif

        .div_clk          (sys_clk),     
        .rst_n            (rst_n),
        
        .sm_on_detect     (sm_on_detect),
        .sm_off_detect    (sm_off_detect),
        .sm_pixel_rst     (sm_pixel_rst),
        .sm_next_row      (sm_next_row),
        .sm_detect_pulse  (sm_detect_pulse),
        
        // Single bit connections
        .array_col_out    (array_col_out),
        .col_pixel_rst    (col_pixel_rst)
    );

endmodule : roic_top0