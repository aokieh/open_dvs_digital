//---------------------------------------------------------------------------
// Module: col_readout_macro_tb
// Description: 
//  Self-checking testbench for the column readout macro. 
//  Verifies metastability synchronization, gated pixel resets, 
//  FIFO writing, and full 136-bit QSPI reconstruction.
//---------------------------------------------------------------------------

`timescale 1ns/1ps

module col_readout_macro_tb();

    // Parameters
    parameter SYS_CLK_PERIOD = 20; // 50MHz
    parameter FIFO_DWIDTH    = 136;
    parameter FIFO_DEPTH     = 16;

    // -----------------------------------------------------------
    // Signals
    // -----------------------------------------------------------
    logic clk = 0;
    logic rst_n = 0;

    // Array Analog Inputs
    logic [63:0] array_col_left  = '0;
    logic [63:0] array_col_right = '0;

    // Array Reset Outputs
    logic [63:0] col_event_rst_left;
    logic [63:0] col_event_rst_right;

    // FSM Control Inputs
    logic sm_enable       = 0;
    logic sm_on_detect    = 0;
    logic sm_off_detect   = 0;
    logic sm_pixel_rst    = 0;
    logic sm_next_row     = 0;
    logic sm_detect_pulse = 0;

    // FIFO / Event Metadata
    logic       fifo_wr_en = 0;
    logic [5:0] row_addr   = 0;
    logic [1:0] event_mode = 0;

    // SPI / FIFO Readout
    logic        shift_en_fifo = 0;
    logic [15:0] rdata_spi;
    logic        empty_fifo, full_fifo;
    logic [$clog2(FIFO_DEPTH)-1:0] numel_fifo;

    // TB Tracking
    logic [135:0] expected_data_queue [$];
    int fd;
    int pass_count = 0;
    int fail_count = 0;

    // -----------------------------------------------------------
    // Device Under Test (DUT)
    // -----------------------------------------------------------
    col_readout_macro i_dut (
        .clk                 (clk),
        .rst_n               (rst_n),
        
        .array_col_left      (array_col_left),
        .array_col_right     (array_col_right),
        .col_event_rst_left  (col_event_rst_left),
        .col_event_rst_right (col_event_rst_right),
        
        .sm_enable           (sm_enable),
        .sm_on_detect        (sm_on_detect),
        .sm_off_detect       (sm_off_detect),
        .sm_pixel_rst        (sm_pixel_rst),
        .sm_next_row         (sm_next_row),
        .sm_detect_pulse     (sm_detect_pulse),
        
        .fifo_wr_en          (fifo_wr_en),
        .row_addr            (row_addr),
        .event_mode          (event_mode),
        
        .shift_en_fifo       (shift_en_fifo),
        .rdata_spi           (rdata_spi),
        .empty_fifo          (empty_fifo),
        .full_fifo           (full_fifo),
        .numel_fifo          (numel_fifo)
    );

    // Clock Generation
    always #(SYS_CLK_PERIOD / 2) clk = ~clk;

    // -----------------------------------------------------------
    // Test Sequence
    // -----------------------------------------------------------
    initial begin
        fd = $fopen("macro_verification.txt", "w");
        $fdisplay(fd, "==================================================");
        $fdisplay(fd, " COL READOUT MACRO INTEGRATION TEST LOG");
        $fdisplay(fd, "==================================================\n");

        $display("Starting Macro Testbench...");

        // 1. Reset
        rst_n = 0;
        #50;
        rst_n = 1;
        #20;
        
        @(posedge clk);
        sm_enable = 1;
        

        // 2. Fill the FIFO while checking Resets
        $display("\n--- PHASE 1: FILLING FIFO & CHECKING RESETS ---");
        $fdisplay(fd, "--- PHASE 1: FILLING FIFO & CHECKING RESETS ---");
        
        // Sweep 8 rows (2 events per row = 16 words, perfectly filling the FIFO)
        for (int i = 0; i < (FIFO_DEPTH / 2); i++) begin
            simulate_row_event(i[5:0]);
        end

        if (full_fifo) $display("FIFO Successfully Filled to %0d elements.", numel_fifo);

        // 3. Drain and Verify SPI Readout
        $display("\n--- PHASE 2: SPI READOUT & RECONSTRUCTION ---");
        $fdisplay(fd, "\n--- PHASE 2: SPI READOUT & RECONSTRUCTION ---");
        
        while (!empty_fifo) begin
            read_row_data();
        end

        // 4. Summary
        $display("\n==================================================");
        $display("TEST COMPLETE: %0d PASSED | %0d FAILED", pass_count, fail_count);
        $display("Check macro_verification.txt for full log.");
        $display("==================================================");
        $fdisplay(fd, "\n==================================================");
        $fdisplay(fd, "END OF LOG.");
        $fclose(fd);
        $finish;
    end


    // -----------------------------------------------------------------
    // Task: Cycle-Accurate Emulation of the ROIC FSM (Fully Periodic)
    // -----------------------------------------------------------------
    task automatic simulate_row_event(input logic [5:0] addr);
        // FSM Timing Parameters (Emulating program_bits = 8'd1)
        int P_PRE_CHARGE   = 4;
        int P_BUFFER       = 4;
        int P_DETECT       = 4;
        int P_ON_DETECT    = 8;
        int P_OFF_DETECT   = 8;
        int P_RST          = 25;
        int target_ticks   = 50; 

        // Exact Subtraction Math
        int wait_off_ticks  = target_ticks - (P_ON_DETECT + P_PRE_CHARGE + P_BUFFER); // 34
        int wait_rst_ticks  = target_ticks - (P_OFF_DETECT + P_BUFFER);                 // 38
        int wait_next_ticks = target_ticks - (P_RST + 1 + P_PRE_CHARGE + P_BUFFER);     // 16

        // Randomized Analog Data
        logic [63:0] on_left  = {$random, $random};
        logic [63:0] on_right = {$random, $random};
        logic [63:0] off_left = {$random, $random};
        logic [63:0] off_right= {$random, $random};

        // --- PRE_CHARGE & BUFFER ---
        array_col_left  = on_left;
        array_col_right = on_right;
        repeat(P_PRE_CHARGE + P_BUFFER) @(posedge clk);

        // =================================================================
        // 1. ON_DETECT PHASE (8 cycles)
        // =================================================================
        #1; sm_on_detect = 1;
        repeat(P_ON_DETECT - P_DETECT) @(posedge clk); 
        
        #1; sm_detect_pulse = 1;                       
        repeat(P_DETECT) @(posedge clk);               

        // Transition: End of ON_DETECT / Start of WAIT_OFF
        #1;
        sm_on_detect    = 0;
        sm_detect_pulse = 0;
        fifo_wr_en      = 1; 
        row_addr        = addr;
        event_mode      = 2'b10;
        expected_data_queue.push_back({2'b10, addr, on_left, on_right});

        @(posedge clk);
        #1;
        fifo_wr_en = 0; 

        array_col_left  = off_left;
        array_col_right = off_right;

        // Remaining wait = 34 + 4 + 4 - 1 = 41 cycles
        repeat(wait_off_ticks + P_PRE_CHARGE + P_BUFFER - 1) @(posedge clk);

        // =================================================================
        // 2. OFF_DETECT PHASE (8 cycles) -> EXACTLY 50 CYCLES LATER
        // =================================================================
        #1; sm_off_detect = 1;
        repeat(P_OFF_DETECT - P_DETECT) @(posedge clk);
        
        #1; sm_detect_pulse = 1;
        repeat(P_DETECT) @(posedge clk);

        // Transition: End of OFF_DETECT / Start of WAIT_RST
        #1;
        sm_off_detect   = 0;
        sm_detect_pulse = 0;
        fifo_wr_en      = 1;
        row_addr        = addr;
        event_mode      = 2'b01;
        expected_data_queue.push_back({2'b01, addr, off_left, off_right});

        @(posedge clk);
        #1;
        fifo_wr_en = 0;

        // Remaining wait = 38 + 4 - 1 = 41 cycles
        repeat(wait_rst_ticks + P_BUFFER - 1) @(posedge clk);

        // =================================================================
        // 3. PIXEL_RST PHASE (25 cycles) -> EXACTLY 50 CYCLES LATER
        // =================================================================
        #1; sm_pixel_rst = 1;

        repeat(5) @(posedge clk);
        #1;
        
        if ((col_event_rst_left !== (on_left | off_left)) || (col_event_rst_right !== (on_right | off_right))) begin
            $display("[FAIL] Reset Mismatch at Row %0d", addr);
            fail_count++;
        end else begin
            $display("[PASS] Targeted Reset Verified at Row %0d", addr);
            pass_count++;
        end

        repeat(P_RST - 5) @(posedge clk);
        #1;
        sm_pixel_rst = 0;

        // =================================================================
        // 4. NEXT_ROW & WAIT_NEXT PHASE -> BRIDGING THE 50 CYCLE GAP
        // =================================================================
        #1; sm_next_row = 1;
        @(posedge clk);
        #1; sm_next_row = 0;

        array_col_left  = '0;
        array_col_right = '0;

        // Emulate ST_WAIT_NEXT to maintain strict inter-row periodicity
        // 16 cycles for program_bits = 1
        repeat(wait_next_ticks) @(posedge clk);
    endtask

    // -----------------------------------------------------------------
    // Task: SPI Shift Generation
    // -----------------------------------------------------------------
    task automatic shifting_sequence(output logic [15:0] captured_spi);
        // 6 cycles low
        for (int j = 0; j < 6; j++) begin
            @(posedge clk);
            #1;
            shift_en_fifo = 0;
            if (j == 5) captured_spi = rdata_spi; // Capture at end of low phase
        end
        // 1 cycle high (shift)
        @(posedge clk);
        #1;
        shift_en_fifo = 1;
        // 1 cycle low (interleaved)
        @(posedge clk);
        #1;
        shift_en_fifo = 0; 
    endtask


    // -----------------------------------------------------------------
    // Task: Reconstruct and Granularly Compare Scoreboard Data
    // -----------------------------------------------------------------
    task automatic read_row_data();
        logic [135:0] expected_word;
        logic [15:0]  spi_chunk;

        logic [63:0] data_left  = '0;
        logic [63:0] data_right = '0;
        logic [7:0]  ctrl_byte  = '0;

        // --- Extracted Expected Data Variables ---
        logic [7:0]  exp_ctrl;
        logic [63:0] exp_left;
        logic [63:0] exp_right;
        
        // --- Match Flags ---
        bit ctrl_match;
        bit left_match;
        bit right_match;

        // 1. Shifts 1-8: Parallel Data Phase
        for (int s = 0; s < 8; s++) begin
            shifting_sequence(spi_chunk);
            data_left[(s*8)  +: 8] = spi_chunk[15:8]; // Channel A
            data_right[(s*8) +: 8] = spi_chunk[7:0];  // Channel B
        end

        // 2. Shift 9: Control Phase
        shifting_sequence(spi_chunk);
        ctrl_byte = spi_chunk[15:8]; 

        // 3. Granular Scoreboard Verification
        if (expected_data_queue.size() > 0) begin
            expected_word = expected_data_queue.pop_front();
            
            // Extract the expected components (Assignments only)
            exp_ctrl  = expected_word[135:128];
            exp_left  = expected_word[127:64];
            exp_right = expected_word[63:0];

            // Independent checks
            ctrl_match  = (ctrl_byte === exp_ctrl);
            left_match  = (data_left === exp_left);
            right_match = (data_right === exp_right);

            if (ctrl_match && left_match && right_match) begin
                // Formatted for easy scanning: Control header followed by the data payloads
                $display("READ [PASS] : CTRL %h | L %h | R %h", ctrl_byte, data_left, data_right);
                $fdisplay(fd, "READ [PASS] : CTRL %h | L %h | R %h", ctrl_byte, data_left, data_right);
            end else begin
                $display("READ [FAIL] : Pipeline Mismatch Detected!");
                $fdisplay(fd, "READ [FAIL] : Pipeline Mismatch Detected!");
                
                // Targeted Error Reporting
                if (!ctrl_match) begin
                    $display("  -> CTRL ERROR  | EXP: %h | ACT: %h", exp_ctrl, ctrl_byte);
                    $fdisplay(fd, "  -> CTRL ERROR  | EXP: %h | ACT: %h", exp_ctrl, ctrl_byte);
                end
                if (!left_match) begin
                    $display("  -> LEFT ERROR  | EXP: %h | ACT: %h", exp_left, data_left);
                    $fdisplay(fd, "  -> LEFT ERROR  | EXP: %h | ACT: %h", exp_left, data_left);
                end
                if (!right_match) begin
                    $display("  -> RIGHT ERROR | EXP: %h | ACT: %h", exp_right, data_right);
                    $fdisplay(fd, "  -> RIGHT ERROR | EXP: %h | ACT: %h", exp_right, data_right);
                end
                $stop; 
            end
        end else begin
            $display("[WARNING] Read executed but expected queue is empty!");
            $fdisplay(fd, "[WARNING] Read executed but expected queue is empty!");
        end
    endtask

endmodule : col_readout_macro_tb