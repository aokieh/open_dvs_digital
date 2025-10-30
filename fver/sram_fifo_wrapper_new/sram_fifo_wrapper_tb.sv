//---------------------------------------------------------------------------
// Author: Kwesi Buabeng Debrah
// Date  : Apr 4, 2025
//
// Module: sram_fifo_wrapper_tb
//
// Description: 
//  Testbench for the sram_fifo_wrapper module.
//---------------------------------------------------------------------------


import aer_pkg::*;


module sram_fifo_wrapper_tb ();

    localparam TEST_SIZE = SIZE_DW;

    localparam DWIDTH = 64;
    localparam DEPTH =  4096;
    localparam AWIDTH = $clog2(DEPTH);
    localparam WMASK = DWIDTH / 8;

    logic [DWIDTH-1:0] mem [DEPTH];

    // Inputs
    logic clk   = 0;
    logic rst_n = 0;

    logic              fifo_rst_n = 1;
    logic              fifo_wr_en = 0;
    logic              fifo_rd_en = 0;
    logic [DWIDTH-1:0] fifo_wdata;
    logic              fifo_empty;
    logic              fifo_full;
    logic [AWIDTH  :0] fifo_numel;
    // logic [AWIDTH  :0] fifo_wr_ptr;
    // logic [AWIDTH  :0] fifo_rd_ptr;
    logic [DWIDTH-1:0] fifo_rdata;

    logic              ce_a;
    logic              ce_b;
    logic [AWIDTH-1:0] addr_a;
    logic [AWIDTH-1:0] addr_b;
    logic              we_a;
    logic              we_b;
    logic [DWIDTH-1:0] wdata_a;
    logic [DWIDTH-1:0] wdata_b;
    logic [WMASK-1 :0] wmask_a;
    logic [WMASK-1 :0] wmask_b;
    logic [DWIDTH-1:0] rdata_a;
    logic [DWIDTH-1:0] rdata_b;


    sram_fifo_wrapper #(DWIDTH, DEPTH) i_wrapper (
        .clk        (clk    ),
        .rst_n      (rst_n  ),
        .fifo_rst_n (fifo_rst_n),
        .fifo_wr_en (fifo_wr_en),
        .fifo_rd_en (fifo_rd_en),
        .fifo_wdata (fifo_wdata),
        .fifo_empty (fifo_empty),
        .fifo_full  (fifo_full ),
        .fifo_numel (fifo_numel),
        // .fifo_wr_ptr(fifo_wr_ptr),
        // .fifo_rd_ptr(fifo_rd_ptr),
        .fifo_rdata (fifo_rdata),

        .ce_a   (ce_a   ),
        .ce_b   (ce_b   ),
        .addr_a (addr_a ),
        .addr_b (addr_b ),
        .we_a   (we_a   ),
        .we_b   (we_b   ),
        .wmask_a(wmask_a),
        .wmask_b(wmask_b),
        .wdata_a(wdata_a),
        .wdata_b(wdata_b),
        .rdata_a(rdata_a),
        .rdata_b(rdata_b)
    );


    event_sram i_event_sram (
        .clk    (clk    ),
        .ce_a   (ce_a   ),
        .ce_b   (ce_b   ),
        .addr_a (addr_a ),
        .addr_b (addr_b ),
        .we_a   (we_a   ),
        .we_b   (we_b   ),
        .wmask_a(wmask_a),
        .wmask_b(wmask_b),
        .wdata_a(wdata_a),
        .wdata_b(wdata_b),
        .rdata_a(rdata_a),
        .rdata_b(rdata_b)
    );


    // Clock generation
    always begin
        #5 clk = !clk;
    end


    // Testbench
    initial begin
        fifo_rst_n = 1;
        
        #10;
        rst_n = 1;
        fifo_wr_en = 0;
        fifo_rd_en = 0;
        
        
        // #10;
        // write_full_depth();

        
        // #30;
        // read_full_depth();

        
        // // Write and read data at the same time
        // #30;
        // write_read();


        // #30;
        // fifo_rst();

        
        #30;
        write_few_data();


        #30;
        read_full_depth();


        // #30;
        // fifo_rst();
        

        #20;
        $stop;
    end


    // task automatic write_full_depth();
    //     int i = 0;

    //     foreach (mem[i])
    //         mem[i] = 0;

    //     $display("\nWriting a bunch of data to the FIFO...");

    //     fifo_wr_en   = 0;
    //     fifo_rd_en   = 0;

    //     while (!fifo_full) begin
    //         @(posedge clk);
    //         #0.1ns;
    //         fifo_wr_en = 1;
    //         fifo_wdata = $urandom_range(0, (2**(8 * 2**TEST_SIZE))-1);
    //         $display("Writing data = %h", fifo_wdata);

    //         mem[i] = fifo_wdata;
    //         i = i + 1;

    //         @(posedge clk);
    //         #0.1ns;
    //         fifo_wr_en = 0;

    //         // #($urandom_range(1, 50));
    //     end

    //     fifo_wr_en   = 0;
    // endtask : write_full_depth


    task automatic write_few_data();
        int i = 0;

        foreach (mem[i])
            mem[i] = 0;

        $display("\nWriting a few data to the FIFO...");

        fifo_wr_en   = 0;
        fifo_rd_en   = 0;

        for (int j = 0; j < (16384); j++) begin
            @(posedge clk);
            #0.1ns;
            fifo_wr_en = 1;
            // fifo_wdata = $urandom_range(0, (2**(8 * 2**TEST_SIZE))-1);
            fifo_wdata = j + 1;
            $display("Writing data = %h", fifo_wdata);

            mem[j] = fifo_wdata;
            // i = i + 1;

            @(posedge clk);
            #0.1ns;
            fifo_wr_en = 0;

            // #($urandom_range(1, 50));
        end

        fifo_wr_en   = 0;
    endtask : write_few_data


    task automatic read_full_depth();
        int i = 0;

        $display("\nReading a bunch of data from the FIFO...");

        fifo_wr_en = 0;
        fifo_rd_en = 0;

        while (!fifo_empty) begin
            @(posedge clk);
            #0.1ns;
            fifo_rd_en = 1;

            // $display("Reading data = %h", fifo_rdata);
            
            if (fifo_rdata !== mem[i]) begin
                $display("Data mismatch @ [i=%0d]: expected %h, got %h", i, mem[i], fifo_rdata);
            end
            else begin
                $display("Data match    @ [i=%0d]: data %h", i, fifo_rdata);
            end
            i = i + 1;
            
            @(posedge clk);
            #0.1ns;
            fifo_rd_en = 0;
            
            // #($urandom_range(1, 50));
        end

        fifo_rd_en = 0;
    endtask : read_full_depth


    // task automatic write_read();
    //     int pre_count, post_count;

    //     $display("\nWrite and Read at the same time...");

    //     fifo_wr_en   = 0;
    //     fifo_rd_en   = 0;

    //     pre_count = fifo_numel;
    //     $display("Pre count = %0d\n", pre_count);

    //     #10;
    //     @(posedge clk);
    //     #0.1ns;
    //     fifo_wr_en   = 1;
    //     fifo_rd_en   = 1;
    //     fifo_wdata   = $urandom_range(0, (2**(8 * 2**TEST_SIZE))-1);
    //     $display("Writing data = %h", fifo_wdata);

    //     @(posedge clk);
    //     #0.1ns;
    //     fifo_wr_en   = 0;
    //     fifo_rd_en   = 0;

    //     #10;
    //     post_count = fifo_numel;
    //     $display("Post count = %0d\n", post_count);

    //     if (post_count > pre_count) begin
    //         $display("[WRITE] FIFO count increased from %0d to %0d\n", pre_count, post_count);
    //     end
    //     else if (post_count < pre_count) begin
    //         $display("[READ] FIFO count decreased from %0d to %0d\n", pre_count, post_count);
    //     end
    //     else begin
    //         $display("[NO OP] FIFO count remained the same at %0d\n", pre_count);
    //     end

    //     fifo_wr_en   = 0;
    //     fifo_rd_en   = 0;
    // endtask : write_read


    // task automatic fifo_rst();
    //     $display("\nResetting the FIFO...");

    //     foreach (mem[i])
    //         mem[i] = 0;

    //     fifo_rst_n = 0;

    //     #10;

    //     assert (fifo_numel == 0) else begin
    //         $error("FIFO reset failed: FIFO count is not zero");
    //     end

    //     assert (fifo_empty == 1) else begin
    //         $error("FIFO reset failed: FIFO is not empty");
    //     end

    //     assert (fifo_full == 0) else begin
    //         $error("FIFO reset failed: FIFO is not full");
    //     end

    //     assert (fifo_wr_ptr == 0) else begin
    //         $error("FIFO reset failed: FIFO write pointer is not zero");
    //     end

    //     assert (fifo_rd_ptr == 0) else begin
    //         $error("FIFO reset failed: FIFO read pointer is not zero");
    //     end

    //     $display("FIFO reset successful");

    //     fifo_rst_n = 1;
    //     #10;
    // endtask : fifo_rst

endmodule : sram_fifo_wrapper_tb
