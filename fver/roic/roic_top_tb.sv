//---------------------------------------------------------------------------
// Module: roic_top_tb
// Description: 
//  Self-checking system testbench for the Phase-Gated ROIC Top Level.
//  Sweeps full 64-row frames across 1us, 32us, and 256us speeds.
//---------------------------------------------------------------------------

`timescale 1ns/1ps

module roic_top_tb();

    parameter SYS_CLK_PERIOD_NS = 20; // 50MHz Master Clock

    // Inputs
    logic        sys_clk = 0;
    logic        rst_n = 0;
    logic        sm_enable = 0;
    logic [7:0]  program_bits = 0;
    logic [63:0] array_col_out = 0;

    // Outputs
    logic        pre_charge_global;
    logic [63:0] row_on_detect;
    logic [63:0] row_off_detect;
    logic [63:0] col_pixel_rst;
    logic [5:0]  row_addr;
    logic        fifo_wr_en;
    logic [1:0]  event_flag;

    // DUT Instantiation
    roic_top i_dut (
        .sys_clk           (sys_clk),
        .rst_n             (rst_n),
        .sm_enable         (sm_enable),
        .program_bits      (program_bits),
        .array_col_out     (array_col_out),
        
        .pre_charge_global (pre_charge_global),
        .row_on_detect     (row_on_detect),
        .row_off_detect    (row_off_detect),
        
        .col_pixel_rst     (col_pixel_rst),
        .row_addr          (row_addr),
        .fifo_wr_en        (fifo_wr_en),
        .event_flag        (event_flag)
    );

    // 50MHz Clock Generation
    always #(SYS_CLK_PERIOD_NS / 2) sys_clk = ~sys_clk;

    initial begin
        $display("==================================================");
        $display("Starting Intent-Based FULL ROIC System TB");
        $display("Testing Timing Deltas, Latching, and State Flow");
        $display("==================================================");

        // --- TEST 1: Fastest Clock (1us) ---
        test_speed("Fast Mode (1us)", 8'd1);

        // --- TEST 2: Medium Clock (32us) ---
        test_speed("Extended Mode (32us)", 8'd32);

        // --- TEST 2: Medium Clock (256us) ---
        test_speed("Extended Mode (256us)", 8'd0);

        $display("\n==================================================");
        $display("ALL SPEEDS, DATAPATHS, AND TIMING DELTAS PASSED!");
        $display("Simulation Complete.");
        $display("==================================================");
        
        $finish;
    end

    // -----------------------------------------------------------------
    // Helper Function: Absolute Value Tolerance Check (Raw Integers)
    // -----------------------------------------------------------------
    function automatic bit is_within_tolerance(longint actual_delta, longint expected_delta, longint tol);
        longint diff = (actual_delta > expected_delta) ? (actual_delta - expected_delta) : (expected_delta - actual_delta);
        return (diff <= tol);
    endfunction

    // -----------------------------------------------------------------
    // Master Task: Executes a full reset and intent-based 64-row sweep
    // -----------------------------------------------------------------
    task automatic test_speed(input string name, input logic [7:0] p_bits);
        
        // Time unit is 1ns. Treat all longints directly as nanoseconds.
        longint target_us = (p_bits == 0) ? 256 : p_bits;
        longint target_delta_ns = target_us * 1000; 
        longint tolerance_ns = 3; // +/- 3ns allowed deviation
        
        longint ref_time; 
        longint event_time;
        longint actual_delta;

        logic [63:0] test_on_data;
        logic [63:0] test_off_data;
        logic [5:0]  expected_addr;

        $display("\n--------------------------------------------------");
        $display(" RUNNING TEST: %s (program_bits = %0d)", name, p_bits);
        $display(" Target Delta: %0d ns (+/- %0d ns)", target_delta_ns, tolerance_ns);
        $display("--------------------------------------------------");

        // Hard Reset & Setup
        rst_n = 0;
        sm_enable = 0;
        program_bits = p_bits;
        array_col_out = '0;
        #(SYS_CLK_PERIOD_NS * 10);
        rst_n = 1;
        
        @(negedge sys_clk);
        sm_enable = 1;
        
        // Mark the moment the FSM acknowledges the enable
        @(posedge sys_clk);
        ref_time = $time; 
        $display(" -> FSM Enabled at %0d ns", ref_time);

        // Sweep all 64 rows using intent-based tracking
        for (int r = 0; r < 64; r++) begin
            bit verbose = (r == 0 || r == 31 || r == 63);
            if (verbose) $display("\n  --- Sweeping Row %0d ---", r);

            // Generate pseudo-random test data for this row
            test_on_data  = {32'hAAAA_0000, 32'hBBBB_1111} ^ r;
            test_off_data = {32'h5555_2222, 32'h4444_3333} ^ r;

            // -------------------------------------------------------------
            // 1. Wait for ON_DETECT 
            // -------------------------------------------------------------
            @(posedge i_dut.i_roic_sm.on_detect);
            event_time = $time;
            actual_delta = event_time - ref_time;
            
            if (!is_within_tolerance(actual_delta, target_delta_ns, tolerance_ns)) begin
                $display("[FATAL ERROR] ON_DETECT delta violation at Row %0d!", r);
                $display("  Expected: %0d ns | Actual: %0d ns", target_delta_ns, actual_delta);
                $stop;
            end
            if (verbose) $display("  -> [PASS] ON_DETECT delta: %0d ns", actual_delta);
            
            ref_time = event_time; // Update rolling reference
            array_col_out = test_on_data; // Feed analog bus

            // -------------------------------------------------------------
            // 2. Wait for OFF_DETECT
            // -------------------------------------------------------------
            @(posedge i_dut.i_roic_sm.off_detect);
            event_time = $time;
            actual_delta = event_time - ref_time;

            if (!is_within_tolerance(actual_delta, target_delta_ns, tolerance_ns)) begin
                $display("[FATAL ERROR] OFF_DETECT delta violation at Row %0d!", r);
                $display("  Expected: %0d ns | Actual: %0d ns", target_delta_ns, actual_delta);
                $stop;
            end
            if (verbose) $display("  -> [PASS] OFF_DETECT delta: %0d ns", actual_delta);
            
            ref_time = event_time; 
            array_col_out = test_off_data; 

            // -------------------------------------------------------------
            // 3. Wait for PIXEL_RST
            // -------------------------------------------------------------
            @(posedge i_dut.i_roic_sm.pixel_rst);
            event_time = $time;
            actual_delta = event_time - ref_time;

            if (!is_within_tolerance(actual_delta, target_delta_ns, tolerance_ns)) begin
                $display("[FATAL ERROR] PIXEL_RST delta violation at Row %0d!", r);
                $display("  Expected: %0d ns | Actual: %0d ns", target_delta_ns, actual_delta);
                $stop;
            end
            if (verbose) $display("  -> [PASS] PIXEL_RST delta: %0d ns", actual_delta);
            
            ref_time = event_time; 

            // -------------------------------------------------------------
            // 4. Verify Column Pixel Reset Output (Data Integrity)
            // -------------------------------------------------------------
            #(SYS_CLK_PERIOD_NS * 1.5); 
            
            if (col_pixel_rst !== (test_on_data | test_off_data)) begin
                $display("[FATAL ERROR] Data Mismatch at Row %0d!", r);
                $display("  Expected (ON | OFF): %h", (test_on_data | test_off_data));
                $display("  Actual col_pixel_rst: %h", col_pixel_rst);
                $stop;
            end
            if (verbose) $display("  -> [PASS] Data correctly bitwise OR'd and latched.");

            // Clear the bus to prevent false latches on next row
            array_col_out = '0;

            // -------------------------------------------------------------
            // 5. Verify Address Increment on sm_next_row falling edge
            // -------------------------------------------------------------
            @(negedge i_dut.i_roic_sm.sm_next_row);
            
            #(1); // Micro-delay to allow token shift propagation
            
            expected_addr = (r == 63) ? 0 : r + 1;
            if (row_addr !== expected_addr) begin
                $display("[FATAL ERROR] Address increment failed after Row %0d!", r);
                $display("  Expected Addr: %0d | Actual Addr: %0d", expected_addr, row_addr);
                $stop;
            end
            if (verbose) $display("  -> [PASS] Address incremented to %0d on sm_next_row drop.", expected_addr);
            
        end

        // Clean shutdown
        @(negedge sys_clk);
        sm_enable = 0;
        $display("  [SUCCESS] %s intent-based timing and data flow perfect.", name);
    endtask

endmodule : roic_top_tb