//---------------------------------------------------------------------------
// Author: Ababakar Okieh
// Date  : April 14, 2026
//
// Module: row_decoder_macro_tb
// Description: 
//  Self-checking testbench for the Central Spine Row Decoder Macro.
//  Verifies exact nanosecond phase timings across multiple speeds, 
//  spatial token ring shifting, and 2-bit split-bus integrity for all 64 rows.
//---------------------------------------------------------------------------

`timescale 1ns/1ps

module row_decoder_macro_tb();

    parameter SYS_CLK_PERIOD_NS = 20; // 50MHz

    // -----------------------------------------------------------
    // System Signals
    // -----------------------------------------------------------
    logic        sys_clk = 0;
    logic        rst_n = 0;
    logic        sm_enable = 0;
    logic [7:0]  program_bits = 8'd1; 

    // -----------------------------------------------------------
    // DUT Outputs
    // -----------------------------------------------------------
    logic [1:0]  pre_charge_global;
    logic [63:0] row_on_detect;
    logic [63:0] row_off_detect;

    logic        sm_on_detect;
    logic        sm_off_detect;
    logic [1:0]  sm_detect_pulse;
    logic        sm_pixel_rst;
    logic        sm_next_row;

    logic [5:0]  row_addr;
    logic        fifo_wr_en;
    logic [1:0]  event_mode;

    // -----------------------------------------------------------
    // DUT Instantiation
    // -----------------------------------------------------------
    row_decoder_macro i_dut (
        .sys_clk           (sys_clk),
        .rst_n             (rst_n),
        .sm_enable         (sm_enable),
        .program_bits      (program_bits),
        
        .pre_charge_global (pre_charge_global),
        .row_on_detect     (row_on_detect),
        .row_off_detect    (row_off_detect),
        
        .sm_on_detect      (sm_on_detect),
        .sm_off_detect     (sm_off_detect),
        .sm_detect_pulse   (sm_detect_pulse),
        .sm_pixel_rst      (sm_pixel_rst),
        .sm_next_row       (sm_next_row),
        
        .row_addr          (row_addr),
        .fifo_wr_en        (fifo_wr_en),
        .event_mode        (event_mode)
    );

    // 50MHz Clock Generation
    always #(SYS_CLK_PERIOD_NS / 2) sys_clk = ~sys_clk;

    time start_time;

    // -----------------------------------------------------------
    // Main Test Sequence
    // -----------------------------------------------------------
    initial begin
        $display("==================================================");
        $display("Starting Central Spine Row Decoder Macro TB...");
        $display("Testing Temporal Timings & Spatial Row Scanning (All 64 Rows)");
        $display("==================================================");

        // Test the fastest limit and a standard extended integration
        test_speed("Fast Mode   (1us)", 1, 8'd1);
        test_speed("Medium Mode (32us)", 32, 8'd32);
        test_speed("Slow Mode   (256us)", 256, 8'd0);

        $display("\n==================================================");
        $display("ALL TEMPORAL TIMINGS AND SPATIAL SHIFTS PASSED!");
        $display("==================================================");
        $finish;
    end

    // -----------------------------------------------------------------
    // Master Task: Executes a 64-Row speed test and verifies dynamic timing
    // -----------------------------------------------------------------
    task automatic test_speed(input string name, input int target_us, input logic [7:0] p_bits);
        time target_ns = target_us * 1000; 

        $display("\n--------------------------------------------------");
        $display(" RUNNING TEST: %s (%0d us period) - FULL 64-ROW SWEEP", name, target_us);
        $display("--------------------------------------------------");

        // Hard Reset
        rst_n = 0;
        sm_enable = 0;
        program_bits = p_bits;
        #(SYS_CLK_PERIOD_NS * 10);
        rst_n = 1;
        sm_enable = 1;
        @(posedge sys_clk);
        
        start_time = $time;

        // Loop through the entire 64-row quadrant
        for (int r = 0; r < 64; r++) begin
            
            // Print a header for the first row, last row, and every 16th row to keep logs clean
            if (r % 16 == 0 || r == 63) begin
                $display("\n--- Sweeping Row %0d ---", r);
            end

            // 1. ON_DETECT Phase -> expected at target_ns * (r*3 + 1)
            @(posedge sm_on_detect);  
            verify_timing("sm_on_detect", target_ns * (r * 3 + 1), r);
            #1; // Wait 1ns for combinational AND gates to settle
            verify_spatial_row(r, row_on_detect, "row_on_detect");
            verify_split_buses();

            // 2. OFF_DETECT Phase -> expected at target_ns * (r*3 + 2)
            @(posedge sm_off_detect); 
            verify_timing("sm_off_detect", target_ns * (r * 3 + 2), r);
            #1; // Wait 1ns
            verify_spatial_row(r, row_off_detect, "row_off_detect");

            // 3. PIXEL_RST Phase -> expected at target_ns * (r*3 + 3)
            @(posedge sm_pixel_rst);
            verify_timing("sm_pixel_rst", target_ns * (r * 3 + 3), r);
        end

        // Clean Shutdown
        @(posedge sys_clk);
        sm_enable = 0;
        #(SYS_CLK_PERIOD_NS * 10);
        
        $display("\n  [SUCCESS] Full 64-row sweep completed perfectly for %s.", name);
    endtask

    // -----------------------------------------------------------------
    // Helper Task: Temporal Stopwatch Verifier
    // -----------------------------------------------------------------
    task automatic verify_timing(input string phase, input time expected_delta, input int row_num);
        time current_time;
        time actual_delta;
        
        current_time = $time;
        actual_delta = current_time - start_time;

        if (actual_delta !== expected_delta) begin
            $display("[FATAL ERROR] %s timing drifted at Row %0d!", phase, row_num);
            $display("  Expected Start: +%0t ns", expected_delta);
            $display("  Actual Start  : +%0t ns", actual_delta);
            $stop;
        end else begin
            // Only print PASS messages for the rows we put headers on, to keep logs readable
            if (row_num % 16 == 0 || row_num == 63) begin
                $display("  -> [PASS] Row %0d %s started at EXACTLY +%0t ns.", row_num, phase, actual_delta);
            end
        end
    endtask

    // -----------------------------------------------------------------
    // Helper Task: Spatial Token Ring Verifier
    // -----------------------------------------------------------------
    task automatic verify_spatial_row(input int expected_row, input logic [63:0] active_bus, input string bus_name);
        logic [63:0] expected_vector;
        expected_vector = 64'd1 << expected_row;

        if (active_bus !== expected_vector) begin
            $display("[FATAL ERROR] Spatial mapping failed on %s!", bus_name);
            $display("  Expected Row %0d Active: %h", expected_row, expected_vector);
            $display("  Actual Bus Output      : %h", active_bus);
            $stop;
        end else begin
            // Only print PASS messages for the rows we put headers on
            if (expected_row % 16 == 0 || expected_row == 63) begin
                $display("  -> [PASS] %s successfully driving physical Row %0d.", bus_name, expected_row);
            end
        end
    endtask

    // -----------------------------------------------------------------
    // Helper Task: 2-Bit Split Bus Integrity Checker
    // -----------------------------------------------------------------
    task automatic verify_split_buses();
        // pre_charge_global is active LOW. At the moment ON_DETECT goes high, 
        // pre-charge should be inactive (2'b11).
        if (pre_charge_global !== 2'b11) begin
            $display("[FATAL ERROR] pre_charge_global 2-bit bus mismatch or wrong state! Val: %b", pre_charge_global);
            $stop;
        end
        
        // Wait for mid-read detect pulse
        @(posedge sm_detect_pulse[0]);
        if (sm_detect_pulse !== 2'b11) begin
            $display("[FATAL ERROR] sm_detect_pulse 2-bit bus mismatch! Val: %b", sm_detect_pulse);
            $stop;
        end
    endtask

endmodule : row_decoder_macro_tb