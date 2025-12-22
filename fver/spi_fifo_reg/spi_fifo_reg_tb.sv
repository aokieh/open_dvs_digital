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
    logic                   wr_en_fifo;
    logic [   DWIDTH-1 : 0] wdata_fifo;
    logic                   empty_fifo;
    logic                   full_fifo;
    logic [$clog2(DEPTH)-1:0] numel_fifo;

    // Internal counters for FIFOs 
    logic [4:0] clk_cycle_cnt;  // count to 7, reset (8 total)
    logic [4:0] shift_cnt;      // count to 8, reset (9 total)

    // Dump variable for the data log file
    integer log_file;
    
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
        .wdata_fifo(wdata_fifo),
        .empty_fifo(empty_fifo),
        .full_fifo(full_fifo),
        .numel_fifo(numel_fifo)
    );

    // ---------------- Tasks and Verification Sequences ------------------


    task automatic write_data_fifo(int num = 1); //write to all FIFO addresses
        // Write a bunch of data to the FIFO
        $display("\nWriting a bunch of data to the FIFO...");

        wr_en_fifo = 0;
        // rd_en = 0;

        for (int i = 0; i < num; i++) begin
            @(posedge clk);
            #0.1ns;
            wr_en_fifo = 1;
            // wdata_fifo = $urandom_range(0, (2**FIFO_DWIDTH)-1);
            // write the fifo_addr number in the last write
            wdata_fifo = {$urandom(), $urandom(), $urandom(), $urandom(), i[7:0]};
            // wdata_fifo = { $urandom(), $urandom(), $urandom(), $urandom(), $urandom() };
            $display("i = %2d  Writing data = %h", i, wdata_fifo);

            @(posedge clk);
            #0.1ns;
            wr_en_fifo = 0;
        end

        wr_en_fifo = 0;
        // rd_en = 0;
    endtask : write_data_fifo

    task automatic read_data_fifo();
        spi_ctrl.trans(READ_FIFO, 0, 0); //addr, data don't matter
        #CLK_P;
    endtask : read_data_fifo


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
        // write_data_fifo(DEPTH);
        write_data_fifo(1);
        clk_cycle_cnt = 0; //resetting counters
        shift_cnt = 0;

        #20;
        
        read_data_fifo();
        #20;
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
        
        $fclose(log_file);
        $stop; //end of top-level testbench 
    end

endmodule : tb