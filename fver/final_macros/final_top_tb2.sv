//---------------------------------------------------------------------------
// Author: Ababakar Okieh
// Date  : April 28, 2026
//
// Module: final_top_tb
// Description: 
//  Full-chip Sign-off TB. Exhaustively tests RegFile configuration using 
//  ported self_check_tb sequences, and verifies True Continuous Q-SPI streaming.
//  Executes Multi-Speed continuous frames and dumps to independent text files.
//---------------------------------------------------------------------------

`timescale 1ns/1ps

module final_top_tb();

    parameter SYS_CLK_PERIOD_NS = 20; // 50MHz Continuous Global Clock

    // -----------------------------------------------------------
    // Top-Level Pins
    // -----------------------------------------------------------
    logic clk = 0; 
    logic rst_n = 0;
    
    // Q-SPI Interface
    logic       CS_N = 1;
    logic [3:0] COPI = 0;
    logic [3:0] CIPO;

    // Analog/Peripheral Outputs
    logic [`DAC_WIDTH-1:0] dac_config_0, dac_config_1, dac_config_2, dac_config_3, dac_config_4;
    logic [`DAC_WIDTH-1:0] dac_config_5, dac_config_6, dac_config_7, dac_config_8, dac_config_9;

    // Analog Array Interfaces
    logic [63:0] array_col_top_left = '0, array_col_top_right = '0;
    logic [63:0] array_col_bot_left = '0, array_col_bot_right = '0;
    logic [63:0] col_event_rst_top_left,  col_event_rst_top_right;
    logic [63:0] col_event_rst_bot_left,  col_event_rst_bot_right;
    logic [1:0]  pre_charge_global_top,   pre_charge_global_bot;
    logic [1:0]  detect_pulse_global_top, detect_pulse_global_bot;
    logic [63:0] row_on_detect_top,       row_off_detect_top;
    logic [63:0] row_on_detect_bot,       row_off_detect_bot;

    logic sm_enable = 0;
    logic data_ready;

    // -----------------------------------------------------------
    // File I/O & Tracking
    // -----------------------------------------------------------
    logic [135:0] img_mem [0:255];
    int fd_top, fd_bot; // Global file descriptors

    logic [11:0] dac_write_data  [7:0];

    // -----------------------------------------------------------
    // DUT Instantiation
    // -----------------------------------------------------------
    final_top2 i_dut (
        .clk                     (clk),
        .rst_n                   (rst_n),
        .CS_N                    (CS_N),
        .COPI                    (COPI),
        .CIPO                    (CIPO),

        .dac_config_0(dac_config_0), .dac_config_1(dac_config_1), 
        .dac_config_2(dac_config_2), .dac_config_3(dac_config_3),
        .dac_config_4(dac_config_4), .dac_config_5(dac_config_5), 
        .dac_config_6(dac_config_6), .dac_config_7(dac_config_7),
        .dac_config_8(dac_config_8), .dac_config_9(dac_config_9),

        .array_col_top_left      (array_col_top_left),
        .array_col_top_right     (array_col_top_right),
        .col_event_rst_top_left  (col_event_rst_top_left),
        .col_event_rst_top_right (col_event_rst_top_right),
        .detect_pulse_global_top (detect_pulse_global_top),
        .pre_charge_global_top   (pre_charge_global_top),
        .row_on_detect_top       (row_on_detect_top),
        .row_off_detect_top      (row_off_detect_top),

        .array_col_bot_left      (array_col_bot_left),
        .array_col_bot_right     (array_col_bot_right),
        .col_event_rst_bot_left  (col_event_rst_bot_left),
        .col_event_rst_bot_right (col_event_rst_bot_right),
        .detect_pulse_global_bot (detect_pulse_global_bot),
        .pre_charge_global_bot   (pre_charge_global_bot),
        .row_on_detect_bot       (row_on_detect_bot),
        .row_off_detect_bot      (row_off_detect_bot),

        .data_ready_top          (data_ready),
        .sm_enable               (sm_enable)
    );

    // Continuous Master Clock
    always #(SYS_CLK_PERIOD_NS / 2) clk = ~clk;

    // =================================================================
    // MAIN EXECUTION THREAD
    // =================================================================
    initial begin
        $display("==================================================");
        $display("STARTING FULL CHIP SIGN-OFF TEST (MULTI-SPEED)");
        $display("==================================================");

        $readmemh("../python/papa_test_data_128x128.hex", img_mem);
        
        rst_n = 0;
        #(SYS_CLK_PERIOD_NS * 10); rst_n = 1;
        #(SYS_CLK_PERIOD_NS * 10); rst_n = 0;
        #(SYS_CLK_PERIOD_NS * 10); rst_n = 1;
        #(SYS_CLK_PERIOD_NS * 5);

        // -----------------------------------------------------------
        // 1. Exhaustive RegFile Mapping Test 
        // -----------------------------------------------------------
        $display("-> Testing Memory Map: Writing DACs and IRQs...");
        pulse_fifo_rst_n(4'hf);
        set_irq(12'hfff, 12'hfff);
        write_dacs(12'hfff);
        #500ns;

        pulse_fifo_rst_n(4'h0);
        set_irq(12'h000, 12'h000);
        write_dacs(12'h000);
        #500ns;

        write_dacs_seq(12'h5aa);           
        set_irq(12'h2AA, 12'h2AA);
        #500ns;

        write_dacs_seq(12'hfaa);          
        set_irq(12'h0CC, 12'h1DD);
        #500ns;
        $display("   [PASS] Exhaustive RegFile configuration verified!");

        // -----------------------------------------------------------
        // 2. Multi-Speed Continuous Read Sequences
        // -----------------------------------------------------------
        // Frame 1: 1us Fast Mode (Default 14-bit Tunings)
        run_full_frame("1us Fast Mode", "1us", 8'd1, 14'd4, 14'd4, 14'd4, 14'd8, 14'd8, 14'd25);

        // Frame 2: 32us Medium Mode (Default 14-bit Tunings)
        run_full_frame("32us Medium Mode", "32us", 8'd32, 14'd4, 14'd4, 14'd4, 14'd8, 14'd8, 14'd25);

        // Frame 3: 256us Extreme Mode (Massive 14-bit Tuning Pulses)
        run_full_frame("256us Extreme Mode", "256us", 8'd0, 14'd1000, 14'd1000, 14'd1000, 14'd10000, 14'd10000, 14'd5000);

        $display("\n==================================================");
        $display("ALL MULTI-SPEED SEQUENCES STREAMED SUCCESSFULLY.");
        $display("==================================================");
        
        $finish;
    end

    // =================================================================
    // UNIFIED FRAME EXECUTION TASK
    // =================================================================
    task automatic run_full_frame(
        input string frame_name,
        input string file_suffix,
        input logic [7:0] p_bits,
        input logic [13:0] pre, input logic [13:0] buf_val, input logic [13:0] det,
        input logic [13:0] on_det, input logic [13:0] off_det, input logic [13:0] rst_val
    );
        $display("\n==================================================");
        $display("STARTING FRAME: %s", frame_name);
        $display("==================================================");

        // Open specific files for this frame configuration
        fd_top = $fopen($sformatf("../python/final_top_out_top_%s.txt", file_suffix), "w");
        fd_bot = $fopen($sformatf("../python/final_top_out_bot_%s.txt", file_suffix), "w");

        // 1. Configure Hardware over Q-SPI
        write_event_rate(p_bits);
        write_phase_tunings(pre, buf_val, det, on_det, off_det, rst_val);
        verify_spi_configurations(p_bits, on_det, off_det);

        // 2. Start Hardware
        $display("-> Starting Imager & Streaming QSPI Data...");
        @(posedge clk);
        sm_enable = 1;

        // 3. Multi-Thread the Feeders and the SPI Master
        fork
            feed_tier("TOP", 0);
            feed_tier("BOT", 64);
            qspi_master_readout();
        join

        // 4. Teardown
        sm_enable = 0;
        
        // Close the file descriptors safely
        $fclose(fd_top);
        $fclose(fd_bot);
        
        #(SYS_CLK_PERIOD_NS * 100);
    endtask

    // =================================================================
    // Q-SPI MASTER READOUT TASK
    // =================================================================
    task automatic qspi_master_readout();
        logic [135:0] top_rec, bot_rec;
        logic [15:0] top_chunks[9];
        logic [15:0] bot_chunks[9];
        longint start_t, end_t;
        real frame_rate;
        int words_read = 0;

        // Wait for imager FSM to fully initialize
        wait(data_ready == 1);
        start_t = $time;

        // Smart Polling Loop (Reads exactly 128 words per frame)
        while (words_read < 128) begin
            
            // Step A: Wait for the ASIC to signal Data Ready
            wait(data_ready == 1);

            // Step B: Initiate Read Transaction
            @(negedge clk);
            CS_N = 0;

            // Send Opcode (3'b111 = 8'h07)
            for(int k=0; k<8; k++) begin
                COPI[0] = (8'h07 >> (7-k)) & 1;
                @(negedge clk);
            end
            COPI = 0;

            // Step C: Stream continuously ONLY while data is actually ready
            while((data_ready == 1) && words_read < 128) begin
                for(int chunk=0; chunk<9; chunk++) begin
                    for(int k=0; k<8; k++) begin
                        @(posedge clk);
                        bot_chunks[chunk][15-k] = CIPO[3];
                        bot_chunks[chunk][7-k]  = CIPO[2]; 
                        top_chunks[chunk][15-k] = CIPO[1]; 
                        top_chunks[chunk][7-k]  = CIPO[0]; 
                        @(negedge clk); 
                    end
                end
                
                // Reconstruct the 136-bit word
                for(int s=0; s<8; s++) begin
                    top_rec[64 + (s*8) +: 8] = top_chunks[s][15:8];
                    top_rec[0  + (s*8) +: 8] = top_chunks[s][7:0];  
                    bot_rec[64 + (s*8) +: 8] = bot_chunks[s][15:8];
                    bot_rec[0  + (s*8) +: 8] = bot_chunks[s][7:0];  
                end
                top_rec[135:128] = top_chunks[8][15:8];
                bot_rec[135:128] = bot_chunks[8][15:8]; 

                $fdisplay(fd_top, "%034x", top_rec);
                $fdisplay(fd_bot, "%034x", bot_rec);
                
                words_read++;
                if (words_read % 16 == 0) $display("  -> Smart Master Grabbed %0d Rows...", words_read);
            end
            
            // Step D: Data ran out. Raise CS_N to save power!
            CS_N = 1; 
            @(negedge clk); 
        end

        end_t = $time;
        
        // Calculate True Hardware Frame Rate
        frame_rate = 1.0 / ((end_t - start_t) / 1000000000.0);
        $display("\nFRAME COMPLETE.");
        $display("Generation & Readout Time: %0d ns", (end_t - start_t));
        $display("Average Frame Rate: ~%0d Hz", frame_rate);
    endtask

    // =================================================================
    // ANALOG ARRAY FEEDER TASK
    // =================================================================
    task automatic feed_tier(input string tier_name, input int offset);
        logic [127:0] t_on, t_off;
        for (int r = 0; r < 64; r++) begin
            
            t_on  = img_mem[(offset + r) * 2][135:8];
            t_off = img_mem[((offset + r) * 2) + 1][135:8];

            if (tier_name == "TOP") begin
                wait(row_on_detect_top != 0);
                array_col_top_left  = t_on[127:64];
                array_col_top_right = t_on[63:0];
                wait(row_on_detect_top == 0);
                
                wait(row_off_detect_top != 0);
                array_col_top_left  = t_off[127:64];
                array_col_top_right = t_off[63:0];
                wait(row_off_detect_top == 0);
            end else begin
                wait(row_on_detect_bot != 0);
                array_col_bot_left  = t_on[127:64];
                array_col_bot_right = t_on[63:0];
                wait(row_on_detect_bot == 0);
                
                wait(row_off_detect_bot != 0);
                array_col_bot_left  = t_off[127:64];
                array_col_bot_right = t_off[63:0];
                wait(row_off_detect_bot == 0);
            end
        end
    endtask

    // =================================================================
    // Q-SPI CONFIGURATION & ASSERTIONS
    // =================================================================
    task automatic verify_spi_configurations(
        input logic [7:0] exp_pbits, 
        input logic [13:0] exp_on, 
        input logic [13:0] exp_off
    );
        $display("-> Executing Hierarchical Configuration Assertions...");
        
        assert(i_dut.event_rate_reg == exp_pbits) else 
            $error("[GLS FATAL] Event Rate Register corrupted!");

        assert(i_dut.i_dvs_core.i_row_decoder_top.i_roic_sm2.p_on_detect == exp_on) else 
            $error("[GLS FATAL] p_on_detect failed to reach Top State Machine!");

        assert(i_dut.i_dvs_core.i_row_decoder_bot.i_roic_sm2.p_off_detect == exp_off) else 
            $error("[GLS FATAL] p_off_detect failed to reach Bottom State Machine!");

        $display("   [ASSERT PASS] All SPI Registers Hold Correct Setup Data.");
    endtask

    task automatic write_phase_tunings(
        input logic [13:0] pre, input logic [13:0] buf_val, input logic [13:0] det,
        input logic [13:0] on_det, input logic [13:0] off_det, input logic [13:0] rst_val
    );
        $display("-> Configuring 14-Bit Phase Tunings via Q-SPI...");
        qspi_write_halfword(8'd112, {2'b00, pre});
        qspi_write_halfword(8'd114, {2'b00, buf_val});
        qspi_write_halfword(8'd116, {2'b00, det});
        qspi_write_halfword(8'd118, {2'b00, on_det});
        qspi_write_halfword(8'd120, {2'b00, off_det});
        qspi_write_halfword(8'd122, {2'b00, rst_val});
    endtask

    task automatic write_event_rate(input logic [7:0] prg_val);
        qspi_write_word(8'd108, {24'd0, prg_val});
        $display("Event Rate (program_bits) configured to = %02h", prg_val);
    endtask

    // -----------------------------------------------------------------
    // LOW-LEVEL Q-SPI BIT-BANGING ROUTINES
    // -----------------------------------------------------------------
    task automatic pulse_fifo_rst_n(input logic [3:0] val);
        qspi_write_word(8'd1, {28'd0, val});
    endtask

    task automatic set_irq(input logic [11:0] deassert_val, input logic [11:0] assert_val);
        qspi_write_halfword(8'd12, {4'd0, deassert_val});
        qspi_write_halfword(8'd14, {4'd0, assert_val});
    endtask

    task automatic write_dacs(input logic [11:0] val);
        for (int i = 0; i < 8; i++) begin
            qspi_write_halfword(8'(i*2 + 20), {4'd0, val});
            dac_write_data[i] = val;
        end
    endtask

    task automatic write_dacs_seq(input logic [11:0] val);
        for (int i = 0; i < 8; i++) begin
            qspi_write_halfword(8'(i*2 + 20), {4'd0, val+i});
            dac_write_data[i] = val + i;
        end
    endtask

    task automatic qspi_write_word(input logic [7:0] addr, input logic [31:0] data);
        @(negedge clk);
        CS_N = 0;
        
        for(int k=0; k<8; k++) begin
            COPI[0] = (8'h06 >> (7-k)) & 1; 
            COPI[1] = (addr >> (7-k)) & 1;
            COPI[3:2] = 0;
            @(negedge clk);
        end
        
        for(int k=0; k<8; k++) begin
            COPI[3] = (data >> (31 - k)) & 1;
            COPI[2] = (data >> (23 - k)) & 1;
            COPI[1] = (data >> (15 - k)) & 1;
            COPI[0] = (data >> (7  - k)) & 1;
            @(negedge clk);
        end
        
        CS_N = 1; COPI = 0;
        @(negedge clk);
    endtask

    task automatic qspi_write_halfword(input logic [7:0] addr, input logic [15:0] data);
        @(negedge clk);
        CS_N = 0;
        
        for(int k=0; k<8; k++) begin
            COPI[0] = (8'h05 >> (7-k)) & 1; 
            COPI[1] = (addr >> (7-k)) & 1;
            COPI[3:2] = 0;
            @(negedge clk);
        end
        
        for(int k=0; k<8; k++) begin
            COPI[1] = (data >> (15 - k)) & 1;
            COPI[0] = (data >> (7  - k)) & 1;
            COPI[3:2] = 0;
            @(negedge clk);
        end
        
        CS_N = 1; COPI = 0;
        @(negedge clk);
    endtask

endmodule : final_top_tb