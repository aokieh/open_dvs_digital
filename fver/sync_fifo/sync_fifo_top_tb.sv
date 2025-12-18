//---------------------------------------------------------------------------
// Author: Kwesi Buabeng Debrah
// Date  : Mar 3, 2025
//
// Module: sync_fifo_tb
//
// Description: 
//  Testbench for synchronous FIFO.
//---------------------------------------------------------------------------


module tb();

    // Parameters
    parameter FIFO_DWIDTH = 136;
    parameter FIFO_DEPTH  =  16;

    // Inputs
    logic clk = 0, rst_n = 0;
    logic wr_en = 0, shift_en = 0;

    logic [FIFO_DWIDTH-1:0] wdata = 0;
    // logic [FIFO_DWIDTH-1:0] rdata;
    logic [$clog2(FIFO_DEPTH):0] numel;
    logic empty, full;
    logic [15:0] rdata_spi;


    logic [4:0] clk_cycle_cnt;  // count to 7, reset (8 total)
    logic [4:0] shift_cnt;      // count to 8, reset (9 total)
    // Instantiate the sync_fifo module
    sync_fifo_top #(FIFO_DWIDTH, FIFO_DEPTH) i_sync_fifo_top (
        .clk,
        .rst_n,
        .wr_en,
        // .rd_en,
        .wdata,
        .empty,
        .full,
        .numel,
        .shift_en,
        .rdata_spi
    );


    // Clock generation: 50MHz operation = 20ns period
    always begin
        #10 clk = ~clk;
    end

    // --------------------- Test Sequence ------------------------------
    initial begin

        $display("Starting FIFO testbench...");

        // Reset FIFO
        rst_n = 0;
        wr_en = 0;
        // rd_en = 0;
        clk_cycle_cnt = 0;
        shift_cnt = 0;
        
        // initializing data busses
        // rdata_spi = 0;
        // wdata = 0;


        #10;
        rst_n = 1;

        // Check for empty flag
        $display("Empty flag = %b", empty);

        // Check for full flag
        $display("Full flag = %b", full);

        // Write a bunch of data to the FIFO
        // write_data(FIFO_DEPTH);
        write_data(2);
        read_row_data();
        clk_cycle_cnt = 0;
        shift_cnt = 0;
        #20;
        read_row_data();

        #20;

        // Check for full flag
        #20;
        
        $display("Full flag = %b", full);
        #20;
        
        $stop;
        
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
        // write_data(FIFO_DEPTH);
        write_data(1);

        // Check for full flag
        $display("Full flag = %b", full);

        #20;
        
        // Read a bunch of data from the FIFO
        read_full_depth();
        
        #10;
        $finish;

    end


    task automatic write_data(int num = 1); //write to all FIFO addresses
        // Write a bunch of data to the FIFO
        $display("\nWriting a bunch of data to the FIFO...");

        wr_en = 0;
        // rd_en = 0;

        for (int i = 0; i < num; i++) begin
            @(posedge clk);
            #0.1ns;
            wr_en = 1;
            // wdata = $urandom_range(0, (2**FIFO_DWIDTH)-1);
            // write the fifo_addr number in the last write
            wdata = {$urandom(), $urandom(), $urandom(), $urandom(), i[7:0]};
            // wdata = { $urandom(), $urandom(), $urandom(), $urandom(), $urandom() };
            $display("i = %2d  Writing data = %h", i, wdata);

            @(posedge clk);
            #0.1ns;
            wr_en = 0;
        end

        wr_en = 0;
        // rd_en = 0;
    endtask : write_data


    task automatic read_full_depth();
        int i = 0;

        // Read a bunch of data from the FIFO
        $display("\nReading a bunch of data from the FIFO...");
        
        wr_en = 0;
        // rd_en = 0;
        shift_en = 0;

        // for (int i = 0; i < (FIFO_DEPTH+2); i++) begin
        while (!empty) begin
            @(posedge clk);
            #0.1ns;
            // rd_en = 1;
            shift_en = 1;
            $display("i = %2d  Reading data = %h", i, rdata_spi);

            i++;

            @(posedge clk);
            #0.1ns;
            // rd_en = 0;
            shift_en = 0;
        end

        wr_en = 0;
        // rd_en = 0;
        shift_en = 0;
    endtask : read_full_depth

    // task automatic shifting_sequence();
    //     for (int j = 0; j < 7; j++) begin
    //         @(posedge clk);
    //         #0.1ns;
    //         if (j < 6) begin
    //             shift_en = 0;
    //         end
    //         else begin
    //             shift_en = 1;  //hold for 1 clk cycle [6-->7]
    //             shift_cnt = shift_cnt + 1;
    //         end
    //     end
    // endtask : shifting_sequence

    task automatic shifting_sequence(); //pulsing shift_en
        // 6 cycles low
        for (int j = 0; j < 6; j++) begin
            @(posedge clk);
            #0.1ns;
            clk_cycle_cnt = j[4:0];
            shift_en = 0;
        end
        // 1 cycle high (shift)
        @(posedge clk);
        #0.1ns;
        clk_cycle_cnt = clk_cycle_cnt + 1;
        shift_en = 1;
        shift_cnt = shift_cnt + 1;
        
        // interleaved, next row data + last shift out
        @(posedge clk);
        #0.1ns;
        clk_cycle_cnt = clk_cycle_cnt + 1;
        shift_en = 0;  // deassert!
    endtask

    task automatic read_row_data();
        // For 9 shifts (one full FIFO row)
        for (int s = 0; s < 9; s++) begin
            shifting_sequence();
        end
    endtask

endmodule : tb
