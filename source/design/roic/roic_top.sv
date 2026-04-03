// //---------------------------------------------------------------------------
// // Module: roic_digital_top
// // Description: 
// //  Top-level digital controller for the 64x64 Neuromorphic Imager.
// //  Integrates clk_div, roic_sm, and row_scanner.
// //---------------------------------------------------------------------------

// module roic_top (
//     `ifdef USE_POWER_PINS
//         inout vccd1, // OpenLane Power  
//         inout vssd1, // OpenLane Ground 
//     `endif

//     // System Inputs
//     input  logic        sys_clk,      // 50MHz Master Clock
//     input  logic        rst_n,        // Asynchronous Active-Low Reset
//     input  logic        sm_enable,    // Global Enable (Play/Pause)
//     input  logic [7:0]  program_bits, // Sets state duration (1us to 256us)

//     // Digital Backend Interconnects (To sync_fifo)
//     output logic        div_clk_out,  // To clock the FIFO's write domain
//     output logic [5:0]  row_addr,     // Tags the incoming data packet

//     // Physical Analog Array Outputs 
//     output logic        pre_charge_global, // 1-bit Global Column Pre-Charge
//     output logic [63:0] row_on_detect,     // 64-bit Row On-Detect
//     output logic [63:0] row_off_detect,    // 64-bit Row Off-Detect
//     output logic [63:0] row_pixel_rst,     // 64-bit Row Pixel Reset
//     output logic [63:0] row_sel            // 64-bit Row Select (Active Token)
// );

//     // Internal routing wires
//     logic div_clk_int;
//     logic sm_on_detect_int;
//     logic sm_off_detect_int;
//     logic sm_pixel_rst_int;
//     logic sm_next_row_int;

//     // Route the divided clock out
//     assign div_clk_out = div_clk_int;

//     // -----------------------------------------------------------------
//     // 1. Programmable Clock Divider
//     // -----------------------------------------------------------------
//     clk_div i_clk_div (
//         .vccd1(vccd1),
//         .vssd1(vssd1), 
//         .sys_clk      (sys_clk),
//         .rst_n        (rst_n),
//         .program_bits (program_bits),
//         .div_clk      (div_clk_int)
//     );

//     // -----------------------------------------------------------------
//     // 2. 5-State ROIC Sequencer
//     // -----------------------------------------------------------------
//     roic_sm i_roic_sm (
//         .vccd1(vccd1),
//         .vssd1(vssd1),

//         .div_clk      (div_clk_int),
//         .rst_n        (rst_n),
//         .sm_enable    (sm_enable),
        
//         .pre_charge   (pre_charge_global), 
//         .on_detect    (sm_on_detect_int),
//         .off_detect   (sm_off_detect_int),
//         .pixel_rst    (sm_pixel_rst_int),
//         .sm_next_row  (sm_next_row_int),
//         .row_addr     (row_addr)
//     );

//     // -----------------------------------------------------------------
//     // 3. Physical Row Scanner (Combinational Array Drivers)
//     // -----------------------------------------------------------------
//     row_scanner i_row_scanner (
//         .vccd1(vccd1),
//         .vssd1(vssd1),

//         .div_clk        (div_clk_int),
//         .rst_n          (rst_n),
//         .sm_enable      (sm_enable),

//         .sm_next_row    (sm_next_row_int),
        
//         .sm_on_detect   (sm_on_detect_int),
//         .sm_off_detect  (sm_off_detect_int),
//         .sm_pixel_rst   (sm_pixel_rst_int),

//         .row_on_detect  (row_on_detect),
//         .row_off_detect (row_off_detect),
//         .row_pixel_rst  (row_pixel_rst),
//         .row_sel        (row_sel)
//     );

// endmodule : roic_top

//---------------------------------------------------------------------------
// Module: roic_digital_top
// Description: 
//  Top-level wrapper for the Phase-Gated Neuromorphic Readout Controller.
//  Instantiates the Clock Divider, 3-State FSM, and 64-Row Scanner.
//---------------------------------------------------------------------------

