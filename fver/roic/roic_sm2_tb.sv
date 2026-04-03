`timescale 1ns/1ps

module roic_sm2_tb();

    parameter SYS_CLK_PERIOD_NS = 20; // 50MHz

    // DUT Signals
    logic       sys_clk = 0;
    logic       rst_n = 0;
    logic       sm_enable = 0;
    logic [7:0] program_bits = 8'd1; 
    
    logic       pre_charge_global;
    logic       on_detect;
    logic       off_detect;
    logic       pixel_rst;
    logic       sm_next_row;
    logic [5:0] row_addr;
    logic       fifo_wr_en;
    logic [1:0] event_flag;

    // DUT Instantiation
    roic_sm2 i_roic_sm2 (
        .sys_clk           (sys_clk),
        .rst_n             (rst_n),
        .sm_enable         (sm_enable),
        .program_bits      (program_bits),
        .pre_charge_global (pre_charge_global),
        .on_detect         (on_detect),
        .off_detect        (off_detect),
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

        // --- TEST 1: Fastest Clock (1us) ---
        test_speed("Fast Mode", 1, 8'd1);

        // --- TEST 2: Medium Clock (32us) ---
        test_speed("Medium Mode", 32, 8'd32);

        // --- TEST 3: Slowest Clock (256us) ---
        // 8'd0 triggers the 256us wrap-around in the FSM math
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
        time target_ns = target_us * 1000; // Convert target us to ns

        $display("\n--------------------------------------------------");
        $display(" RUNNING TEST: %s (%0d us period)", name, target_us);
        $display("--------------------------------------------------");

        // 1. Hard Reset & Setup
        rst_n = 0;
        sm_enable = 0;
        program_bits = p_bits;
        #(SYS_CLK_PERIOD_NS * 10);
        rst_n = 1;
        
        // Wait for a clean clock edge to start the stopwatch
        @(posedge sys_clk);
        sm_enable = 1;
        start_time = $time;
        
        // --- ROW 0 TIMING CHECKS ---
        $display("--- Tracking Row 0 ---");
        @(posedge on_detect);  verify_timing("ON_DETECT",  target_ns * 1);
        @(posedge off_detect); verify_timing("OFF_DETECT", target_ns * 2);
        @(posedge pixel_rst);  verify_timing("PIXEL_RST",  target_ns * 3);

        // --- ROW 1 TIMING CHECKS (Pipeline Loopback) ---
        $display("\n--- Tracking Row 1 (Pipeline Loopback) ---");
        @(posedge on_detect);  verify_timing("ON_DETECT",  target_ns * 4);
        @(posedge off_detect); verify_timing("OFF_DETECT", target_ns * 5);
        @(posedge pixel_rst);  verify_timing("PIXEL_RST",  target_ns * 6);

        // Disable to safely end the test block
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

endmodule : roic_sm2_tb