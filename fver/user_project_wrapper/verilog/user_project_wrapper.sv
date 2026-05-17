/* verilator lint_off UNUSEDSIGNAL */
/* verilator lint_off UNUSEDPARAM */
`default_nettype none

module user_project_wrapper #(
    parameter BITS = 32
) (
`ifdef USE_POWER_PINS
    inout vdda1,    // User area 1 3.3V supply
    inout vdda2,    // User area 2 3.3V supply
    inout vssa1,    // User area 1 analog ground
    inout vssa2,    // User area 2 analog ground
    inout vccd1,    // User area 1 1.8V supply
    inout vccd2,    // User area 2 1.8v supply
    inout vssd1,    // User area 1 digital ground
    inout vssd2,    // User area 2 digital ground
`endif

    // Wishbone Slave ports (WB MI A)
    input wb_clk_i,
    input wb_rst_i,
    input wbs_stb_i,
    input wbs_cyc_i,
    input wbs_we_i,
    input [3:0] wbs_sel_i,
    input [31:0] wbs_dat_i,
    input [31:0] wbs_adr_i,
    output wbs_ack_o,
    output [31:0] wbs_dat_o,

    // Logic Analyzer Signals
    input  [127:0] la_data_in,
    output [127:0] la_data_out,
    input  [127:0] la_oenb,

    // IOs
    input  [`MPRJ_IO_PADS-1:0] io_in,
    output [`MPRJ_IO_PADS-1:0] io_out,
    output [`MPRJ_IO_PADS-1:0] io_oeb,

    // Analog (direct connection to GPIO pad---use with caution)
    inout [`MPRJ_IO_PADS-10:0] analog_io,

    // Independent clock (on independent integer divider)
    input   user_clock2,

    // User maskable interrupt signals
    output [2:0] user_irq
);

    // =======================================================
    // 1. Explicit Output Enable (OEB) Setup
    // =======================================================
    // 1 = Input (Disables digital output buffer)
    // 0 = Output (Enables digital output buffer)
    
    assign io_oeb[6:0]   = 7'h7F;   // Unused/Housekeeping
    
    // Active Digital Inputs
    assign io_oeb[7]     = 1'b1;    // clk
    assign io_oeb[8]     = 1'b1;    // rst_n
    assign io_oeb[9]     = 1'b1;    // CS_N
    assign io_oeb[13:10] = 4'b1111; // COPI[3:0]
    assign io_oeb[14]    = 1'b1;    // sm_enable
    assign io_oeb[15]    = 1'b1;    // pix_rst_global_in (Moved to Pin 15)
    
    // Active Digital Outputs
    assign io_oeb[19:16] = 4'b0000; // CIPO[3:0] 
    assign io_oeb[20]    = 1'b0;    // data_ready_top 
    
    // Unused Digital + Analog pads (Tie to 1 to protect lines)
    // Pin 21 is now safely in this unused block
    assign io_oeb[37:21] = 17'h1FFFF;

    // =======================================================
    // 1.5 Mandatory Tie-Offs for Unused Outputs (Fixes Yosys)
    // =======================================================
    
    // io_out must be driven to 0 for all inputs and unused pads
    assign io_out[15:0]  = 16'b0;
    assign io_out[37:21] = 17'b0;

    // SoC interfaces must be tied to 0 to prevent unmapped cell errors
    assign wbs_ack_o   = 1'b0;
    assign wbs_dat_o   = 32'b0;
    assign la_data_out = 128'b0;
    assign user_irq    = 3'b0;


    // =======================================================
    // 2. Input Synchronizers (Metastability Protection)
    // =======================================================
    logic sm_enable_meta1, sm_enable_meta2, sm_enable_sync;
    logic pix_rst_meta1,   pix_rst_meta2,   pix_rst_sync;

    // Use io_in[7] as clk, and io_in[8] as rst_n
    always_ff @(posedge io_in[7] or negedge io_in[8]) begin
        if (!io_in[8]) begin
            sm_enable_meta1 <= 1'b0;
            sm_enable_meta2 <= 1'b0;
            sm_enable_sync  <= 1'b0;
            pix_rst_meta1   <= 1'b0;
            pix_rst_meta2   <= 1'b0;
            pix_rst_sync    <= 1'b0;
        end else begin
            // 2-Stage Flip-Flop Synchronizer for FSM Enable
            sm_enable_meta1 <= io_in[14];
            sm_enable_meta2 <= sm_enable_meta1;
            sm_enable_sync  <= sm_enable_meta2;

            // 2-Stage Flip-Flop Synchronizer for Pixel Reset
            pix_rst_meta1   <= io_in[15]; // <--- Accurately mapped to Pin 15
            pix_rst_meta2   <= pix_rst_meta1;
            pix_rst_sync    <= pix_rst_meta2;
        end
    end

    // =======================================================
    // 3. OpenDVS Core Complex Instantiation
    // =======================================================

    open_dvs_top core_inst (
        `ifdef USE_POWER_PINS
            .vdda1(vdda1),
            .vssa1(vssa1),
            .vccd1(vccd1),
            .vssd1(vssd1),
        `endif

        // System Control
        .clk(io_in[7]),
        .rst_n(io_in[8]),
        .sm_enable(sm_enable_sync),          // Synchronized Input
        .pix_rst_global_in(pix_rst_sync),    // Synchronized Input

        // SPI Interface
        .CS_N(io_in[9]),
        .COPI(io_in[13:10]),
        .CIPO(io_out[19:16]),                // Direct output map drives io_out natively

        // Status Flags
        .data_ready_top(io_out[20]),         // Direct output map drives io_out natively

        // Analog Override (10 Pins)
        // analog_io index = mprj_io pin_number - 7
        // Therefore, mprj_io[26:35] maps to analog_io[19:28]
        .pad_bias(analog_io[28:19]),
        // Single Analog Receiver (rx) -> Maps to mprj_io[25]
        .rx(analog_io[18])
    );

endmodule