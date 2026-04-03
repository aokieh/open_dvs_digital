//---------------------------------------------------------------------------
// Module: clk_div_tb
// Description: 
//  Self-checking testbench for the corrected 500ns-base clock divider.
//  Verifies 1us to 256us FULL PERIOD granularity at 50MHz.
//---------------------------------------------------------------------------

`timescale 1ns/1ps

module clk_div_tb();

    // -----------------------------------------------------------------
    // System Parameters
    // -----------------------------------------------------------------
    parameter SYS_CLK_FREQ_MHZ = 50;
    parameter SYS_CLK_PERIOD_NS = 1000 / SYS_CLK_FREQ_MHZ; // 20ns
    parameter ONE_MICROSECOND_NS = 1000;

    // -----------------------------------------------------------------
    // DUT Signals
    // -----------------------------------------------------------------
    logic       sys_clk = 0;
    logic       rst_n = 0;
    logic [7:0] program_bits = 0;
    logic       div_clk;

    // -----------------------------------------------------------------
    // DUT Instantiation
    // -----------------------------------------------------------------
    clk_div i_clk_div (
        .sys_clk      (sys_clk),
        .rst_n        (rst_n),
        .program_bits (program_bits),
        .div_clk      (div_clk)
    );

    // -----------------------------------------------------------------
    // Clock Generation
    // -----------------------------------------------------------------
    always begin
        #(SYS_CLK_PERIOD_NS / 2) sys_clk = ~sys_clk;
    end

    // -----------------------------------------------------------------
    // Main Test Sequence
    // -----------------------------------------------------------------
    initial begin
        $display("========================================");
        $display("Starting Prescaler Clock Divider TB...");
        $display("System Clock: %0d MHz (%0d ns period)", SYS_CLK_FREQ_MHZ, SYS_CLK_PERIOD_NS);
        $display("Verifying FULL PERIOD granularity.");
        $display("========================================");

        // 1. Reset Sequence
        rst_n = 0;
        program_bits = 8'd1; 
        #100;
        rst_n = 1;
        $display("[INIT] Reset de-asserted. Hardware alive.");

        // 2. Test Cases
        $display("\n--- TEST 1: Minimum Granularity (1 us Period) ---");
        program_bits = 8'd1;
        measure_and_verify(1);

        $display("\n--- TEST 2: Typical Low Granularity (5 us Period) ---");
        program_bits = 8'd5;
        measure_and_verify(5); 

        $display("\n--- TEST 3: Medium Granularity (42 us Period) ---");
        program_bits = 8'd42;
        measure_and_verify(42); 

        $display("\n--- TEST 4: Maximum Granularity (255 us Period) ---");
        program_bits = 8'd255;
        measure_and_verify(255); 

        $display("\n========================================");
        $display("All timing checks PASSED perfectly!");
        $display("Simulation Complete.");
        $display("========================================");
        
        $finish;
    end

    // -----------------------------------------------------------------
    // Self-Checking Measurement Task
    // -----------------------------------------------------------------
    // Updated to measure FULL PERIOD (posedge to posedge)
    // -----------------------------------------------------------------
    task automatic measure_and_verify(input int target_us);
        time t_start, t_end;
        time measured_period_ns;
        time expected_period_ns = target_us * ONE_MICROSECOND_NS;
        
        // Wait for the first stable rising edge
        @(posedge div_clk);
        t_start = $realtime;
        
        // Wait for the next rising edge to complete a FULL clock cycle
        @(posedge div_clk);
        t_end = $realtime;
        
        measured_period_ns = t_end - t_start;
        
        $display("  Target Full-Period: %0d us (%0d ns)", target_us, expected_period_ns);
        $display("  Actual Full-Period: %0d ns", measured_period_ns);
        
        // Assertion check
        if (measured_period_ns !== expected_period_ns) begin
            $display("\n[FATAL ERROR] Period mismatch detected!");
            $display("Expected %0d ns but measured %0d ns.", expected_period_ns, measured_period_ns);
            $stop;
        end else begin
            $display("  -> [PASS] Period is dead accurate.");
        end
        
    endtask

endmodule : clk_div_tb