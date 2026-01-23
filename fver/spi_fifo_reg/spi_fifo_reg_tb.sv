`timescale 1ns/1ps
import pkg_spi_fver::*;

module tb ();
    
    localparam CLK_P = 20ns;
    localparam DEPTH = 16;
    localparam DWIDTH = 136;

    logic clk  = 0;
    logic rst_n = 0;

    logic SCK;
    logic CS_N;
    logic [3:0] COPI; 
    logic [3:0] CIPO;
    logic                     wr_en_fifo;
    logic [   DWIDTH-1 : 0]   wdata_fifo_0, wdata_fifo_1;
    logic [1:0]               empty_fifo;
    logic [1:0]               full_fifo;
    logic [$clog2(DEPTH)-1:0] numel_fifo_0, numel_fifo_1;

    // Internal counters for FIFOs 
    logic [4:0] clk_cycle_cnt;  // count to 7, reset (8 total)
    logic [4:0] shift_cnt;      // count to 8, reset (9 total)

    // Dump variable for the data log file
    integer log_file;
    
    // Registers for error checking
    logic [11:0] dac_write_data     [7:0];
    logic [11:0] dac_read_data      [7:0];

    logic [23:0] bias_write_data    [3:0];
    logic [23:0] bias_read_data     [3:0];

    // Example on assigning random data to registers
    logic [11:0] irq_deassert_write_val = $random & 10'h3FF;
    logic [11:0] irq_assert_write_val   = $random & 10'h3FF;

    spi_intf i_spi_intf(
        .CS_N,
        .SCK ,
        .COPI,
        .CIPO
    );


    class_spi_ctrl spi_ctrl = new (i_spi_intf);

    always #(CLK_P/2) clk = ~clk;

    always @(negedge SCK) begin
    if (!CS_N)
        $fwrite(log_file, "%0t, %b\n", $time, CIPO);
    end

    // DUT instantiation
    spi_fifo_regfile  #(DWIDTH, DEPTH) i_spi_fifo_regfile(
        //Global Signals
        .SCK(SCK),
        .clk(clk),
        .rst_n(rst_n),
        
        // SPI Interface
        .CS_N(CS_N),
        .COPI(COPI), 
        .CIPO(CIPO),    

        // FIFO Signals
        .wr_en_fifo(wr_en_fifo),
        .wdata_fifo_0(wdata_fifo_0),
        .wdata_fifo_1(wdata_fifo_1),
        .empty_fifo(empty_fifo),
        .full_fifo(full_fifo),
        .numel_fifo_0(numel_fifo_0),
        .numel_fifo_1(numel_fifo_1)
    );

    // ---------------- Tasks and Verification Sequences ------------------


    task automatic write_data_fifo(int num = 1); //write to all FIFO addresses
        // Write a bunch of data to the FIFO
        $display("\nWriting a bunch of data to the FIFO...");

        wr_en_fifo = 0;
        // rd_en = 0;

        for (int i = 0; i < num; i++) begin
            @(posedge clk);
            #20ns;
            wr_en_fifo = 1;
            // wdata_fifo = $urandom_range(0, (2**FIFO_DWIDTH)-1);
            // write the fifo_addr number in the last write
            // wdata_fifo = {$urandom(), $urandom(), $urandom(), $urandom(), i[7:0]};
            // wdata_fifo = {(16){8'hAA}, i[7:0]};
            wdata_fifo_0 = {{16{8'hAA}}, i[7:0]};
            wdata_fifo_1 = {{16{8'hBB}}, i[7:0]}; 
            // wdata_fifo = { $urandom(), $urandom(), $urandom(), $urandom(), $urandom() };
            $display("\ni = %2d  Writing data = %h", i, wdata_fifo_0);
            $display("i = %2d  Writing data = %h", i, wdata_fifo_1);

            @(posedge clk);
            #20ns;
            wr_en_fifo = 0;
        end

        wr_en_fifo = 0;
        // rd_en = 0;
    endtask : write_data_fifo

    task automatic read_data_fifo();
        spi_ctrl.trans(READ_FIFO, 0, 0); //addr, data don't matter
        #CLK_P;
    endtask : read_data_fifo

    task automatic read_complete_fifo();   
        // read_data_fifo();
         for (int q = 0; q < 16; q++) begin
            $display ("     \n\nq=%h", q[7:0]);
            spi_ctrl.trans(READ_FIFO, 0, q[7:0]); //addr, data don't matter
            #CLK_P;
            #20;
         end
    endtask : read_complete_fifo

    task automatic pulse_fifo_rst_n(input logic [3:0] val);
        spi_ctrl.trans(WRITE_BT, 1, val);
        #CLK_P;
    endtask

    task automatic set_irq(input logic [11:0] deassert_val, input logic [11:0] assert_val, input logic mode_read);
            spi_ctrl.trans(WRITE_HW, 12, deassert_val);
            #CLK_P;
            spi_ctrl.trans(WRITE_HW, 14, assert_val);
            #CLK_P;
        if(mode_read) begin
            spi_ctrl.trans(READ_HW, 12, 0, deassert_val);
            #CLK_P;
            spi_ctrl.trans(READ_HW, 14, 0, assert_val);
            #CLK_P;
        end 
    endtask

    task automatic write_dacs(input logic [11:0] val, input logic mode_read);
        for (int i = 0; i < `NUM_DACS; i++) begin
            spi_ctrl.trans(WRITE_HW, i*2 + 20, val);
            dac_write_data[i] = val;
            #CLK_P;
        end
        if (mode_read) begin
            for (int i = 0; i < `NUM_DACS; i++) begin
                spi_ctrl.trans(READ_HW, i*2 + 20, 0, val);
                // dac_write_data[i] = val;
                #CLK_P;
            end
        end
    endtask

    task automatic read_dacs(input logic [11:0] val);
        for (int i = 0; i < `NUM_DACS; i++) begin
            spi_ctrl.trans(WRITE_HW, i*2 + 20, val+i);
            dac_write_data[i] = val;
            #CLK_P;
        end
        
        for (int i = 0; i < `NUM_DACS; i++) begin
            spi_ctrl.trans(READ_HW, i*2 + 20, 0, val+i);
            #CLK_P;
        end
    endtask

    task automatic write_dacs_seq();
        for (int i = 0; i < 10; i++) begin
            spi_ctrl.trans(WRITE_HW, i*2 + 20, 'h5aa + i);
            dac_write_data[i] = 'h5aa + i;
            #CLK_P;
        end
    endtask

    task automatic write_biases(input logic [3:0] start_val, input logic is_uniform, input logic mode_read);
        logic [3:0] digit;
        logic [23:0] bias_val;
        for (int i = 0; i < `NUM_BIASES; i++) begin
            if (is_uniform)
                digit = start_val;
            else
                digit = (start_val + i) & 4'hF;

            bias_val = {6{digit}};
            spi_ctrl.trans(WRITE_WD, 112 + i*4, bias_val);
            bias_write_data[i] = bias_val;
            $display("Bias[%0d] write = %06h", i, bias_val);
            #CLK_P;
        end

        for (int i = 0; i < `NUM_BIASES; i++) begin
            if(mode_read) begin
                if (is_uniform)
                    digit = start_val;
                else
                    digit = (start_val + i) & 4'hF;
                bias_val = {6{digit}};
                spi_ctrl.trans(READ_WD, 112 + i*4, 0, bias_val);
                bias_write_data[i] = bias_val;
                $display("Bias[%0d] write = %06h", i, bias_val);
                #CLK_P;
            end
        end
    endtask

    // task automatic read_full_depth();
    //     int i = 0;

    //     // Read a bunch of data from the FIFO
    //     $display("\nReading a bunch of data from the FIFO...");
        
    //     wr_en_fifo = 0;
    //     // rd_en = 0;
    //     // shift_en = 0;

    //     // for (int i = 0; i < (FIFO_DEPTH+2); i++) begin
    //     while (!empty_fifo) begin
    //         @(posedge clk);
    //         #0.1ns;
    //         // rd_en = 1;
    //         // shift_en = 1;
    //         $display("i = %2d  Reading data = %h", i, rdata_spi);

    //         i++;

    //         @(posedge clk);
    //         #0.1ns;
    //         // rd_en = 0;
    //         // shift_en = 0;
    //     end

    //     wr_en_fifo = 0;
    //     // rd_en = 0;
    //     // shift_en = 0;
    // endtask : read_full_depth

    // // not needed here, shift & read handled by spi
    // task automatic shifting_sequence(); //pulsing shift_en
    //     // 6 cycles low
    //     for (int j = 0; j < 6; j++) begin
    //         @(posedge clk);
    //         #0.1ns;
    //         clk_cycle_cnt = j[4:0];
    //         // shift_en = 0;
    //     end
    //     // 1 cycle high (shift)
    //     @(posedge clk);
    //     #0.1ns;
    //     clk_cycle_cnt = clk_cycle_cnt + 1;
    //     // shift_en = 1;
    //     shift_cnt = shift_cnt + 1;
        
    //     // interleaved, next row data + last shift out
    //     @(posedge clk);
    //     #0.1ns;
    //     clk_cycle_cnt = clk_cycle_cnt + 1;
    //     // shift_en = 0;  // deassert!
    // endtask

    // task automatic read_row_data();
    //     // For 9 shifts (one full FIFO row)
    //     for (int s = 0; s < 9; s++) begin
    //         shifting_sequence();
    //     end
    // endtask


        // --------------------- Test Sequence ------------------------------
    initial begin
        //TODO: add correct sdf files for top all blocks 
        
                // For corner: max_ff_n40C_1v95
        // $sdf_annotate("/home/aokieh1/projects/digital_top_hardened_macro/openlane/digital_top/runs/antenna_clean/final/sdf/max_ff_n40C_1v95/digital_top__max_ff_n40C_1v95.sdf", i_digital_top);
        
                // For corner: max_ss_100C_1v60
        // $sdf_annotate("/home/aokieh1/projects/digital_top_hardened_macro/openlane/digital_top/runs/antenna_clean/final/sdf/max_ss_100C_1v60/digital_top__max_ss_100C_1v60.sdf", i_digital_top);
        
                // For corner: max_tt_025C_1v80
        // $sdf_annotate("/home/aokieh1/projects/digital_top_hardened_macro/openlane/digital_top/runs/antenna_clean/final/sdf/max_tt_025C_1v80/digital_top__max_tt_025C_1v80.sdf", i_digital_top);
        
                // For corner: min_ff_n40C_1v95
        // $sdf_annotate("/home/aokieh1/projects/digital_top_hardened_macro/openlane/digital_top/runs/antenna_clean/final/sdf/min_ff_n40C_1v95/digital_top__min_ff_n40C_1v95.sdf", i_digital_top);
        
                // For corner: min_ss_100C_1v60
        // $sdf_annotate("/home/aokieh1/projects/digital_top_hardened_macro/openlane/digital_top/runs/antenna_clean/final/sdf/min_ss_100C_1v60/digital_top__min_ss_100C_1v60.sdf", i_digital_top);
        
                // For corner: min_tt_025C_1v80
        // $sdf_annotate("/home/aokieh1/projects/digital_top_hardened_macro/openlane/digital_top/runs/antenna_clean/final/sdf/min_tt_025C_1v80/digital_top__min_tt_025C_1v80.sdf", i_digital_top);
        
                // For corner: nom_ff_n40C_1v95
        // $sdf_annotate("/home/aokieh1/projects/digital_top_hardened_macro/openlane/digital_top/runs/antenna_clean/final/sdf/nom_ff_n40C_1v95/digital_top__nom_ff_n40C_1v95.sdf", i_digital_top);
        
                // For corner: nom_ss_100C_1v60
        // $sdf_annotate("/home/aokieh1/projects/digital_top_hardened_macro/openlane/digital_top/runs/antenna_clean/final/sdf/nom_ss_100C_1v60/digital_top__nom_ss_100C_1v60.sdf", i_digital_top);
        
                // For corner: nom_tt_025C_1v80
        // $sdf_annotate("/home/aokieh1/projects/digital_top_hardened_macro/openlane/digital_top/runs/antenna_clean/final/sdf/nom_tt_025C_1v80/digital_top__nom_tt_025C_1v80.sdf", i_digital_top);
        log_file = $fopen("spi_cipo_monitor.txt", "w");
        spi_ctrl.init();
        

        // Reset sequence
        #(10*CLK_P); rst_n = 1;
        #(10*CLK_P); rst_n = 0;
        #(10*CLK_P); rst_n = 1;
        #(5*CLK_P);


        $display("Starting FIFO testbench...");

        // Reset FIFO
        rst_n = 0;
        wr_en_fifo = 0;
        // rd_en = 0;
        clk_cycle_cnt = 0;
        shift_cnt = 0;
        
        // initializing data busses
        // rdata_spi = 0;
        // wdata_fifo = 0;


        #10;
        rst_n = 1;

        // Check for empty flag
        $display("Empty flag = %b", empty_fifo);

        // Check for full flag
        $display("Full flag = %b", full_fifo);

        // Write a bunch of data to the FIFO
        write_data_fifo(DEPTH);
        // write_data_fifo(2);
        clk_cycle_cnt = 0; //resetting counters
        shift_cnt = 0;

        #20;
        read_complete_fifo();
        // read_data_fifo();
        // #50;

        // read_data_fifo();
        // #20;
        // $display("Empty flag = %b", empty_fifo);

        // // Check for full flag
        // $display("Full flag = %b", full_fifo);

        // clk_cycle_cnt = 0; //resetting counters
        // shift_cnt = 0;
        // #20;
        // read_data_fifo();

        // #20;

        // // Check for full flag
        // #20;
        
        // $display("Full flag = %b", full_fifo);
        // #20;
        
        // $fclose(log_file);

        // Register file 
                // ---------------- Write all ones ------------------------
        pulse_fifo_rst_n('hf);
        set_irq('hfff, 'hfff, 0);
        write_dacs('hfff, 0);
        write_biases(4'hf, 1, 0);
        #500ns;

        // ---------------- Write all zeros -----------------------
        pulse_fifo_rst_n('h0);
        set_irq('h000, 'h000, 0);
        write_dacs('h000, 0);
        write_biases(4'h0, 1, 0);
        #500ns;

        // ---------------- Write sequence data -------------------
        write_dacs_seq();
        write_biases(4'ha, 0, 0);              // starts A, increments
        set_irq('h2AA, 'h2AA, 0);
        #500ns;

        // ---------------- Read and dump comparison --------------
        // Read Chip ID
        spi_ctrl.trans(READ_BT, 0, 0, 'h55);
        #CLK_P;

        set_irq(irq_deassert_write_val, irq_assert_write_val, 1);
        read_dacs('h100);   //writes consecutive data to dacs & reads
        write_biases(4'h3, 0, 1);  //write and read beginning at 333333

        #300ns;
        
        $fclose(log_file);
        $stop; //end of top-level testbench 
    end

endmodule : tb