module roic_top (
    `ifdef USE_POWER_PINS
        inout vccd1, // OpenLane Power  
        inout vssd1, // OpenLane Ground 
    `endif
    
    // System Inputs
    input  logic        sys_clk,
    input  logic        rst_n,

    // Control Plane (From RegFile)
    input  logic        sm_enable,
    input  logic [7:0]  program_bits,

    // Analog Array Control Plane
    output logic        pre_charge_global,
    output logic [63:0] row_on_detect,
    output logic [63:0] row_off_detect,
    output logic [63:0] row_pixel_rst,
    output logic [63:0] row_sel,

    // Digital Backend Data Plane (To FIFOs)
    output logic        div_clk_out, // Used as the FIFO write clock
    output logic [5:0]  row_addr,    // Binary tag for the FIFO data
    output logic        fifo_wr_en,  // Automatically triggers on Read phases
    output logic [1:0]  event_flag   // 2'b10 = ON Event, 2'b01 = OFF Event
);

    // -----------------------------------------------------------------
    // Internal Interconnects
    // -----------------------------------------------------------------
    logic div_clk_int;
    logic sm_on_detect;
    logic sm_off_detect;
    logic sm_pixel_rst;
    logic sm_next_row;
    logic sm_is_on_state;
    logic sm_is_off_state;
    
    // [NEW] Break-Before-Make routing wires
    logic eval_phase;
    logic pre_charge_phase;

    // Export the divided clock to the top level for the FIFOs
    assign div_clk_out = div_clk_int;

    // Generate FIFO write signals based on FSM state
    assign fifo_wr_en = sm_is_on_state | sm_is_off_state;
    assign event_flag = {sm_is_on_state, sm_is_off_state};

    // -----------------------------------------------------------------
    // Module Instantiations
    // -----------------------------------------------------------------
    
    clk_div i_clk_div (
        `ifdef USE_POWER_PINS
            .vccd1            (vccd1),
            .vssd1            (vssd1),
        `endif
        .sys_clk          (sys_clk),
        .rst_n            (rst_n),
        .program_bits     (program_bits),
        .div_clk          (div_clk_int),
        .eval_phase       (eval_phase),       // [ADDED]
        .pre_charge_phase (pre_charge_phase)  // [ADDED]
    );

    roic_sm i_roic_sm (
        `ifdef USE_POWER_PINS
            .vccd1             (vccd1),
            .vssd1             (vssd1),
        `endif
        .div_clk           (div_clk_int),
        .rst_n             (rst_n),
        .sm_enable         (sm_enable),
        .eval_phase        (eval_phase),       // [ADDED]
        .pre_charge_phase  (pre_charge_phase), // [ADDED]
        .pre_charge_global (pre_charge_global),
        .on_detect         (sm_on_detect),
        .off_detect        (sm_off_detect),
        .pixel_rst         (sm_pixel_rst),
        .is_on_state       (sm_is_on_state),
        .is_off_state      (sm_is_off_state),
        .sm_next_row       (sm_next_row),
        .row_addr          (row_addr)
    );

    row_scanner i_row_scanner (
        `ifdef USE_POWER_PINS
            .vccd1          (vccd1),
            .vssd1          (vssd1),
        `endif
        .div_clk        (div_clk_int),
        .rst_n          (rst_n),
        .sm_enable      (sm_enable),
        .sm_on_detect   (sm_on_detect),
        .sm_off_detect  (sm_off_detect),
        .sm_pixel_rst   (sm_pixel_rst),
        .sm_next_row    (sm_next_row),
        .row_on_detect  (row_on_detect),
        .row_off_detect (row_off_detect),
        .row_pixel_rst  (row_pixel_rst),
        .row_sel        (row_sel)
    );

endmodule : roic_top