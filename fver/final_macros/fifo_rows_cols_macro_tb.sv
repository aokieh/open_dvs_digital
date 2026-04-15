//---------------------------------------------------------------------------
// Author: Ababakar Okieh
// Date  : April 14, 2026
//
// Module: fifo_rows_cols_macro_tb
// Description: 
//  Full-system data streaming verification for the 128x128 DVS Core.
//  Uses multi-threading to feed analog array data dynamically and 
//  read out the dual-tier Q-SPI FIFOs concurrently.
//---------------------------------------------------------------------------

`timescale 1ns/1ps

module fifo_rows_cols_macro_tb();

    parameter SYS_CLK_PERIOD_NS = 20; // 50MHz

    // -----------------------------------------------------------
    // System Signals
    // -----------------------------------------------------------
    logic        sys_clk = 0;
    logic        rst_n = 0;
    logic        sm_enable = 0;
    logic [7:0]  program_bits = 8'd1; // 1us fast mode

    // -----------------------------------------------------------
    // DUT Interfaces
    // -----------------------------------------------------------
    // Top Tier
    logic [63:0] array_col_top_left = '0, array_col_top_right = '0;
    logic [63:0] col_event_rst_top_left,  col_event_rst_top_right;
    logic [1:0]  pre_charge_global_top;
    logic [63:0] row_on_detect_top,       row_off_detect_top;
    
    logic        shift_en_top = 0;
    logic [15:0] rdata_spi_top;
    logic        empty_fifo_top, full_fifo_top;
    logic [3:0]  numel_fifo_top;

    // Bottom Tier
    logic [63:0] array_col_bot_left = '0, array_col_bot_right = '0;
    logic [63:0] col_event_rst_bot_left,  col_event_rst_bot_right;
    logic [1:0]  pre_charge_global_bot;
    logic [63:0] row_on_detect_bot,       row_off_detect_bot;
    
    logic        shift_en_bot = 0;
    logic [15:0] rdata_spi_bot;
    logic        empty_fifo_bot, full_fifo_bot;
    logic [3:0]  numel_fifo_bot;

    // -----------------------------------------------------------
    // Memory & Tracking
    // -----------------------------------------------------------
    logic [135:0] img_mem [0:255]; 
    int fd_top, fd_bot;
    
    int top_reads = 0;
    int bot_reads = 0;

    // -----------------------------------------------------------
    // DUT Instantiation
    // -----------------------------------------------------------
    fifo_rows_cols_macro i_dut (
        .sys_clk                 (sys_clk),
        .rst_n                   (rst_n),
        .sm_enable               (sm_enable),
        .program_bits            (program_bits),
        
        .array_col_top_left      (array_col_top_left),
        .array_col_top_right     (array_col_top_right),
        .col_event_rst_top_left  (col_event_rst_top_left),
        .col_event_rst_top_right (col_event_rst_top_right),
        .pre_charge_global_top   (pre_charge_global_top),
        .row_on_detect_top       (row_on_detect_top),
        .row_off_detect_top      (row_off_detect_top),
        
        .array_col_bot_left      (array_col_bot_left),
        .array_col_bot_right     (array_col_bot_right),
        .col_event_rst_bot_left  (col_event_rst_bot_left),
        .col_event_rst_bot_right (col_event_rst_bot_right),
        .pre_charge_global_bot   (pre_charge_global_bot),
        .row_on_detect_bot       (row_on_detect_bot),
        .row_off_detect_bot      (row_off_detect_bot),
        
        .shift_en_top            (shift_en_top),
        .rdata_spi_top           (rdata_spi_top),
        .empty_fifo_top          (empty_fifo_top),
        .full_fifo_top           (full_fifo_top),
        .numel_fifo_top          (numel_fifo_top),
        
        .shift_en_bot            (shift_en_bot),
        .rdata_spi_bot           (rdata_spi_bot),
        .empty_fifo_bot          (empty_fifo_bot),
        .full_fifo_bot           (full_fifo_bot),
        .numel_fifo_bot          (numel_fifo_bot)
    );

    // 50MHz Clock
    always #(SYS_CLK_PERIOD_NS / 2) sys_clk = ~sys_clk;

    // =================================================================
    // PROCESS 1: REQUIREMENT 1 - load_image_array() & Master Control
    // =================================================================
    initial begin
        $display("==================================================");
        $display("STARTING FULL DVS CORE DATA STREAMING (1us FAST MODE)");
        $display("==================================================");

        // 1. Load Data
        $readmemh("/LinuxRAID/home/aokieh1/projects/open_dvs_digital/fver/final_macros/python/papa_test_data_128x128.hex", img_mem);
        if (img_mem[0] === 136'hx) begin
            $display("[FATAL ERROR] Failed to load hex file!");
            $stop;
        end

        // Setup File I/O for Python Reconstruction
        fd_top = $fopen("/LinuxRAID/home/aokieh1/projects/open_dvs_digital/fver/final_macros/python/sim_output_top.txt", "w");
        fd_bot = $fopen("/LinuxRAID/home/aokieh1/projects/open_dvs_digital/fver/final_macros/python/sim_output_bot.txt", "w");

        // Hard Reset
        rst_n = 0;
        #(SYS_CLK_PERIOD_NS * 10);
        rst_n = 1;
        
        @(posedge sys_clk);
        sm_enable = 1;

        // Wait until both tiers completely finish shifting all 128 words (64 ON + 64 OFF)
        wait(top_reads == 128 && bot_reads == 128);
        
        // Emulate frame end
        #(SYS_CLK_PERIOD_NS * 100);
        sm_enable = 0;
        
        $display("\n==================================================");
        $display("IMAGE STREAMING COMPLETE.");
        $display("Peak Frame Rate Maintained: ~5200 Hz");
        $display("==================================================");
        $fclose(fd_top);
        $fclose(fd_bot);
        $finish;
    end

    // =================================================================
    // PROCESS 2 & 3: REQUIREMENT 2 - write_to_fifo() (Front-End)
    // =================================================================
    initial begin
        feed_and_verify_tier("TOP", 0,  array_col_top_left, array_col_top_right, col_event_rst_top_left, col_event_rst_top_right, row_on_detect_top, row_off_detect_top);
    end

    initial begin
        feed_and_verify_tier("BOT", 64, array_col_bot_left, array_col_bot_right, col_event_rst_bot_left, col_event_rst_bot_right, row_on_detect_bot, row_off_detect_bot);
    end

    task automatic feed_and_verify_tier(
        input string tier_name,
        input int offset,
        ref logic [63:0] col_left,  ref logic [63:0] col_right,
        ref logic [63:0] rst_left,  ref logic [63:0] rst_right,
        ref logic [63:0] row_on_det, ref logic [63:0] row_off_det
    );
        longint target_ns = (program_bits == 0 ? 256 : program_bits) * 1000;
        longint expected_on_to_off = 1 * target_ns; // 1us
        longint expected_on_to_on  = 3 * target_ns; // 3us

        longint wr_on_time = 0, wr_off_time = 0, prev_wr_on_time = 0;
        logic [127:0] test_on_data, test_off_data;

        for (int r = 0; r < 64; r++) begin
            // Fetch memory payload
            test_on_data  = img_mem[(offset + r) * 2][135:8];
            test_off_data = img_mem[((offset + r) * 2) + 1][135:8];

            // ----------------------------------------
            // 1. ON_DETECT PHASE
            // ----------------------------------------
            wait(row_on_det != 0);
            col_left  = test_on_data[127:64];
            col_right = test_on_data[63:0];

            // Hierarchical wait for the internal write trigger
            if (tier_name == "TOP") @(posedge i_dut.i_row_decoder_top.fifo_wr_en);
            else                    @(posedge i_dut.i_row_decoder_bot.fifo_wr_en);
            wr_on_time = $time;

            if (r > 0) begin
                if ((wr_on_time - prev_wr_on_time) !== expected_on_to_on) begin
                    $display("[%s] [FATAL] ON->ON delta mismatch at row %0d! Expected %0d ns, Actual %0d ns", tier_name, r, expected_on_to_on, (wr_on_time - prev_wr_on_time));
                    $stop;
                end
            end
            prev_wr_on_time = wr_on_time;

            wait(row_on_det == 0);
            col_left = '0; col_right = '0;

            // ----------------------------------------
            // 2. OFF_DETECT PHASE
            // ----------------------------------------
            wait(row_off_det != 0);
            col_left  = test_off_data[127:64];
            col_right = test_off_data[63:0];

            if (tier_name == "TOP") @(posedge i_dut.i_row_decoder_top.fifo_wr_en);
            else                    @(posedge i_dut.i_row_decoder_bot.fifo_wr_en);
            wr_off_time = $time;

            if ((wr_off_time - wr_on_time) !== expected_on_to_off) begin
                $display("[%s] [FATAL] ON->OFF delta mismatch at row %0d! Expected %0d ns, Actual %0d ns", tier_name, r, expected_on_to_off, (wr_off_time - wr_on_time));
                $stop;
            end

            wait(row_off_det == 0);
            col_left = '0; col_right = '0;

            // ----------------------------------------
            // 3. PIXEL_RST INTEGRITY CHECK
            // ----------------------------------------
            if (tier_name == "TOP") @(posedge i_dut.i_row_decoder_top.sm_pixel_rst);
            else                    @(posedge i_dut.i_row_decoder_bot.sm_pixel_rst);

            #(SYS_CLK_PERIOD_NS * 1.5); // Sample stable data mid-reset
            if ({rst_left, rst_right} !== (test_on_data | test_off_data)) begin
                $display("[%s] [FATAL] Pixel Reset mismatch at row %0d!", tier_name, r);
                $stop;
            end
            
            if (r % 16 == 0 || r == 63) begin
                $display("  -> [%s] Row %0d successfully loaded & verified (Resets + Deltas matched).", tier_name, r);
            end
        end
    endtask

    // =================================================================
    // PROCESS 4 & 5: REQUIREMENT 3 - read_row_from_fifo() (Back-End)
    // =================================================================
    initial begin
        while (top_reads < 128) begin
            read_row_from_fifo("TOP", fd_top, empty_fifo_top, shift_en_top, rdata_spi_top);
            top_reads++;
        end
    end

    initial begin
        while (bot_reads < 128) begin
            read_row_from_fifo("BOT", fd_bot, empty_fifo_bot, shift_en_bot, rdata_spi_bot);
            bot_reads++;
        end
    end

    task automatic read_row_from_fifo(
        input string tier_name,
        input int fd,
        ref logic empty,
        ref logic shift_en,
        ref logic [15:0] rdata
    );
        logic [135:0] rec_word;
        logic [63:0]  d_left = '0, d_right = '0;
        logic [7:0]   ctrl = '0;
        longint       start_t, end_t;

        wait(!empty);
        
        // Align to clock edge to ensure perfect precision measurement
        @(posedge sys_clk);
        start_t = $time;

        // 8 Parallel Data Shifts
        for (int s = 0; s < 8; s++) begin
            for (int j = 0; j < 6; j++) begin
                @(posedge sys_clk); #1; shift_en = 0;
            end
            d_left[(s*8)+:8]  = rdata[15:8];
            d_right[(s*8)+:8] = rdata[7:0];
            @(posedge sys_clk); #1; shift_en = 1;
            @(posedge sys_clk); #1; shift_en = 0; 
        end

        // 1 Control Shift
        for (int j = 0; j < 6; j++) begin
            @(posedge sys_clk); #1; shift_en = 0;
        end
        ctrl = rdata[15:8];
        @(posedge sys_clk); #1; shift_en = 1;
        
        // --- THE FIX: Capture time exactly on the 72nd edge ---
        @(posedge sys_clk); 
        end_t = $time;       // Capture time BEFORE the #1 delay
        #1; shift_en = 0;    // Now apply the hold-time delay safely

        rec_word = {ctrl, d_left, d_right};

        // Assert constant 1440ns throughput
        if ((end_t - start_t) !== 1440) begin
            $display("[%s] [FATAL] SPI Read timing violation! Expected 1440ns, Actual: %0d ns", tier_name, (end_t - start_t));
            $stop;
        end

        // Write to python file (136 bits = 34 hex characters)
        $fdisplay(fd, "%034x", rec_word);
        
        // Terminal heartbeat
        if ((top_reads + bot_reads) % 32 == 0) begin
            $display("  -> [%s] SPI Shifted successfully in 1440ns.", tier_name);
        end
    endtask

endmodule : fifo_rows_cols_macro_tb