//---------------------------------------------------------------------------
// Author: Ababakar Okieh
// Date  : Mar 11, 2025
//
// Module: async_fifo_top_tb
//
// Description: 
//  Testbench for asynchronous FIFO.
//---------------------------------------------------------------------------


module tb();
    //Global design signals
    `ifndef USE_POWER_PINS
        logic vccd1_dummy = 1'b1;
        logic vssd1_dummy = 1'b0;
    `endif
    parameter CLK_P = 20;
    logic clk = 0, rst_n = 0;
    

    // FIFO signals
    logic data_ack, data_req = 0;
    logic [`FIFO_WIDTH_ASYNC-1:0] wdata_async = '0;

    // Asynchronous Interface
    logic empty_fifo, full_fifo;
    logic [`FIFO_AWIDTH_ASYNC-1:0] numel_fifo;

    // SPI Interface
    logic fifo_rd_en = 0;
    logic [`FIFO_WIDTH_ASYNC-1:0] async_rdata_spi;


async_fifo_top i_async_fifo_top(

    `ifdef USE_POWER_PINS
        .vccd1(vccd1_dummy),
        .vssd1(vssd1_dummy),
    `endif

    .clk,
    .rst_n,

    // FIFO signals
    .empty_fifo,
    .full_fifo,
    .numel_fifo,

    // Asynchronous Interface
    .wdata_async,
    .data_req,
    .data_ack,

    // SPI Interface
    .fifo_rd_en,
    .async_rdata_spi
);


    // Clock generation: 50MHz operation = 20ns period
    always begin
        #10 clk = ~clk;
    end

    // --------------------- Test Sequence ------------------------------
    initial begin

        $display("\n\nStarting FIFO testbench...");

        // Reset FIFO
        rst_n = 0;
        fifo_rd_en = 0;

        #80;
        rst_n = 1;

        // // Check for empty flag
        // $display("Empty flag = %b", empty_fifo);

        // // Check for full flag
        // $display("Full flag = %b", full_fifo);

        display_flags();

        // Write a bunch of data to the FIFO
        write_data(`FIFO_DEPTH_ASYNC+10);
        display_flags();

        #500;

        // Read a bunch of data from the FIFO
        read_data(`FIFO_DEPTH_ASYNC);
        display_flags();

        $finish;

    end


    task automatic write_data(int num = 0); //write to all FIFO addresses
        // Write a bunch of data to the FIFO
        $display("\nWriting a bunch of data to the FIFO...");

        for (int i = 0; i < num; i++) begin
            @(posedge clk);
            #2.5ns; //off cycle to see synchronization
            data_req = 1;
            // wdata = $urandom_range(0, (2**FIFO_DWIDTH)-1);
            // write the fifo_addr number in the last write
            // wdata_fifo = {$urandom(), $urandom(), $urandom(), $urandom(), i[7:0]};
            wdata_async = {$urandom()};
            // wdata = { $urandom(), $urandom(), $urandom(), $urandom(), $urandom() };
            $display("i = %2d  Writing data = %h", i, wdata_async);

            wait(data_ack);

            @(posedge clk);
            data_req = 0;
            #(3 * CLK_P);
        end

        $display("\n...... Completed writing to FIFO ......");
    endtask : write_data

    task automatic read_data(int num = 0); //write to all FIFO addresses
        // Write a bunch of data to the FIFO
        $display("\nReading a bunch of data from the FIFO...");

        for (int i = 0; i < num; i++) begin
            @(posedge clk);
            // #2.5ns; //off cycle to see synchronization
            fifo_rd_en = 1;
            // wdata = $urandom_range(0, (2**FIFO_DWIDTH)-1);
            // write the fifo_addr number in the last write
            // wdata_fifo = {$urandom(), $urandom(), $urandom(), $urandom(), i[7:0]};
            // wdata_async = {$urandom()};
            // wdata = { $urandom(), $urandom(), $urandom(), $urandom(), $urandom() };
            $display("i = %2d  Reading data = %h", i, async_rdata_spi);

            // wait(data_ack);

            @(posedge clk);
            fifo_rd_en = 0;
            #(3 * CLK_P);
        end

        $display("\n...... Completed reading from FIFO ......\n\n");
    endtask : read_data
        
    task automatic display_flags();
                // Check for empty flag
        $display("Empty flag = %b", empty_fifo);

        // Check for full flag
        $display("Full flag = %b", full_fifo);
    endtask : display_flags
endmodule : tb
