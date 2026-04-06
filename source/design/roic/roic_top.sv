//---------------------------------------------------------------------------
// Author: Ababakar Okieh
// Date  :April 4th, 2026
//
// Module: roic_top
// Description: 
//  Top-level wrapper for the Phase-Gated Neuromorphic Readout Controller.
//  Instantiates the 50MHz Micro-Sequencer (FSM), Row Scanner, and Column Event Logic.
//  (Fully synchronous to sys_clk)
//---------------------------------------------------------------------------

module roic_top (
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

    // Data FROM the Pixel Array
    input  logic [63:0] array_col_out, 

    // Analog Array Control Plane (Rows)
    output logic        pre_charge_global, // Active LOW
    output logic [63:0] row_on_detect,
    output logic [63:0] row_off_detect,
    // output logic [63:0] row_pixel_rst,
    // output logic [63:0] row_sel,

    // Analog Array Control Plane (Columns)
    output logic [63:0] col_pixel_rst,

    // Digital Backend Data Plane (To FIFOs)
    output logic [5:0]  row_addr,    // Binary tag for the FIFO data
    output logic        fifo_wr_en,  // Automatically triggers on Read phases
    output logic [1:0]  event_flag   // 2'b10 = ON Event, 2'b01 = OFF Event
    // output logic [`FIFO_WIDTH-1:0] wdata_to_fifo  TODO: add later
);

    // -----------------------------------------------------------------
    // Internal Interconnects
    // -----------------------------------------------------------------
    logic                   sm_on_detect;
    logic                   sm_off_detect;
    logic                   sm_detect_pulse;
    logic                   sm_pixel_rst;
    logic                   sm_next_row;
    // logic [`FIFO_WIDTH-1:0] evt_to_fifo;

    // assign evt_to_fifo = {array_col_out, event_flag, row_addr}; TODO: add later

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
    row_scanner i_row_scanner (
        `ifdef USE_POWER_PINS
            .vccd1          (vccd1),
            .vssd1          (vssd1),
        `endif
        
        // [UPDATED] Driven directly by sys_clk
        .div_clk        (sys_clk),     
        .rst_n          (rst_n),
        
        .sm_enable      (sm_enable),
        .sm_on_detect   (sm_on_detect),
        .sm_off_detect  (sm_off_detect),
        // .sm_pixel_rst   (sm_pixel_rst),
        .sm_next_row    (sm_next_row),
        
        .row_on_detect  (row_on_detect),
        .row_off_detect (row_off_detect)
        // .row_pixel_rst  (row_pixel_rst),
        // .row_sel        (row_sel) // TODO: remove this signal
    );

    // -----------------------------------------------------------------
    // 3. Column Event Reset Block (Pixel Latch & Wipe)
    // -----------------------------------------------------------------
    col_event_rst i_col_event_rst (
        // Note: No OpenLane power pins declared in this module's signature
        
        // [UPDATED] Driven directly by sys_clk
        .div_clk          (sys_clk),     
        .rst_n            (rst_n),
        
        .sm_on_detect     (sm_on_detect),
        .sm_off_detect    (sm_off_detect),
        .sm_pixel_rst     (sm_pixel_rst),
        .sm_next_row      (sm_next_row),
        .sm_detect_pulse  (sm_detect_pulse),
        
        .array_col_out    (array_col_out),
        .col_pixel_rst    (col_pixel_rst)
    );

endmodule : roic_top