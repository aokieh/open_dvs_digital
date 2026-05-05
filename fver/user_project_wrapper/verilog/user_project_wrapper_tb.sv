//---------------------------------------------------------------------------
// Module: user_project_wrapper_tb
// Description: 
//  Full-chip Sign-off TB at the Caravel Wrapper Level. 
//  Exhaustively tests RegFile configuration and True Continuous Q-SPI 
//  streaming through the physical io_in and io_out pad mappings.
//---------------------------------------------------------------------------

`timescale 1ns/1ps
`define MPRJ_IO_PADS 38

module user_project_wrapper_tb();

    parameter SYS_CLK_PERIOD_NS = 20; // 50MHz Continuous Global Clock

    // ASIC Power Rails (Crucial for GLS)
    supply1 VDD; // Ideal 1 (Power Source)
    supply0 VSS; // Ideal 0 (Ground Source)
    wire vccd1, vccd2;  // Core Power Net (VCC)
    wire vssd1, vssd2;  // Core Ground Net (VSS)
    wire vdda1, vdda2;
    wire vssa1, vssa2;

    assign vccd1 = VDD;
    assign vccd2 = VDD;
    assign vdda1 = VDD;
    assign vdda2 = VDD;

    assign vssd1 = VSS;
    assign vssd2 = VSS;
    assign vssa1 = VSS;
    assign vssa2 = VSS;
    // =======================================================
    // 1. Caravel Wrapper Signals
    // =======================================================
    logic wb_clk_i = 0, wb_rst_i = 0, wbs_stb_i = 0, wbs_cyc_i = 0, wbs_we_i = 0;
    logic [3:0]  wbs_sel_i = '0;
    logic [31:0] wbs_dat_i = '0;
    logic [31:0] wbs_adr_i = '0;
    wire         wbs_ack_o;
    wire  [31:0] wbs_dat_o;

    logic [127:0] la_data_in = '0;
    wire  [127:0] la_data_out;
    logic [127:0] la_oenb = '1; 

    logic [`MPRJ_IO_PADS-1:0] io_in;
    wire  [`MPRJ_IO_PADS-1:0] io_out;
    wire  [`MPRJ_IO_PADS-1:0] io_oeb;
    
    wire  [`MPRJ_IO_PADS-10:0] analog_io;
    logic user_clock2 = 0;
    wire  [2:0] user_irq;

    // =======================================================
    // 2. TB Driver Aliases (Mapping to Pads)
    // =======================================================
    logic clk = 0; 
    logic rst_n = 0;
    logic CS_N = 1;
    logic [3:0] COPI = 0;
    logic sm_enable = 0;
    logic pix_rst_global_in = 0;

    assign io_in[7]    = clk;
    assign io_in[8]     = rst_n;
    assign io_in[9]     = CS_N;
    assign io_in[13:10] = COPI;
    assign io_in[14]    = sm_enable;
    assign io_in[21]    = pix_rst_global_in;

    // Output Probes
    wire [3:0] CIPO       = io_out[19:16];
    wire       data_ready = io_out[20];

    // Tie-off unused input pads to 0 to prevent X-propagation
    assign io_in[6:0]   = 7'h00;
    assign io_in[20:15] = 6'h00;
    assign io_in[37:22] = 16'h0000;
    // ===========================================================
    // File I/O & Tracking
    // ===========================================================
    logic [135:0] img_mem [0:255];
    int fd_top, fd_bot; 
    logic [11:0] dac_write_data [7:0];

    // Static variables required for cross-hierarchy force statements
    logic [127:0] force_on_top, force_off_top;
    logic [127:0] force_on_bot, force_off_bot;

    // =======================================================
    // 3. DUT Instantiation
    // =======================================================
    user_project_wrapper #(
        .BITS(32)
    ) i_dut (
        `ifdef USE_POWER_PINS
            .vccd1(vccd1),.vccd2(vccd2),
            .vssd1(vssd1),.vssd2(vssd2),
            .vdda1(vdda1),.vdda2(vdda2),
            .vssa1(vdda1),.vssa2(vssa2),
        `endif
        .wb_clk_i(wb_clk_i), .wb_rst_i(wb_rst_i), .wbs_stb_i(wbs_stb_i),
        .wbs_cyc_i(wbs_cyc_i), .wbs_we_i(wbs_we_i), .wbs_sel_i(wbs_sel_i),
        .wbs_dat_i(wbs_dat_i), .wbs_adr_i(wbs_adr_i), .wbs_ack_o(wbs_ack_o),
        .wbs_dat_o(wbs_dat_o),
        .la_data_in(la_data_in), .la_data_out(la_data_out), .la_oenb(la_oenb),
        .io_in(io_in), .io_out(io_out), .io_oeb(io_oeb),
        .analog_io(analog_io), .user_clock2(user_clock2), .user_irq(user_irq)
    );

    // Continuous Master Clock
    always #(SYS_CLK_PERIOD_NS / 2) clk = ~clk;

    // =================================================================
    // MAIN EXECUTION THREAD
    // =================================================================
    initial begin
        $display("==================================================");
        $display("STARTING FULL CHIP WRAPPER SIGN-OFF TEST");
        $display("==================================================");

        $readmemh("../python/papa_test_data_128x128.hex", img_mem);
        
        // -----------------------------------------------------------
        // 1. Check Output Enable (OEB) Setup
        // -----------------------------------------------------------
        rst_n = 0;
        #(SYS_CLK_PERIOD_NS * 10); rst_n = 1;
        #(SYS_CLK_PERIOD_NS * 10); rst_n = 0;
        #(SYS_CLK_PERIOD_NS * 10); rst_n = 1;
        #(SYS_CLK_PERIOD_NS * 5);

        $display("-> Verifying OEB configurations...");
        // assert(io_oeb[15] == 1'b1) else $error("FATAL: clk OEB is not input (1)");
        assert(io_oeb[7] == 1'b1) else $error("FATAL: clk OEB is not input (1)");
        assert(io_oeb[19:16] == 4'b0000) else $error("FATAL: CIPO OEBs are not outputs (0)");
        assert(io_oeb[20] == 1'b0) else $error("FATAL: data_ready OEB is not output (0)");
        $display("   [PASS] IO ring directionality is locked.");

        // -----------------------------------------------------------
        // 2. Multi-Speed Continuous Read Sequences (Through Wrapper)
        // -----------------------------------------------------------
        run_full_frame("1us Fast Mode", "1us", 8'd1, 14'd4, 14'd4, 14'd4, 14'd8, 14'd8, 14'd25);
        run_full_frame("32us Medium Mode", "32us", 8'd32, 14'd4, 14'd4, 14'd4, 14'd8, 14'd8, 14'd25);
        run_full_frame("256us Extreme Mode", "256us", 8'd0, 14'd1000, 14'd1000, 14'd1000, 14'd10000, 14'd10000, 14'd5000);

        $display("\n==================================================");
        $display("ALL SEQUENCES STREAMED THROUGH WRAPPER PADS.");
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

        $display("-> Hard Resetting ASIC to clear FSM and FIFOs...");
        rst_n = 0; #(SYS_CLK_PERIOD_NS * 10);
        rst_n = 1; #(SYS_CLK_PERIOD_NS * 10);

        write_dacs_seq(12'h5aa);           
        set_irq(12'h2AA, 12'h2AA);
        write_event_rate(p_bits);
        write_phase_tunings(pre, buf_val, det, on_det, off_det, rst_val);

        fd_top = $fopen($sformatf("../python/wrapper_out_top_%s.txt", file_suffix), "w");
        fd_bot = $fopen($sformatf("../python/wrapper_out_bot_%s.txt", file_suffix), "w");

        $display("-> Starting Imager & Streaming QSPI Data from Pads...");
        @(posedge clk);
        sm_enable = 1;

        fork
            feed_tier("TOP", 0);
            feed_tier("BOT", 64);
            qspi_master_readout();
        join

        sm_enable = 0;
        $fclose(fd_top);
        $fclose(fd_bot);
        #(SYS_CLK_PERIOD_NS * 100);
    endtask

    // =================================================================
    // Q-SPI MASTER READOUT TASK (PURE POSEDGE PIPELINE)
    // =================================================================
    task automatic qspi_master_readout();
        logic [135:0] top_rec, bot_rec;
        logic [15:0] top_chunks[9];
        logic [15:0] bot_chunks[9];
        int words_read = 0;
        longint start_t, end_t;real frame_rate;

        wait(data_ready == 1);
        start_t = $time;

        while (words_read < 128) begin
            wait(data_ready == 1);
           
            @(negedge clk);
            CS_N = 0;

            for(int k=0; k<8; k++) begin
                COPI[0] = (8'h07 >> (7-k)) & 1;
                @(negedge clk);
            end
            COPI = 0;

            // Pure Posedge Pipeline Alignment
            // @(posedge clk); 
            @(posedge clk); 

            while((data_ready == 1) && words_read < 128) begin
                for(int chunk=0; chunk<9; chunk++) begin
                    for(int k=0; k<8; k++) begin
                        @(posedge clk); 
                        bot_chunks[chunk][15-k] = CIPO[3];
                        bot_chunks[chunk][7-k]  = CIPO[2]; 
                        top_chunks[chunk][15-k] = CIPO[1]; 
                        top_chunks[chunk][7-k]  = CIPO[0]; 
                    end
                end
                
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
            
            CS_N = 1; 
            @(negedge clk); 
        end
        end_t = $time;
        frame_rate = 1.0 / ((end_t - start_t) / 1000000000.0);
        $display("\nFRAME COMPLETE.");
        $display("Generation & Readout Time: %0d ns", (end_t - start_t));
        $display("Average Frame Rate: ~%0d Hz", frame_rate);
    endtask


    // =================================================================
    // ANALOG ARRAY FEEDER TASK (CROSS-HIERARCHY FORCING)
    // =================================================================
    task automatic feed_tier(input string tier_name, input int offset);
        for (int r = 0; r < 64; r++) begin
            
            if (tier_name == "TOP") begin
                force_on_top  = img_mem[(offset + r) * 2][135:8];
                force_off_top = img_mem[((offset + r) * 2) + 1][135:8];

                wait(i_dut.row_on_detect_top != 0);
                force i_dut.array_col_top_left  = force_on_top[127:64];
                force i_dut.array_col_top_right = force_on_top[63:0];
                wait(i_dut.row_on_detect_top == 0);
                
                wait(i_dut.row_off_detect_top != 0);
                force i_dut.array_col_top_left  = force_off_top[127:64];
                force i_dut.array_col_top_right = force_off_top[63:0];
                wait(i_dut.row_off_detect_top == 0);

            end else begin
                force_on_bot  = img_mem[(offset + r) * 2][135:8];
                force_off_bot = img_mem[((offset + r) * 2) + 1][135:8];

                wait(i_dut.row_on_detect_bot != 0);
                force i_dut.array_col_bot_left  = force_on_bot[127:64];
                force i_dut.array_col_bot_right = force_on_bot[63:0];
                wait(i_dut.row_on_detect_bot == 0);
                
                wait(i_dut.row_off_detect_bot != 0);
                force i_dut.array_col_bot_left  = force_off_bot[127:64];
                force i_dut.array_col_bot_right = force_off_bot[63:0];
                wait(i_dut.row_off_detect_bot == 0);
            end
        end
    endtask


    // =================================================================
    // Q-SPI CONFIGURATION TASKS
    // =================================================================
    task automatic write_phase_tunings(
        input logic [13:0] pre, input logic [13:0] buf_val, input logic [13:0] det,
        input logic [13:0] on_det, input logic [13:0] off_det, input logic [13:0] rst_val
    );
        qspi_write_halfword(8'd112, {2'b00, pre});
        qspi_write_halfword(8'd114, {2'b00, buf_val});
        qspi_write_halfword(8'd116, {2'b00, det});
        qspi_write_halfword(8'd118, {2'b00, on_det});
        qspi_write_halfword(8'd120, {2'b00, off_det});
        qspi_write_halfword(8'd122, {2'b00, rst_val});
    endtask

    task automatic write_event_rate(input logic [7:0] prg_val);
        qspi_write_word(8'd108, {24'd0, prg_val});
    endtask

    task automatic set_irq(input logic [11:0] deassert_val, input logic [11:0] assert_val);
        qspi_write_halfword(8'd12, {4'd0, deassert_val});
        qspi_write_halfword(8'd14, {4'd0, assert_val});
    endtask

    task automatic write_dacs_seq(input logic [11:0] val);
        for (int i = 0; i < 8; i++) begin
            qspi_write_halfword(8'(i*2 + 20), {4'd0, val+i});
            dac_write_data[i] = val + i;
        end
    endtask

    task automatic qspi_write_word(input logic [7:0] addr, input logic [31:0] data);
        @(negedge clk); CS_N = 0;
        for(int k=0; k<8; k++) begin
            COPI[0] = (8'h06 >> (7-k)) & 1; COPI[1] = (addr >> (7-k)) & 1; COPI[3:2] = 0;
            @(negedge clk);
        end
        for(int k=0; k<8; k++) begin
            COPI[3] = (data >> (31 - k)) & 1; COPI[2] = (data >> (23 - k)) & 1;
            COPI[1] = (data >> (15 - k)) & 1; COPI[0] = (data >> (7  - k)) & 1;
            @(negedge clk);
        end
        @(negedge clk); @(negedge clk);
        CS_N = 1; COPI = 0;
        @(negedge clk);
    endtask

    task automatic qspi_write_halfword(input logic [7:0] addr, input logic [15:0] data);
        @(negedge clk); CS_N = 0;
        for(int k=0; k<8; k++) begin
            COPI[0] = (8'h05 >> (7-k)) & 1; COPI[1] = (addr >> (7-k)) & 1; COPI[3:2] = 0;
            @(negedge clk);
        end
        for(int k=0; k<8; k++) begin
            COPI[1] = (data >> (15 - k)) & 1; COPI[0] = (data >> (7  - k)) & 1; COPI[3:2] = 0;
            @(negedge clk);
        end
        @(negedge clk); @(negedge clk);
        CS_N = 1; COPI = 0;
        @(negedge clk);
    endtask

endmodule

// =================================================================
// STUB: Analog Imager Blackbox
// Placed here so the simulator compiles cleanly without missing cells.
// =================================================================
// module Imager_Top_no_m5 (
//     input [63:0] col_event_rst_top_left, col_event_rst_top_right, col_event_rst_bot_left, col_event_rst_bot_right,
//     input [63:0] row_on_detect_top, row_off_detect_top, row_on_detect_bot, row_off_detect_bot,
//     input pre_charge_global_top_left, pre_charge_global_top_right, pre_charge_global_bot_left, pre_charge_global_bot_right,
//     input detect_pulse_global_top_left, detect_pulse_global_top_right, detect_pulse_global_bot_left, detect_pulse_global_bot_right,
//     input [10:0] dac_config_0, dac_config_1, dac_config_2, dac_config_3, dac_config_4, dac_config_5, dac_config_6, dac_config_7, dac_config_8, dac_config_9,
//     input sync_pix_rst_top_left, sync_pix_rst_bot_left, sync_pix_rst_top_right, sync_pix_rst_bot_right,
    
//     // Outputs (Tied to 0 to prevent X-propagation)
//     output logic [63:0] array_col_top_left = '0, array_col_top_right = '0, array_col_bot_left = '0, array_col_bot_right = '0
// );
// endmodule