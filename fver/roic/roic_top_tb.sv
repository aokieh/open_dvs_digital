//---------------------------------------------------------------------------
// Module: roic_digital_top_tb
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

    // Outputs
    logic        div_clk_out;
    logic [5:0]  row_addr;
    logic        pre_charge_global;
    logic [63:0] row_on_detect;
    logic [63:0] row_off_detect;
    logic [63:0] row_pixel_rst;
    logic [63:0] row_sel;
    
    // Digital Backend Flags
    logic        fifo_wr_en;
    logic [1:0]  event_flag;

    // DUT Instantiation
    roic_top i_dut (
        .sys_clk           (sys_clk),
        .rst_n             (rst_n),
        .sm_enable         (sm_enable),
        .program_bits      (program_bits),
        .div_clk_out       (div_clk_out),
        .row_addr          (row_addr),
        .pre_charge_global (pre_charge_global),
        .row_on_detect     (row_on_detect),
        .row_off_detect    (row_off_detect),
        .row_pixel_rst     (row_pixel_rst),
        .row_sel           (row_sel),
        .fifo_wr_en        (fifo_wr_en),
        .event_flag        (event_flag)
    );

    // 50MHz Clock Generation
    always #(SYS_CLK_PERIOD_NS / 2) sys_clk = ~sys_clk;

    initial begin
        $display("==================================================");
        $display("Starting FULL FRAME ROIC System TB");
        $display("Testing Speeds: 1us, 32us, and 256us");
        $display("==================================================");

        // --- TEST 1: Fastest Clock (1us) ---
        test_speed("Fast Mode", 1, 8'd1);

        // --- TEST 2: Medium Clock (32us) ---
        test_speed("Medium Mode", 32, 8'd32);

        // --- TEST 3: Slowest Clock (256us) ---
        // Note: 8'd0 triggers the 256us wrap-around in the prescaler math
        test_speed("Slow Mode (Max Integration)", 256, 8'd0);

        $display("\n==================================================");
        $display("ALL SPEEDS AND FULL FRAMES PASSED PERFECTLY!");
        $display("Simulation Complete.");
        $display("==================================================");
        
        $finish;
    end

    // -----------------------------------------------------------------
    // Master Task: Executes a full reset, init check, and 64-row sweep
    // -----------------------------------------------------------------
    task automatic test_speed(input string name, input int target_us, input logic [7:0] p_bits);
        $display("\n--------------------------------------------------");
        $display(" RUNNING TEST: %s (%0d us period)", name, target_us);
        $display("--------------------------------------------------");

// 1. Hard Reset & Setup
        rst_n = 0;
        sm_enable = 0;
        program_bits = p_bits;
        #(SYS_CLK_PERIOD_NS * 10);
        rst_n = 1;
        
        // 2. Verify Initial Conditions
        // Wait for the first system clock to push tick_25 past 0 and clear the Dead Zone
        @(posedge sys_clk); 
        #(SYS_CLK_PERIOD_NS + 1); 
        check_buses(1, 64'd0, 64'd0, 64'd0, 64'd1, 0, 1'b0, 2'b00, "INITIAL_CONDITIONS", 0);
        $display("  -> [INIT] System reset cleanly. Initial conditions met.");

        // 3. Enable FSM (Align to the clock safely)
        @(negedge div_clk_out);
        #(SYS_CLK_PERIOD_NS + 1); // Wait for dead zone to clear
        sm_enable = 1;

        // 4. Sweep all 64 rows
        for (int r = 0; r < 64; r++) begin
            bit verbose = (r == 0 || r == 31 || r == 63);
            if (verbose) $display("  -> Sweeping Row %0d...", r);
            
            verify_physical_sequence(r, !verbose);
        end

        // 5. Verify Loopback to Row 0
        $display("  -> Verifying Wrap-Around back to Row 0...");
        verify_physical_sequence(0, 0); // verbose = 0 (print pass)

        $display("  [SUCCESS] %s full frame complete.", name);
    endtask

// -----------------------------------------------------------------
    // Helper Task: Verifies the strictly synchronous posedge sequence
    // -----------------------------------------------------------------
    task automatic verify_physical_sequence(input int active_row, input bit quiet);
        logic [63:0] expected_hot_bus;

        expected_hot_bus = 64'd1 << active_row;

        // --- CYCLE 1: ON_DETECT ---
        @(posedge div_clk_out); 
        #(SYS_CLK_PERIOD_NS + 1); // Wait for Dead Zone to clear
        check_buses(0, expected_hot_bus, 64'd0, 64'd0, expected_hot_bus, active_row, 1'b1, 2'b10, "ON_DETECT (Eval)", quiet);
        
        @(negedge div_clk_out); 
        #(SYS_CLK_PERIOD_NS + 1); 
        // [FIX] Digital data plane remains safely stable for the FULL clock cycle.
        check_buses(1, 64'd0, 64'd0, 64'd0, expected_hot_bus, active_row, 1'b1, 2'b10, "ON_DETECT (PreCharge)", quiet);

        // --- CYCLE 2: OFF_DETECT ---
        @(posedge div_clk_out); 
        #(SYS_CLK_PERIOD_NS + 1);
        check_buses(0, 64'd0, expected_hot_bus, 64'd0, expected_hot_bus, active_row, 1'b1, 2'b01, "OFF_DETECT (Eval)", quiet);
        
        @(negedge div_clk_out); 
        #(SYS_CLK_PERIOD_NS + 1);
        check_buses(1, 64'd0, 64'd0, 64'd0, expected_hot_bus, active_row, 1'b1, 2'b01, "OFF_DETECT (PreCharge)", quiet);

        // --- CYCLE 3: PIXEL_RST ---
        @(posedge div_clk_out); 
        #(SYS_CLK_PERIOD_NS + 1);
        check_buses(0, 64'd0, 64'd0, expected_hot_bus, expected_hot_bus, active_row, 1'b0, 2'b00, "PIXEL_RST (Eval)", quiet);
        
        @(negedge div_clk_out); 
        #(SYS_CLK_PERIOD_NS + 1);
        // [FIX] Row address and token don't shift until the NEXT posedge! 
        check_buses(1, 64'd0, 64'd0, 64'd0, expected_hot_bus, active_row, 1'b0, 2'b00, "PIXEL_RST (PreCharge)", quiet);
    endtask

    
    // -----------------------------------------------------------------
    // Helper Task: Hard Assertions for 64-bit buses and FIFO signals
    // -----------------------------------------------------------------
    task automatic check_buses(
        input logic        exp_pre,
        input logic [63:0] exp_on_bus, 
        input logic [63:0] exp_off_bus, 
        input logic [63:0] exp_rst_bus, 
        input logic [63:0] exp_sel_bus, 
        input int          exp_addr,
        input logic        exp_wr_en,
        input logic [1:0]  exp_flag,
        input string       phase,
        input bit          quiet
    );
        // Hard fail check
        if (pre_charge_global !== exp_pre || row_on_detect !== exp_on_bus || 
            row_off_detect !== exp_off_bus || row_pixel_rst !== exp_rst_bus || 
            row_sel !== exp_sel_bus || row_addr !== exp_addr[5:0] || 
            fifo_wr_en !== exp_wr_en || event_flag !== exp_flag) begin
            
            $display("\n[FATAL ERROR] Bus routing failure during %s!", phase);
            $display("  Global PreCharge: Exp=%b, Act=%b", exp_pre, pre_charge_global);
            $display("  Row Address     : Exp=%0d, Act=%0d", exp_addr[5:0], row_addr);
            $display("  OnDetect Bus    : Exp=%h, Act=%h", exp_on_bus, row_on_detect);
            $display("  OffDetect Bus   : Exp=%h, Act=%h", exp_off_bus, row_off_detect);
            $display("  PixelRst Bus    : Exp=%h, Act=%h", exp_rst_bus, row_pixel_rst);
            $display("  RowSel Bus      : Exp=%h, Act=%h", exp_sel_bus, row_sel);
            $display("  FIFO Write En   : Exp=%b, Act=%b", exp_wr_en, fifo_wr_en);
            $display("  Event Flag      : Exp=%b, Act=%b", exp_flag, event_flag);
            $stop;
        end else if (!quiet) begin
            $display("      [PASS] %s matrix and FIFO data match perfectly.", phase);
        end
    endtask

endmodule : roic_top_tb