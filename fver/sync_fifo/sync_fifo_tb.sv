//---------------------------------------------------------------------------
// Author: Kwesi Buabeng Debrah
// Date  : Mar 3, 2025
//
// Module: sync_fifo_tb
//
// Description: 
//  Testbench for synchronous FIFO.
//---------------------------------------------------------------------------


module sync_fifo_tb();

    // Parameters
    // parameter FIFO_DWIDTH = 16;
    // parameter FIFO_DEPTH  =  8;
    parameter FIFO_DWIDTH = 64;
    parameter FIFO_DEPTH  =  16;

    // Inputs
    logic clk = 0, rst_n = 0;
    logic wr_en = 0, rd_en = 0;
    logic [FIFO_DWIDTH-1:0] wdata = 0;
    logic [FIFO_DWIDTH-1:0] rdata;
    logic [$clog2(FIFO_DEPTH):0] numel;
    logic empty, full;


    // Instantiate the sync_fifo module
    sync_fifo #(FIFO_DWIDTH, FIFO_DEPTH) i_fifo (
        .clk,
        .rst_n,
        .wr_en,
        .rd_en,
        .wdata,
        .empty,
        .full,
        .numel,
        .rdata
    );


    // Clock generation
    always begin
        #5 clk = ~clk;
    end


    initial begin
        $display("Starting FIFO testbench...");

        // Reset FIFO
        rst_n = 0;
        wr_en = 0;
        rd_en = 0;
        #10;
        rst_n = 1;

        // Check for empty flag
        $display("Empty flag = %b", empty);

        // Check for full flag
        $display("Full flag = %b", full);

        // Write a bunch of data to the FIFO
        write_data(FIFO_DEPTH);

        #20;

        // Check for full flag
        $display("Full flag = %b", full);

        // Read a bunch of data from the FIFO
        read_full_depth();

        // Check for empty flag
        $display("Empty flag = %b", empty);

        // Check for full flag
        $display("Full flag = %b", full);


        #20;

        $stop;

        #20;


        // Write some data to the FIFO
        $display("\nWriting and reading a few data to/from the FIFO...");
        write_data(5);

        // Check for full flag
        $display("Full flag = %b", full);

        // Read a bunch of data from the FIFO
        read_full_depth();

        // Check for empty flag
        $display("Empty flag = %b", empty);


        #20;

        $stop;

        #20;


        // Write a bunch of data to the FIFO
        write_data(FIFO_DEPTH);

        // Check for full flag
        $display("Full flag = %b", full);

        #20;
        
        // Read a bunch of data from the FIFO
        read_full_depth();
        
        #10;
        $finish;

    end


    task automatic write_data(int num = 1);
        // Write a bunch of data to the FIFO
        $display("\nWriting a bunch of data to the FIFO...");

        wr_en = 0;
        rd_en = 0;

        for (int i = 0; i < num; i++) begin
            @(posedge clk);
            #0.1ns;
            wr_en = 1;
            wdata = $urandom_range(0, (2**FIFO_DWIDTH)-1);
            $display("i = %2d  Writing data = %h", i, wdata);

            @(posedge clk);
            #0.1ns;
            wr_en = 0;
        end

        wr_en = 0;
        rd_en = 0;
    endtask : write_data


    task automatic read_full_depth();
        int i = 0;

        // Read a bunch of data from the FIFO
        $display("\nReading a bunch of data from the FIFO...");
        
        wr_en = 0;
        rd_en = 0;

        // for (int i = 0; i < (FIFO_DEPTH+2); i++) begin
        while (!empty) begin
            @(posedge clk);
            #0.1ns;
            rd_en = 1;
            $display("i = %2d  Reading data = %h", i, rdata);

            i++;

            @(posedge clk);
            #0.1ns;
            rd_en = 0;
        end

        wr_en = 0;
        rd_en = 0;
    endtask : read_full_depth

endmodule : sync_fifo_tb
