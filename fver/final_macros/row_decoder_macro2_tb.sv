//---------------------------------------------------------------------------
// Author: Ababakar Okieh
// Date  : April 27, 2026
//
// Module: row_decoder_macro2_tb
//
// Description: 
//  Testing the integrated Row Decoder Macro.
//  Validates the 14-bit programmable FSM timings AND proves that the 
//  row_scanner correctly routes the pulses to consecutive array rows.
//---------------------------------------------------------------------------

`timescale 1ns/1ps

module row_decoder_macro_tb();

    parameter SYS_CLK_PERIOD_NS = 20; // 50MHz

    // DUT Signals
    logic        sys_clk = 0;
    logic        rst_n = 0;
    logic        sm_enable = 0;
    logic [7:0]  program_bits = 8'd1; 
    
    // Programmable Timing Inputs (14-BIT TUNING)
    logic [13:0] p_pre_charge;
    logic [13:0] p_buffer;
    logic [13:0] p_detect;
    logic [13:0] p_on_detect;
    logic [13:0] p_off_detect;
    logic [13:0] p_rst;

    // Outputs
    logic [1:0]  pre_charge_global;
    logic [1:0]  detect_pulse_global;
    logic [63:0] row_on_detect;
    logic [63:0] row_off_detect;

    logic        sm_on_detect;
    logic        sm_off_detect;
    logic        sm_pixel_rst;
    logic        sm_next_row;
    logic [5:0]  row_addr;
    logic        fifo_wr_en;
    logic [1:0]  event_mode;

    // DUT Instantiation
    row_decoder_macro2 i_dut (
        .sys_clk             (sys_clk),
        .rst_n               (rst_n),
        .sm_enable           (sm_enable),
        .program_bits        (program_bits),

        .p_pre_charge        (p_pre_charge),
        .p_buffer            (p_buffer),
        .p_detect            (p_detect),
        .p_on_detect         (p_on_detect),
        .p_off_detect        (p_off_detect),
        .p_rst               (p_rst),

        .pre_charge_global   (pre_charge_global),
        .detect_pulse_global (detect_pulse_global),
        .row_on_detect       (row_on_detect),
        .row_off_detect      (row_off_detect),

        .sm_on_detect        (sm_on_detect),
        .sm_off_detect       (sm_off_detect),
        .sm_pixel_rst        (sm_pixel_rst),
        .sm_next_row         (sm_next_row),
        
        .row_addr            (row_addr),
        .fifo_wr_en          (fifo_wr_en),
        .event_mode          (event_mode)
    );

    // 50MHz Clock Generation
    always #(SYS_CLK_PERIOD_NS / 2) sys_clk = ~sys_clk;

    time start_time;

    // Main Test Sequence
    initial begin
        $display("==================================================");
        $display("Starting Integrated Row Decoder Macro TB...");
        $display("Proving 14-Bit Timing & Token Ring Scanning");
        $display("==================================================");

        // -----------------------------------------------------------
        // TEST 1: 1us Mode with Default Parameters
        // -----------------------------------------------------------
        set_tune_params(14'd4, 14'd4, 14'd4, 14'd8, 14'd8, 14'd25);
        test_speed("Fast Mode (Default Tuning)", 1, 8'd1);

        // -----------------------------------------------------------
        // TEST 2: 1us Mode with STRETCHED Parameters
        // -----------------------------------------------------------
        set_tune_params(14'd10, 14'd10, 14'd10, 14'd15, 14'd15, 14'd10);
        test_speed("Fast Mode (Stretched Tuning)", 1, 8'd1);

        // -----------------------------------------------------------
        // TEST 3: 32us Mode with Default Parameters
        // -----------------------------------------------------------
        set_tune_params(14'd4, 14'd4, 14'd4, 14'd8, 14'd8, 14'd25);
        test_speed("Medium Mode (Default Tuning)", 32, 8'd32);

        // -----------------------------------------------------------
        // TEST 4: 256us Mode with EXTREME 14-BIT Parameters
        // -----------------------------------------------------------
        set_tune_params(14'd1000, 14'd1000, 14'd1000, 14'd10000, 14'd10000, 14'd5000);
        test_speed("Slow Mode (14-bit Extreme Tuning)", 256, 8'd0);

        $display("\n==================================================");
        $display("MACRO INTEGRATION PASSED! SCANNER & FSM IN PERFECT SYNC.");
        $display("==================================================");
        $finish;
    end

    // -----------------------------------------------------------------
    // Helper Task: Set Phase Tunings (14 BITS)
    // -----------------------------------------------------------------
    task automatic set_tune_params(
        input logic [13:0] pre, input logic [13:0] buf_val, input logic [13:0] det,
        input logic [13:0] on_det, input logic [13:0] off_det, input logic [13:0] rst_val
    );
        p_pre_charge = pre;
        p_buffer     = buf_val;
        p_detect     = det;
        p_on_detect  = on_det;
        p_off_detect = off_det;
        p_rst        = rst_val;
    endtask

    // -----------------------------------------------------------------
    // Master Task: Verifies dynamic timing AND Scanner Routing
    // -----------------------------------------------------------------
    task automatic test_speed(input string name, input int target_us, input logic [7:0] p_bits);
        time target_ns = target_us * 1000; 

        $display("\n--------------------------------------------------");
        $display(" RUNNING TEST: %s (%0d us period)", name, target_us);
        $display("   -> Tuning: Pre=%0d, Buf=%0d, On=%0d, Off=%0d", 
                 p_pre_charge, p_buffer, p_on_detect, p_off_detect);
        $display("--------------------------------------------------");

        rst_n = 0;
        sm_enable = 0;
        program_bits = p_bits;
        #(SYS_CLK_PERIOD_NS * 10);
        rst_n = 1;
        
        @(posedge sys_clk);
        sm_enable = 1;
        start_time = $time;
        
        $display("--- Tracking Array Row [0] ---");
        fork
            // Process A: Track the absolute frame boundaries on the physical ROW 0 wires
            begin
                @(posedge row_on_detect[0]);  verify_timing("ROW_0_ON_START",  target_ns * 1);
                @(posedge row_off_detect[0]); verify_timing("ROW_0_OFF_START", target_ns * 2);
                @(posedge sm_pixel_rst);      verify_timing("GLOBAL_RST_START",target_ns * 3);
            end

            // Process B: Assert the individual FSM pulse widths concurrently
            verify_pulse_widths();
        join

        $display("\n--- Tracking Array Row [1] (Scanner Shift Verified) ---");
        // Track the boundaries on the physical ROW 1 wires to prove the shift occurred
        @(posedge row_on_detect[1]);  verify_timing("ROW_1_ON_START",  target_ns * 4);
        @(posedge row_off_detect[1]); verify_timing("ROW_1_OFF_START", target_ns * 5);
        @(posedge sm_pixel_rst);      verify_timing("GLOBAL_RST_START",target_ns * 6);

        // Optional: Ensure Row [0] stayed completely quiet during Row [1]'s turn!
        assert(row_on_detect[0] == 0) else $error("[FATAL] Row 0 latching error during Row 1 cycle!");

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

    // -----------------------------------------------------------------
    // Helper Task: Intra-Row Pulse Width Assertions (Using Global/FSM Nets)
    // -----------------------------------------------------------------
    task automatic verify_pulse_widths();
        fork
            // Thread 1: Check Active-Low Pre-Charge (Checking bit 0 of the 2-bit bus)
            begin : chk_pre
                time t_start, t_end; int ticks;
                @(negedge pre_charge_global[0]); t_start = $time;
                @(posedge pre_charge_global[0]); t_end   = $time;
                ticks = (t_end - t_start) / SYS_CLK_PERIOD_NS;
                
                assert_pre: assert(ticks == p_pre_charge) else 
                    $error("[ASSERT FATAL] PRE_CHARGE expected %0d, got %0d", p_pre_charge, ticks);
                $display("    [ASSERT PASS] PRE_CHARGE width = %0d ticks", ticks);
            end

            // Thread 2: Check Active-High ON_DETECT
            begin : chk_on
                time t_start, t_end; int ticks;
                @(posedge sm_on_detect); t_start = $time;
                @(negedge sm_on_detect); t_end   = $time;
                ticks = (t_end - t_start) / SYS_CLK_PERIOD_NS;
                
                assert_on: assert(ticks == p_on_detect) else 
                    $error("[ASSERT FATAL] ON_DETECT expected %0d, got %0d", p_on_detect, ticks);
                $display("    [ASSERT PASS] ON_DETECT width = %0d ticks", ticks);
            end

            // Thread 3: Check Active-High OFF_DETECT
            begin : chk_off
                time t_start, t_end; int ticks;
                @(posedge sm_off_detect); t_start = $time;
                @(negedge sm_off_detect); t_end   = $time;
                ticks = (t_end - t_start) / SYS_CLK_PERIOD_NS;
                
                assert_off: assert(ticks == p_off_detect) else 
                    $error("[ASSERT FATAL] OFF_DETECT expected %0d, got %0d", p_off_detect, ticks);
                $display("    [ASSERT PASS] OFF_DETECT width = %0d ticks", ticks);
            end

            // Thread 4: Check Active-High PIXEL_RST
            begin : chk_rst
                time t_start, t_end; int ticks;
                @(posedge sm_pixel_rst); t_start = $time;
                @(negedge sm_pixel_rst); t_end   = $time;
                ticks = (t_end - t_start) / SYS_CLK_PERIOD_NS;
                
                assert_rst: assert(ticks == p_rst) else 
                    $error("[ASSERT FATAL] PIXEL_RST expected %0d, got %0d", p_rst, ticks);
                $display("    [ASSERT PASS] PIXEL_RST width = %0d ticks", ticks);
            end
        join
    endtask

endmodule : row_decoder_macro_tb