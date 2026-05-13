//---------------------------------------------------------------------------
// Module: roic_top_tb_2x2
// Description: 
//  Self-checking system testbench for the 2x2 Phase-Gated ROIC Top Level.
//  Sweeps the 2-row frame and captures outputs to a file.
//---------------------------------------------------------------------------

`timescale 1ns/1ps

module roic_top_tb_2x2();

    parameter SYS_CLK_PERIOD_NS = 20; // 50MHz Master Clock

    // Inputs
    logic        sys_clk = 0;
    logic        rst_n = 0;
    logic        sm_enable = 0;
    logic [7:0]  program_bits = 0;
    logic [1:0]  array_col_out = 0; // [UPDATED] 2-bit Column

    logic [13:0] p_pre_charge = 14'd4;      // set to 14'd4
    logic [13:0] p_buffer =     14'd4;      // set to 14'd4
    logic [13:0] p_detect =     14'd4;      // set to 14'd4
    logic [13:0] p_on_detect =  14'd8;      // set to 14'd8
    logic [13:0] p_off_detect = 14'd8;      // set to 14'd8
    logic [13:0] p_rst =        14'd25;     // set to 14'd25

    // Outputs
    logic        pre_charge_global;
    logic [1:0]  row_on_detect;     // [UPDATED] 2-bit Row Lines
    logic [1:0]  row_off_detect;    // [UPDATED] 2-bit Row Lines
    logic [1:0]  col_pixel_rst;     // [UPDATED] 2-bit Column Reset
    logic        row_addr;          // [UPDATED] 1-bit Row Address
    logic        fifo_wr_en;
    logic [1:0]  event_flag;
    logic        detect, ndetect;

    // --- File I/O & Memory ---
    // Holds the 4 phases of test data (2 rows * 2 phases = 4 entries)
    logic [1:0]  img_mem [0:3];     // [UPDATED] 2-bit wide entries
    integer      fd;                // File descriptor for output log

    // DUT Instantiation
    roic_top0 i_dut (
        // System
        .sys_clk           (sys_clk),
        .rst_n             (rst_n),
        .sm_enable         (sm_enable),
        .program_bits      (program_bits),
        .array_col_out     (array_col_out),
        
        // Analog Control
        .pre_charge_global (pre_charge_global),
        .row_on_detect     (row_on_detect),
        .row_off_detect    (row_off_detect),
        .col_pixel_rst     (col_pixel_rst),
        .detect            (detect),
        .ndetect           (ndetect),
        
        // Backend
        .row_addr          (row_addr),
        .fifo_wr_en        (fifo_wr_en),
        .event_flag        (event_flag),

        // Programmable timings
        .p_pre_charge(p_pre_charge),
        .p_buffer(p_buffer),
        .p_detect(p_detect),
        .p_on_detect(p_on_detect),
        .p_off_detect(p_off_detect),
        .p_rst(p_rst)
    );
    

    // 50MHz Clock Generation
    always #(SYS_CLK_PERIOD_NS / 2) sys_clk = ~sys_clk;

    // -----------------------------------------------------------------
    // Backend FIFO Monitor (Logs to File on Write Enable)
    // -----------------------------------------------------------------
    always @(posedge sys_clk) begin
        if (rst_n && fifo_wr_en) begin
            // 2-bit event_flag + 2-bit array_col_out = 4 bits
            // Outputting in binary for easy reading of small widths
            $fdisplay(fd, "%04b", {event_flag, array_col_out});
        end
    end

    initial begin
        $display("==================================================");
        $display("Starting Intent-Based 2x2 ROIC System TB");
        $display("Testing Timing Deltas, Latching, and State Flow");
        $display("==================================================");

        // Manually load hardcoded test data for the 2x2 array
        // Pattern: Row 0 gets an ON event. Row 1 gets an OFF event.
        img_mem[0] = 2'b11; // Row 0 ON     (both evts)
        img_mem[1] = 2'b00; // Row 0 OFF    (both evts)
        img_mem[2] = 2'b00; // Row 1 ON     (no evts)
        img_mem[3] = 2'b11; // Row 1 OFF    (no evts)

        // Open file to log the backend captures
        fd = $fopen("/LinuxRAID/home/aokieh1/projects/open_dvs_digital/fver/roic/python/sim_output_2x2.txt", "w");
        if (fd == 0) begin
            $display("[FATAL ERROR] Could not open sim_output_2x2.txt for writing!");
            $stop;
        end

        // --- TEST 1: Fastest Clock (1us) ---
        test_speed("Fast Mode (1us)", 8'd1);

        // --- TEST 2: Medium Clock (32us) ---
        test_speed("Extended Mode (32us)", 8'd32);

        // --- TEST 3: Slow Clock (256us) ---
        test_speed("Extended Mode (256us)", 8'd0);

        $display("\n==================================================");
        $display("ALL SPEEDS, DATAPATHS, AND TIMING DELTAS PASSED!");
        $display("Simulation Complete. Output written to sim_output_2x2.txt");
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
    // Master Task: Executes a full reset and intent-based 2-row sweep
    // -----------------------------------------------------------------
    task automatic test_speed(input string name, input logic [7:0] p_bits);
        
        // Time unit is 1ns. Treat all longints directly as nanoseconds.
        longint target_us = (p_bits == 0) ? 256 : p_bits;
        longint target_delta_ns = target_us * 1000; 
        longint tolerance_ns = 3; // +/- 3ns allowed deviation
        
        longint ref_time; 
        longint event_time;
        longint actual_delta;

        logic [1:0] test_on_data;  // [UPDATED] 2-bit
        logic [1:0] test_off_data; // [UPDATED] 2-bit
        logic expected_addr;       // [UPDATED] 1-bit

        $display("\n--------------------------------------------------");
        $display(" RUNNING TEST: %s (program_bits = %0d)", name, p_bits);
        $display(" Target Delta: %0d ns (+/- %0d ns)", target_delta_ns, tolerance_ns);
        $display("--------------------------------------------------");

        // Hard Reset & Setup
        rst_n = 0;
        sm_enable = 0;
        program_bits = p_bits;
        array_col_out = 2'b0;
        #(SYS_CLK_PERIOD_NS * 10);
        rst_n = 1;
        
        @(negedge sys_clk);
        sm_enable = 1;
        
        // Mark the moment the FSM acknowledges the enable
        @(posedge sys_clk);
        ref_time = $time; 
        $display(" -> FSM Enabled at %0d ns", ref_time);

        // Sweep both rows [UPDATED loop limit]
        for (int r = 0; r < 2; r++) begin
            bit verbose = 1; // Always print for just 2 rows
            if (verbose) $display("\n  --- Sweeping Row %0d ---", r);

            // Fetch the image data from memory
            test_on_data  = img_mem[r * 2];
            test_off_data = img_mem[(r * 2) + 1];

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
            
            array_col_out = test_on_data; 

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
            
            // Apply the ~ operator to test_off_data to match the RTL inversion
            if (col_pixel_rst !== (test_on_data | ~test_off_data)) begin
                $display("[FATAL ERROR] Data Mismatch at Row %0d!", r);
                $display("  Expected (ON | ~OFF): %b", (test_on_data | ~test_off_data));
                $display("  Actual col_pixel_rst: %b", col_pixel_rst);
                $stop;
            end
            if (verbose) $display("  -> [PASS] Data correctly bitwise OR'd and latched.");

            // -------------------------------------------------------------
            // 5. Verify Address Increment on sm_next_row falling edge
            // -------------------------------------------------------------
            @(negedge i_dut.i_roic_sm.sm_next_row);
            
            #(1); // Micro-delay
            
            // [UPDATED] 1-bit rollover logic
            expected_addr = (r == 1) ? 1'b0 : 1'b1;
            
            if (row_addr !== expected_addr) begin
                $display("[FATAL ERROR] Address increment failed after Row %0d!", r);
                $display("  Expected Addr: %b | Actual Addr: %b", expected_addr, row_addr);
                $stop;
            end
            if (verbose) $display("  -> [PASS] Address incremented to %b on sm_next_row drop.", expected_addr);
            
        end

        // Clean shutdown
        @(negedge sys_clk);
        sm_enable = 0;
        $display("  [SUCCESS] %s intent-based timing and data flow perfect.", name);
    endtask

endmodule : roic_top_tb_2x2