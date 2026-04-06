//---------------------------------------------------------------------------
// Author: Ababakar Okieh
// Date  : March 30th, 2026
//
// Module: roic_sm_tb
//
// Description: 
//  Testing the state control of the ROIC across various speeds.
//---------------------------------------------------------------------------

`timescale 1ns/1ps

module roic_sm_tb();

    parameter SYS_CLK_PERIOD_NS = 20; // 50MHz

    // DUT Signals
    logic       sys_clk = 0;
    logic       rst_n = 0;
    logic       sm_enable = 0;
    logic [7:0] program_bits = 8'd1; 
    
    logic       pre_charge_global;
    logic       on_detect;
    logic       off_detect;
    logic       detect_pulse; // [ADDED]
    logic       pixel_rst;
    logic       sm_next_row;
    logic [5:0] row_addr;
    logic       fifo_wr_en;
    logic [1:0] event_flag;

    // DUT Instantiation
    roic_sm i_roic_sm (
        .sys_clk           (sys_clk),
        .rst_n             (rst_n),
        .sm_enable         (sm_enable),
        .program_bits      (program_bits),
        .pre_charge_global (pre_charge_global),
        .on_detect         (on_detect),
        .off_detect        (off_detect),
        .detect_pulse      (detect_pulse), // [ADDED]
        .pixel_rst         (pixel_rst),
        .sm_next_row       (sm_next_row),
        .row_addr          (row_addr),
        .fifo_wr_en        (fifo_wr_en),
        .event_flag        (event_flag)
    );

    // 50MHz Clock Generation
    always #(SYS_CLK_PERIOD_NS / 2) sys_clk = ~sys_clk;

    time start_time;

    // Main Test Sequence
    initial begin
        $display("==================================================");
        $display("Starting Multi-Speed Paced Micro-Sequencer TB...");
        $display("Testing Speeds: 1us, 32us, and 256us");
        $display("==================================================");

        test_speed("Fast Mode", 1, 8'd1);
        // test_speed("2 us Mode", 2, 8'd2);
        // test_speed("4 us Mode", 4, 8'd4);
        // test_speed("8 us Mode", 8, 8'd8);
        // test_speed("16 us Mode", 16, 8'd16);
        test_speed("Medium Mode", 32, 8'd32);
        // test_speed("64us Mode", 64, 8'd64);
        // test_speed("128us Moode", 128, 8'd128);
        test_speed("Slow Mode (Max Integration)", 256, 8'd0);

        $display("\n==================================================");
        $display("ALL SPEEDS AND EXACT NANOSECOND TIMINGS PASSED!");
        $display("==================================================");
        $finish;
    end

    // -----------------------------------------------------------------
    // Master Task: Executes a speed test and verifies dynamic timing
    // -----------------------------------------------------------------
    task automatic test_speed(input string name, input int target_us, input logic [7:0] p_bits);
        time target_ns = target_us * 1000; 

        $display("\n--------------------------------------------------");
        $display(" RUNNING TEST: %s (%0d us period)", name, target_us);
        $display("--------------------------------------------------");

        rst_n = 0;
        sm_enable = 0;
        program_bits = p_bits;
        #(SYS_CLK_PERIOD_NS * 10);
        rst_n = 1;
        
        @(posedge sys_clk);
        sm_enable = 1;
        start_time = $time;
        
        $display("--- Tracking Row 0 ---");
        @(posedge on_detect);  verify_timing("ON_DETECT",  target_ns * 1);
        @(posedge off_detect); verify_timing("OFF_DETECT", target_ns * 2);
        @(posedge pixel_rst);  verify_timing("PIXEL_RST",  target_ns * 3);

        $display("\n--- Tracking Row 1 (Pipeline Loopback) ---");
        @(posedge on_detect);  verify_timing("ON_DETECT",  target_ns * 4);
        @(posedge off_detect); verify_timing("OFF_DETECT", target_ns * 5);
        @(posedge pixel_rst);  verify_timing("PIXEL_RST",  target_ns * 6);

        @(posedge sys_clk);
        sm_enable = 0;
        #(SYS_CLK_PERIOD_NS * 10);
    endtask

    // -----------------------------------------------------------------
    // Helper Task: Stopwatch Verifier
    // -----------------------------------------------------------------
    task automatic verify_timing(input string phase, input time expected_delta);
        time current_time;
        time actual_delta;
        
        current_time = $time;
        actual_delta = current_time - start_time;

        if (actual_delta !== expected_delta) begin
            $display("[FATAL ERROR] %s timing drifted!", phase);
            $display("  Expected Start: +%0t ns", expected_delta);
            $display("  Actual Start  : +%0t ns", actual_delta);
            $stop;
        end else begin
            $display("  -> [PASS] %s started at EXACTLY +%0t ns.", phase, actual_delta);
        end
    endtask

endmodule : roic_sm_tb