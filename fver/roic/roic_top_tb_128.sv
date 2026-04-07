//---------------------------------------------------------------------------
// Module: roic_top_tb_128
// Description: 
//  Self-checking system testbench for the Phase-Gated ROIC Top Level.
//  Simulates a 128x128 sensor by sweeping the 64-row FSM twice continuously.
//---------------------------------------------------------------------------

`timescale 1ns/1ps

`define IMAGER_COL_WIDTH 128

module roic_top_tb_128();

    parameter SYS_CLK_PERIOD_NS = 20; // 50MHz Master Clock

    // Inputs
    logic        sys_clk = 0;
    logic        rst_n = 0;
    logic        sm_enable = 0;
    logic [7:0]  program_bits = 0;
    logic [`IMAGER_COL_WIDTH-1:0] array_col_out = 0;

    // Outputs
    logic        pre_charge_global;
    logic [63:0] row_on_detect;
    logic [63:0] row_off_detect;
    logic [`IMAGER_COL_WIDTH-1:0] col_pixel_rst;
    logic [5:0]  row_addr;
    logic        fifo_wr_en;
    logic [1:0]  event_flag;

    // --- File I/O & Memory ---
    // Holds 256 rows (128 ON + 128 OFF) of 136-bit Python generated Hex
    logic [135:0] img_mem [0:255]; 
    integer       fd;              
    
    // Tracks the 128-row spatial mapping for the output file
    logic [6:0]   sim_global_row = 0; 

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

    // -----------------------------------------------------------------
    // Backend FIFO Monitor (Logs to File on Write Enable)
    // -----------------------------------------------------------------
    always @(posedge sys_clk) begin
        if (rst_n && fifo_wr_en) begin
            // 128-bit data + 2-bit flag + 7-bit global addr = 137 bits.
            // Ceil(137/4) = 35 hex characters.
            $fdisplay(fd, "%035x", {array_col_out, event_flag, sim_global_row});
        end
    end

    initial begin
        $display("==================================================");
        $display("Starting Intent-Based FULL ROIC System TB");
        $display("Testing Timing Deltas, Latching, and State Flow (128x128 Tiled)");
        $display("==================================================");

        // Load input image data
        $readmemh("/LinuxRAID/home/aokieh1/projects/open_dvs_digital/fver/roic/python/papa_test_data_128x128.hex", img_mem);
        
        // Defensive check to ensure the file actually loaded
        if (img_mem[0] === 136'hx) begin
            $display("[FATAL ERROR] Failed to load papa_test_data_128x128.hex!");
            $stop;
        end

        // Open file to log the backend captures
        fd = $fopen("/LinuxRAID/home/aokieh1/projects/open_dvs_digital/fver/roic/python/sim_output_128x128.txt", "w");
        if (fd == 0) begin
            $display("[FATAL ERROR] Could not open sim_output_128x128.txt for writing!");
            $stop;
        end

        // --- TEST 1: Fastest Clock (1us) ---
        test_speed("Fast Mode (1us)", 8'd1);

        // --- TEST 2: Medium Clock (32us) ---
        test_speed("Extended Mode (32us)", 8'd32);

        $display("\n==================================================");
        $display("ALL SPEEDS, DATAPATHS, AND TIMING DELTAS PASSED!");
        $display("Simulation Complete. Output written to sim_output.txt");
        $display("==================================================");
        
        $fclose(fd);
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
    // Master Task: Executes a full reset and intent-based 128-row sweep
    // -----------------------------------------------------------------
    task automatic test_speed(input string name, input logic [7:0] p_bits);
        
        longint target_us = (p_bits == 0) ? 256 : p_bits;
        longint target_delta_ns = target_us * 1000; 
        longint tolerance_ns = 3; 
        
        longint ref_time, event_time, actual_delta;

        logic [127:0] test_on_data;
        logic [127:0] test_off_data;
        logic [5:0]   expected_addr;

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
        
        @(posedge sys_clk);
        ref_time = $time; 

        // Sweep 128 rows (Tile 1: 0-63, Tile 2: 64-127)
        for (int r = 0; r < 128; r++) begin
            bit verbose = (r == 0 || r == 63 || r == 64 || r == 127);
            if (verbose) $display("\n  --- Sweeping Global Row %0d (Tile %0d, Local Row %0d) ---", r, r/64, r%64);

            // Set the global row tracker for the backend logger (0 to 127)
            sim_global_row = r[6:0]; 

            // Fetch the 136-bit packet and extract only the 128-bit payload
            test_on_data  = img_mem[r * 2][135:8];
            test_off_data = img_mem[(r * 2) + 1][135:8];

            // 1. Wait for ON_DETECT 
            @(posedge i_dut.i_roic_sm.on_detect);
            event_time = $time;
            actual_delta = event_time - ref_time;
            
            if (!is_within_tolerance(actual_delta, target_delta_ns, tolerance_ns)) begin
                $display("[FATAL ERROR] ON_DETECT delta violation at Row %0d!", r);
                $stop;
            end
            
            ref_time = event_time; 
            array_col_out = test_on_data; 

            // 2. Wait for OFF_DETECT
            @(posedge i_dut.i_roic_sm.off_detect);
            event_time = $time;
            actual_delta = event_time - ref_time;

            if (!is_within_tolerance(actual_delta, target_delta_ns, tolerance_ns)) begin
                $display("[FATAL ERROR] OFF_DETECT delta violation at Row %0d!", r);
                $stop;
            end
            
            ref_time = event_time; 
            array_col_out = test_off_data; 

            // 3. Wait for PIXEL_RST
            @(posedge i_dut.i_roic_sm.pixel_rst);
            event_time = $time;
            actual_delta = event_time - ref_time;

            if (!is_within_tolerance(actual_delta, target_delta_ns, tolerance_ns)) begin
                $display("[FATAL ERROR] PIXEL_RST delta violation at Row %0d!", r);
                $stop;
            end
            
            ref_time = event_time; 

            // 4. Verify Column Pixel Reset Output (Data Integrity)
            #(SYS_CLK_PERIOD_NS * 1.5); 
            if (col_pixel_rst !== (test_on_data | test_off_data)) begin
                $display("[FATAL ERROR] Data Mismatch at Row %0d!", r);
                $stop;
            end

            array_col_out = '0;

            // 5. Verify Address Increment (Modulo 64 for local HW address)
            @(negedge i_dut.i_roic_sm.sm_next_row);
            #(1); 
            
            expected_addr = (r % 64 == 63) ? 0 : (r % 64) + 1;
            if (row_addr !== expected_addr) begin
                $display("[FATAL ERROR] Address increment failed after Global Row %0d!", r);
                $display("  Expected HW Addr: %0d | Actual HW Addr: %0d", expected_addr, row_addr);
                $stop;
            end
            
        end

        // Clean shutdown
        @(negedge sys_clk);
        sm_enable = 0;
        $display("  [SUCCESS] %s intent-based timing and 128-row tiled data flow perfect.", name);
    endtask

endmodule : roic_top_tb_128