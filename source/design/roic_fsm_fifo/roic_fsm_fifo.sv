



roic_top i_roic_top (
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
    input  logic [`IMAGER_COL_WIDTH-1:0] array_col_out, 

    // Analog Array Control Plane (Rows)
    output logic        pre_charge_global, // Active LOW
    output logic [63:0] row_on_detect,
    output logic [63:0] row_off_detect,
    // output logic [63:0] row_pixel_rst,
    // output logic [63:0] row_sel,

    // Analog Array Control Plane (Columns)
    output logic [`IMAGER_COL_WIDTH-1:0] col_pixel_rst,

    // Digital Backend Data Plane (To FIFOs)
    output logic [5:0]  row_addr,    // Binary tag for the FIFO data
    output logic        fifo_wr_en,  // Automatically triggers on Read phases
    output logic [1:0]  event_flag,   // 2'b10 = ON Event, 2'b01 = OFF Event
    output logic [`FIFO_WIDTH-1:0] wdata_to_fifo  //TODO: add later
);