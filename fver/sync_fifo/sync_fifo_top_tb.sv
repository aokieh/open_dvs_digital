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
    logic wr_en_fifo = 0, shift_en_fifo = 0;

    logic [FIFO_DWIDTH-1:0] wdata_fifo = 0;
    // logic [FIFO_DWIDTH-1:0] rdata;
    logic [$clog2(FIFO_DEPTH)-1:0] numel_fifo;
    logic empty_fifo, full_fifo;
    logic [15:0] rdata_spi;


    logic [4:0] clk_cycle_cnt;  // count to 7, reset (8 total)
    logic [4:0] shift_cnt;      // count to 8, reset (9 total)
    // Instantiate the sync_fifo module
    sync_fifo_top i_sync_fifo_top (
        .clk,
        .rst_n,
        .wr_en_fifo,
        // .rd_en,
        .wdata_fifo,
        .empty_fifo,
        .full_fifo,
        .numel_fifo,
        .shift_en_fifo,
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
        wr_en_fifo = 0;
        clk_cycle_cnt = 0;
        shift_cnt = 0;


        #10;
        rst_n = 1;

        // Check for empty flag
        $display("Empty flag = %b", empty_fifo);

        // Check for full flag
        $display("Full flag = %b", full_fifo);

        // Write a bunch of data to the FIFO
        write_data(FIFO_DEPTH);
        $display("Full flag = %b", full_fifo);
        // write_data(15);
        read_row_data();
        clk_cycle_cnt = 0;
        shift_cnt = 0;
        #20;
        read_row_data();

        #20;

        // Check for full flag
        #20;
        
        $display("Full flag = %b", full_fifo);
        #20;
        
        $stop;
        
        // Read a bunch of data from the FIFO
        read_full_depth();

        // Check for empty flag
        $display("Empty flag = %b", empty_fifo);

        // Check for full flag
        $display("Full flag = %b", full_fifo);


        #20;

        $stop;

        #20;


        // Write some data to the FIFO
        $display("\nWriting and reading a few data to/from the FIFO...");
        write_data(5);

        // Check for full flag
        $display("Full flag = %b", full_fifo);

        // Read a bunch of data from the FIFO
        read_full_depth();

        // Check for empty flag
        $display("Empty flag = %b", empty_fifo);


        #20;

        $stop;

        #20;


        // Write a bunch of data to the FIFO
        // write_data(FIFO_DEPTH);
        write_data(1);

        // Check for full flag
        $display("Full flag = %b", full_fifo);

        #20;
        
        // Read a bunch of data from the FIFO
        read_full_depth();
        
        #10;
        $finish;

    end


    task automatic write_data(int num = 15); //write to all FIFO addresses
        // Write a bunch of data to the FIFO
        $display("\nWriting a bunch of data to the FIFO...");

        wr_en_fifo = 0;
        // rd_en = 0;

        for (int i = 0; i < num; i++) begin
            @(posedge clk);
            #10ns;
            wr_en_fifo = 1;
            // wdata = $urandom_range(0, (2**FIFO_DWIDTH)-1);
            // write the fifo_addr number in the last write
            // wdata_fifo = {$urandom(), $urandom(), $urandom(), $urandom(), i[7:0]};
            wdata_fifo = {32'hAAAA_AAAA, 32'hAAAA_AAAA, 32'hBBBB_BBBB, 32'hBBBB_BBBB, i[7:0]};
            // wdata = { $urandom(), $urandom(), $urandom(), $urandom(), $urandom() };
            $display("i = %2d  Writing data = %h", i, wdata_fifo);

            @(posedge clk);
            #10ns;
            wr_en_fifo = 0;
        end

        wr_en_fifo = 0;
        // rd_en = 0;
    endtask : write_data


    task automatic read_full_depth();
        int i = 0;

        // Read a bunch of data from the FIFO
        $display("\nReading a bunch of data from the FIFO...");
        
        wr_en_fifo = 0;
        // rd_en = 0;
        shift_en_fifo = 0;

        // for (int i = 0; i < (FIFO_DEPTH+2); i++) begin
        while (!empty_fifo) begin
            @(posedge clk);
            #10ns;
            // rd_en = 1;
            shift_en_fifo = 1;
            $display("i = %2d  Reading data = %h", i, rdata_spi);

            i++;

            @(posedge clk);
            #10ns;
            // rd_en = 0;
            shift_en_fifo = 0;
        end

        wr_en_fifo = 0;
        // rd_en = 0;
        shift_en_fifo = 0;
    endtask : read_full_depth

    // task automatic shifting_sequence();
    //     for (int j = 0; j < 7; j++) begin
    //         @(posedge clk);
    //         #10ns;
    //         if (j < 6) begin
    //             shift_en_fifo = 0;
    //         end
    //         else begin
    //             shift_en_fifo = 1;  //hold for 1 clk cycle [6-->7]
    //             shift_cnt = shift_cnt + 1;
    //         end
    //     end
    // endtask : shifting_sequence

    task automatic shifting_sequence(); //pulsing shift_en_fifo
        // 6 cycles low
        for (int j = 0; j < 6; j++) begin
            @(posedge clk);
            #10ns;
            clk_cycle_cnt = j[4:0];
            shift_en_fifo = 0;
        end
        // 1 cycle high (shift)
        @(posedge clk);
        #10ns;
        clk_cycle_cnt = clk_cycle_cnt + 1;
        shift_en_fifo = 1;
        shift_cnt = shift_cnt + 1;
        
        // interleaved, next row data + last shift out
        @(posedge clk);
        #10ns;
        clk_cycle_cnt = clk_cycle_cnt + 1;
        shift_en_fifo = 0;  // deassert!
    endtask

    task automatic read_row_data();
        // For 9 shifts (one full FIFO row)
        for (int s = 0; s < 9; s++) begin
            shifting_sequence();
        end
    endtask

endmodule : tb
