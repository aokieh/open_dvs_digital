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
    // 1. Digital to Analog Macro Interconnect Wires
    // =======================================================
    wire [63:0] array_col_top_left, array_col_top_right, array_col_bot_left, array_col_bot_right;
    wire [63:0] col_event_rst_top_left, col_event_rst_top_right, col_event_rst_bot_left, col_event_rst_bot_right;
    wire [63:0] row_on_detect_top, row_off_detect_top, row_on_detect_bot, row_off_detect_bot;
    
    wire [1:0] detect_pulse_global_top, pre_charge_global_top, detect_pulse_global_bot, pre_charge_global_bot;
    
    wire [10:0] dac_config_0, dac_config_1, dac_config_2, dac_config_3, dac_config_4;
    wire [10:0] dac_config_5, dac_config_6, dac_config_7, dac_config_8, dac_config_9;

    // Internal wires for metastability
    logic sm_enable_meta1, sm_enable_meta2, sm_enable_sync;
    logic pix_rst_meta1, pix_rst_meta2,   pix_rst_sync;
    wire sync_pix_rst_top_left,  sync_pix_rst_bot_left;
    wire sync_pix_rst_top_right, sync_pix_rst_bot_right;



    // =======================================================
    // 2. Constant Tie-Offs for Wrapper Outputs
    // (Requires SYNTH_ELABORATE_ONLY = false to become physical cells)
    // =======================================================
    
    // -------------------------------------------------------
    // OEB Setup (1 = Input, 0 = Output)
    // -------------------------------------------------------
    // Active Inputs
    assign io_oeb[7]     = 1'b1;    // clk
    assign io_oeb[8]     = 1'b1;    // rst_n
    assign io_oeb[9]     = 1'b1;    // cs_n
    assign io_oeb[13:10] = 4'b1111; // copi
    assign io_oeb[14]    = 1'b1;    // sm_enable
    // assign io_oeb[15]    = 1'b1;    // clk
    assign io_oeb[21]    = 1'b1;    // async_array_rst

    // Active Outputs
    assign io_oeb[19:16] = 4'b0000; // cipo
    assign io_oeb[20]    = 1'b0;    // data_ready
    
    // Unused OEBs (Tied to 1 to make them safe inputs)
    assign io_oeb[6:0]   = 7'hFF;
    assign io_oeb[15]    = 1'b0;   
    assign io_oeb[37:22] = 16'hFFFF; 

    // -------------------------------------------------------
    // IO_OUT Tie-Offs (Must be 0 for all inputs and unused pins)
    // -------------------------------------------------------
    assign io_out[7:0]   = 8'h00;
    assign io_out[8]     = 1'b0;    // rst_n tie-off
    assign io_out[14:9]  = 6'h00;   // cs_n, copi, sm_enable
    assign io_out[15]    = 1'b0;
    assign io_out[21]    = 1'b0;    // async_array_rst tie-off
    assign io_out[37:22] = 16'h0000;

    // -------------------------------------------------------
    // Tie off unused SoC internal interfaces
    // -------------------------------------------------------
    assign wbs_ack_o   = 1'b0;
    assign wbs_dat_o   = 32'b0;
    assign la_data_out = 128'b0;
    assign user_irq    = 3'b0;

    // =======================================================
    // 2.5 Input Synchronizers (Metastability Protection)
    // =======================================================
    // assign sm_enable_meta = io_in[14];
    // assign pix_rst_meta   = io_in[21];
    assign sync_pix_rst_top_left  = pix_rst_sync;
    assign sync_pix_rst_top_right = pix_rst_sync;
    assign sync_pix_rst_bot_left  = pix_rst_sync;
    assign sync_pix_rst_bot_right = pix_rst_sync;

    // Use io_in[15] as clk, and io_in[8] as rst_n
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
            sm_enable_sync <= sm_enable_meta2;

            // 2-Stage Flip-Flop Synchronizer for Pixel Reset
            pix_rst_meta1   <= io_in[21];
            pix_rst_meta2   <= pix_rst_meta1;
            pix_rst_sync    <= pix_rst_meta2;
        end
    end

    // =======================================================
    // 3. Macro Instantiations (Direct Port Mappings)
    // =======================================================

    final_top3 final_top_inst (
        `ifdef USE_POWER_PINS
            .vccd1(vccd1),
            .vssd1(vssd1),
        `endif
        // External Digital IO (Direct from Caravel Pads)
        .clk(io_in[7]),
        .rst_n(io_in[8]),
        .CS_N(io_in[9]),
        // .sm_enable(io_in[14]),
        .sm_enable(sm_enable_sync), //changed for metastability
        .COPI(io_in[13:10]),
        .CIPO(io_out[19:16]),
        .data_ready_top(io_out[20]),
        // .pix_rst_global_in(io_in[21]),
        .pix_rst_global_in(pix_rst_sync), //changed for metastability

        // DAC Configs
        .dac_config_0(dac_config_0), .dac_config_1(dac_config_1),
        .dac_config_2(dac_config_2), .dac_config_3(dac_config_3),
        .dac_config_4(dac_config_4), .dac_config_5(dac_config_5),
        .dac_config_6(dac_config_6), .dac_config_7(dac_config_7),
        .dac_config_8(dac_config_8), .dac_config_9(dac_config_9),

        // Analog Interconnects
        .array_col_top_left(array_col_top_left),           .array_col_top_right(array_col_top_right),
        .col_event_rst_top_left(col_event_rst_top_left),   .col_event_rst_top_right(col_event_rst_top_right),
        .array_col_bot_left(array_col_bot_left),           .array_col_bot_right(array_col_bot_right),
        .col_event_rst_bot_left(col_event_rst_bot_left),   .col_event_rst_bot_right(col_event_rst_bot_right),
        .row_on_detect_top(row_on_detect_top),             .row_off_detect_top(row_off_detect_top),
        .row_on_detect_bot(row_on_detect_bot),             .row_off_detect_bot(row_off_detect_bot),
        .pre_charge_global_top(pre_charge_global_top),     .detect_pulse_global_top(detect_pulse_global_top),
        .pre_charge_global_bot(pre_charge_global_bot),     .detect_pulse_global_bot(detect_pulse_global_bot)

        // Analog Imager Reset
        // .pix_rst_global_top_left  (sync_pix_rst_top_left),
        // .pix_rst_global_bot_left  (sync_pix_rst_bot_left),
        // .pix_rst_global_top_right (sync_pix_rst_top_right),
        // .pix_rst_global_bot_right (sync_pix_rst_bot_right)
    );

    (* keep *)
    Imager_Top_no_m5 analog_imager_inst (
        `ifdef USE_POWER_PINS
            .vdda1(vdda1),
            .vssa1(vssa1),
        `endif
        // North/South Columns
        .array_col_top_left(array_col_top_left),           .array_col_top_right(array_col_top_right),
        .col_event_rst_top_left(col_event_rst_top_left),   .col_event_rst_top_right(col_event_rst_top_right),
        .array_col_bot_left(array_col_bot_left),           .array_col_bot_right(array_col_bot_right),
        .col_event_rst_bot_left(col_event_rst_bot_left),   .col_event_rst_bot_right(col_event_rst_bot_right),
        
        // West Rows
        .row_on_detect_top(row_on_detect_top),             .row_off_detect_top(row_off_detect_top),
        .row_on_detect_bot(row_on_detect_bot),             .row_off_detect_bot(row_off_detect_bot),
        
        // Globals 
        .pre_charge_global_top_left(pre_charge_global_top[0]),     .pre_charge_global_top_right(pre_charge_global_top[1]),
        .detect_pulse_global_top_left(detect_pulse_global_top[0]), .detect_pulse_global_top_right(detect_pulse_global_top[1]),
        .pre_charge_global_bot_left(pre_charge_global_bot[0]),     .pre_charge_global_bot_right(pre_charge_global_bot[1]),
        .detect_pulse_global_bot_left(detect_pulse_global_bot[0]), .detect_pulse_global_bot_right(detect_pulse_global_bot[1]),
        
        // East DACs
        .dac_config_0(dac_config_0), .dac_config_1(dac_config_1),
        .dac_config_2(dac_config_2), .dac_config_3(dac_config_3),
        .dac_config_4(dac_config_4), .dac_config_5(dac_config_5),
        .dac_config_6(dac_config_6), .dac_config_7(dac_config_7),
        .dac_config_8(dac_config_8), .dac_config_9(dac_config_9),

        // Synchronized reset from the digital blocks
        .pix_rst_global_top_left  (sync_pix_rst_top_left),
        .pix_rst_global_bot_left  (sync_pix_rst_bot_left),
        .pix_rst_global_top_right (sync_pix_rst_top_right),
        .pix_rst_global_bot_right (sync_pix_rst_bot_right)
    );

endmodule