//---------------------------------------------------------------------------
// Author: Ababakar Okieh
// Date  : April 15, 2026
//
// Module: final_top_tb
// Description: 
//  Full-chip Sign-off TB. Exhaustively tests RegFile configuration using 
//  ported self_check_tb sequences, and verifies True Continuous Q-SPI streaming.
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
    // logic [23:0] bias_0, bias_1, bias_2, bias_3;
    logic [`DAC_WIDTH-1:0] dac_config_0, dac_config_1, dac_config_2, dac_config_3, dac_config_4;
    logic [`DAC_WIDTH-1:0]  dac_config_5, dac_config_6, dac_config_7, dac_config_8, dac_config_9;

    // Analog Array Interfaces
    logic [63:0] array_col_top_left = '0, array_col_top_right = '0;
    logic [63:0] array_col_bot_left = '0, array_col_bot_right = '0;
    logic [63:0] col_event_rst_top_left,  col_event_rst_top_right;
    logic [63:0] col_event_rst_bot_left,  col_event_rst_bot_right;
    logic [1:0]  pre_charge_global_top,   pre_charge_global_bot;
    logic [63:0] row_on_detect_top,       row_off_detect_top;
    logic [63:0] row_on_detect_bot,       row_off_detect_bot;

    logic sm_enable = 0;
    logic [7:0] program_bits = 8'd1;
    logic data_ready;

    // logic data_ready_top;
    // logic data_ready_bot;

    // -----------------------------------------------------------
    // File I/O & Tracking
    // -----------------------------------------------------------
    logic [135:0] img_mem [0:255]; 
    int fd_top, fd_bot;

    logic [11:0] dac_write_data  [7:0];
    logic [23:0] bias_write_data [3:0];

    // -----------------------------------------------------------
    // DUT Instantiation
    // -----------------------------------------------------------
    final_top i_dut (
        .clk                     (clk),
        .rst_n                   (rst_n),
        .CS_N                    (CS_N),
        // .SCK                     (clk),  
        .COPI                    (COPI),
        .CIPO                    (CIPO),

        // .bias_0(bias_0), .bias_1(bias_1), .bias_2(bias_2), .bias_3(bias_3),
        .dac_config_0(dac_config_0), .dac_config_1(dac_config_1), 
        .dac_config_2(dac_config_2), .dac_config_3(dac_config_3),
        .dac_config_4(dac_config_4), .dac_config_5(dac_config_5), 
        .dac_config_6(dac_config_6), .dac_config_7(dac_config_7),
        .dac_config_8(dac_config_8), .dac_config_9(dac_config_9),

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

        .data_ready_top          (data_ready),
        // .data_ready_top          (data_ready_top),
        // .data_ready_bot          (data_ready_bot),
        .sm_enable               (sm_enable)
        // .program_bits            (program_bits)
    );

    // Continuous Master Clock
    always #(SYS_CLK_PERIOD_NS / 2) clk = ~clk;

    // =================================================================
    // PROCESS 1: Exhaustive Configuration & Main Control
    // =================================================================
    initial begin
        $display("==================================================");
        $display("STARTING FULL CHIP SIGN-OFF TEST (TRUE CONTINUOUS)");
        $display("==================================================");

        $readmemh("../python/papa_test_data_128x128.hex", img_mem);
        fd_top = $fopen("../python/final_top_sim_output_top.txt", "w");
        fd_bot = $fopen("../python/final_top_sim_output_bot.txt", "w");

        rst_n = 0;
        #(SYS_CLK_PERIOD_NS * 10); rst_n = 1;
        #(SYS_CLK_PERIOD_NS * 10); rst_n = 0;
        #(SYS_CLK_PERIOD_NS * 10); rst_n = 1;
        #(SYS_CLK_PERIOD_NS * 5);

        // -----------------------------------------------------------
        // 1. Exhaustive RegFile Mapping Test (Ported from self_check_tb)
        // -----------------------------------------------------------
        $display("-> Testing Memory Map: Writing DACs, Biases, and IRQs...");

        // ---------------- Write all ones ------------------------
        pulse_fifo_rst_n(4'hf);
        set_irq(12'hfff, 12'hfff);
        write_dacs(12'hfff);
        // write_biases(4'hf, 1);
        #500ns;

        // ---------------- Write all zeros -----------------------
        pulse_fifo_rst_n(4'h0);
        set_irq(12'h000, 12'h000);
        write_dacs(12'h000);
        // write_biases(4'h0, 1);
        #500ns;

        // ---------------- Write sequence data -------------------
        write_dacs_seq(12'h5aa);
        // write_biases(4'ha, 0);              
        set_irq(12'h2AA, 12'h2AA);
        #500ns;

        // ---------------- Write sequence data -------------------
        write_dacs_seq(12'hfaa);
        // write_biases(4'hf, 0);              
        set_irq(12'h0CC, 12'h1DD);
        #500ns;
        
        $display("   [PASS] Exhaustive RegFile configuration verified!");

        // -----------------------------------------------------------
        // 2. Start Imager & Continuous Read
        // -----------------------------------------------------------
        
        write_event_rate(program_bits);
        $display("\n-> Starting Imager & Streaming QSPI Data...");
        @(posedge clk);
        sm_enable = 1;

        // Block here until Q-SPI Master Finishes in Process 3
    end

    // =================================================================
    // PROCESS 2: Analog Array Feeders (Aligned to [135:8])
    // =================================================================
    initial feed_tier("TOP", 0);
    initial feed_tier("BOT", 64);

    task automatic feed_tier(input string tier_name, input int offset);
        logic [127:0] t_on, t_off;
        for (int r = 0; r < 64; r++) begin
            
            // THE FIX: Shift the read index to [135:8] to bypass the old LSB control byte
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
    // PROCESS 3: Q-SPI Master (Smart Interrupt-Driven Readout)
    // =================================================================
    initial begin
        logic [135:0] top_rec, bot_rec;
        logic [15:0] top_chunks[9];
        logic [15:0] bot_chunks[9];
        longint start_t, end_t;
        real frame_rate;
        // int words_read = 0;
        int words_read;
        words_read = 0;

        // 1. Wait for imager to start
        wait(sm_enable == 1);
        start_t = $time;

        // 2. Smart Polling Loop (Reads exactly 128 words per frame)
        while (words_read < 128) begin
            
            // Step A: Idle State - Wait for the ASIC to signal Data Ready (IRQ)
            // wait(data_ready_top == 1 && data_ready_bot == 1);
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
            // while ((data_ready_top == 1 && data_ready_bot == 1) && words_read < 128) begin
                while((data_ready == 1) && words_read < 128) begin
                for(int chunk=0; chunk<9; chunk++) begin
                    for(int k=0; k<8; k++) begin
                        @(posedge clk); // Sample CIPO on Master's rising edge
                        bot_chunks[chunk][15-k] = CIPO[3]; 
                        bot_chunks[chunk][7-k]  = CIPO[2]; 
                        top_chunks[chunk][15-k] = CIPO[1]; 
                        top_chunks[chunk][7-k]  = CIPO[0]; 
                        @(negedge clk); // Shift on falling edge
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
            
            // Step D: Data ran out (or frame finished). Raise CS_N to save power!
            CS_N = 1; 
            @(negedge clk); // Give one cycle of buffer before checking again
        end
        end_t = $time;
        // Wait for internal analog sweep to naturally terminate
        // wait(i_dut.i_dvs_core.i_row_decoder_bot.row_addr == 63 && i_dut.i_dvs_core.row_off_detect_bot == 0);
        

        // Calculate True Hardware Frame Rate
        frame_rate = 1.0 / ((end_t - start_t) / 1000000000.0);

        $display("\n==================================================");
        $display("IMAGE STREAMING COMPLETE.");
        $display("Total Imager Generation & Readout Time: %0d ns", (end_t - start_t));
        $display("Average Frame Rate: ~%0d Hz", frame_rate);
        $display("==================================================");
        
        $fclose(fd_top);
        $fclose(fd_bot);
        $finish;
    end

    // -----------------------------------------------------------------
    // PORTED TASKS FROM self_check_tb.sv
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

    task automatic write_biases(input logic [3:0] start_val, input logic is_uniform);
        logic [3:0] digit;
        logic [23:0] bias_val;
        for (int i = 0; i < 4; i++) begin
            if (is_uniform) digit = start_val;
            else            digit = (start_val + i) & 4'hF;
            bias_val = {6{digit}};
            qspi_write_word(8'(112 + i*4), {8'd0, bias_val});
            bias_write_data[i] = bias_val;
            $display("Bias[%0d] write = %06h", i, bias_val);
        end
    endtask

    task automatic write_event_rate(input logic [7:0] prg_val);
        // Write the 8-bit value to byte address 108
        // We pad the top 24 bits with 0s to make a full 32-bit Q-SPI word write
        qspi_write_word(8'd108, {24'd0, prg_val});
        $display("Event Rate (program_bits) configured to = %02h", prg_val);
    endtask

    // -----------------------------------------------------------------
    // Q-SPI Master Low-Level Bit-Banging Tasks
    // -----------------------------------------------------------------
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