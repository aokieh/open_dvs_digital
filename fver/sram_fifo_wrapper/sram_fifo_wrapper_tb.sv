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

    localparam WIDTH = 64;
    localparam DEPTH = 4096; // FIFO depth
    localparam MEM_DEPTH  = DEPTH * (2**(3+TEST_SIZE)) / WIDTH;

    // Inputs
    logic clk   = 0;
    logic rst_n = 0;

    logic [(WIDTH / 2**(3-TEST_SIZE))-1:0] mem [WIDTH * MEM_DEPTH / (2**(3+TEST_SIZE))];


    sram_fifo_wrapper_intf #(WIDTH, MEM_DEPTH, TEST_SIZE) mem_intf (clk, rst_n);


    // Instantiate the sram_fifo_wrapper module
    sram_fifo_wrapper #(WIDTH, MEM_DEPTH, TEST_SIZE) i_wrapper (
        .fifo_intf(mem_intf),
        .sram_intf(mem_intf)
    );


    // Instantiate the SRAM memory module
    sram_byte_ctrl #(WIDTH, MEM_DEPTH, TEST_SIZE) i_ctrl (
        .addr_a_i (mem_intf.fifo_wr_ptr),
        .addr_b_i (mem_intf.fifo_rd_ptr),
        .addr_a_o (mem_intf.addr_a     ),
        .addr_b_o (mem_intf.addr_b     ),
        .wmask_a  (mem_intf.wmask_a    ),
        .wmask_b  (mem_intf.wmask_b    )
    );


    // Instantiate the SRAM memory module
    sram_memory #(WIDTH, MEM_DEPTH) i_sram (
        .clk    (clk             ),
        .ce_a   (mem_intf.ce_a   ),
        .ce_b   (mem_intf.ce_b   ),
        .addr_a (mem_intf.addr_a ),
        .addr_b (mem_intf.addr_b ),
        .we_a   (mem_intf.we_a   ),
        .we_b   (mem_intf.we_b   ),
        .wmask_a(mem_intf.wmask_a),
        .wmask_b(mem_intf.wmask_b),
        .wdata_a(mem_intf.wdata_a),
        .wdata_b(mem_intf.wdata_b),
        .rdata_a(mem_intf.rdata_a),
        .rdata_b(mem_intf.rdata_b)
    );


    // Clock generation
    always begin
        #5 clk = !clk;
    end


    // Testbench
    initial begin
        mem_intf.fifo_rst_n = 1;
        
        #10;
        rst_n = 1;
        mem_intf.fifo_wr_en = 0;
        mem_intf.fifo_rd_en = 0;
        
        
        #10;
        write_full_depth();

        
        #30;
        read_full_depth();

        
        // Write and read data at the same time
        #30;
        write_read();


        #30;
        fifo_rst();

        
        #30;
        write_few_data();


        #30;
        read_full_depth();


        #30;
        fifo_rst();
        

        #20;
        $stop;
    end


    task automatic write_full_depth();
        int i = 0;

        foreach (mem[i])
            mem[i] = 0;

        $display("\nWriting a bunch of data to the FIFO...");

        mem_intf.fifo_wr_en   = 0;
        mem_intf.fifo_rd_en   = 0;

        while (!mem_intf.fifo_full) begin
            @(posedge clk);
            #0.1ns;
            mem_intf.fifo_wr_en = 1;
            mem_intf.fifo_wdata = $urandom_range(0, (2**(8 * 2**TEST_SIZE))-1);
            $display("Writing data = %h", mem_intf.fifo_wdata);

            mem[i] = mem_intf.fifo_wdata;
            i = i + 1;

            @(posedge clk);
            #0.1ns;
            mem_intf.fifo_wr_en = 0;

            // #($urandom_range(1, 50));
        end

        mem_intf.fifo_wr_en   = 0;
    endtask : write_full_depth


    task automatic write_few_data();
        int i = 0;

        foreach (mem[i])
            mem[i] = 0;

        $display("\nWriting a few data to the FIFO...");

        mem_intf.fifo_wr_en   = 0;
        mem_intf.fifo_rd_en   = 0;

        for (int j = 0; j < (DEPTH >> 1); j++) begin
            @(posedge clk);
            #0.1ns;
            mem_intf.fifo_wr_en = 1;
            mem_intf.fifo_wdata = $urandom_range(0, (2**(8 * 2**TEST_SIZE))-1);
            $display("Writing data = %h", mem_intf.fifo_wdata);

            mem[i] = mem_intf.fifo_wdata;
            i = i + 1;

            @(posedge clk);
            #0.1ns;
            mem_intf.fifo_wr_en = 0;

            // #($urandom_range(1, 50));
        end

        mem_intf.fifo_wr_en   = 0;
    endtask : write_few_data


    task automatic read_full_depth();
        int i = 0;

        $display("\nReading a bunch of data from the FIFO...");

        mem_intf.fifo_wr_en = 0;
        mem_intf.fifo_rd_en = 0;

        while (!mem_intf.fifo_empty) begin
            @(posedge clk);
            #0.1ns;
            mem_intf.fifo_rd_en = 1;

            $display("Reading data = %h", mem_intf.fifo_rdata);
            
            if (mem_intf.fifo_rdata !== mem[i]) begin
                $display("Data mismatch: expected %h, got %h", mem[i], mem_intf.fifo_rdata);
            end
            i = i + 1;
            
            @(posedge clk);
            #0.1ns;
            mem_intf.fifo_rd_en = 0;
            
            // #($urandom_range(1, 50));
        end

        mem_intf.fifo_rd_en = 0;
    endtask : read_full_depth


    task automatic write_read();
        int pre_count, post_count;

        $display("\nWrite and Read at the same time...");

        mem_intf.fifo_wr_en   = 0;
        mem_intf.fifo_rd_en   = 0;

        pre_count = mem_intf.fifo_numel;
        $display("Pre count = %0d\n", pre_count);

        #10;
        @(posedge clk);
        #0.1ns;
        mem_intf.fifo_wr_en   = 1;
        mem_intf.fifo_rd_en   = 1;
        mem_intf.fifo_wdata   = $urandom_range(0, (2**(8 * 2**TEST_SIZE))-1);
        $display("Writing data = %h", mem_intf.fifo_wdata);

        @(posedge clk);
        #0.1ns;
        mem_intf.fifo_wr_en   = 0;
        mem_intf.fifo_rd_en   = 0;

        #10;
        post_count = mem_intf.fifo_numel;
        $display("Post count = %0d\n", post_count);

        if (post_count > pre_count) begin
            $display("[WRITE] FIFO count increased from %0d to %0d\n", pre_count, post_count);
        end
        else if (post_count < pre_count) begin
            $display("[READ] FIFO count decreased from %0d to %0d\n", pre_count, post_count);
        end
        else begin
            $display("[NO OP] FIFO count remained the same at %0d\n", pre_count);
        end

        mem_intf.fifo_wr_en   = 0;
        mem_intf.fifo_rd_en   = 0;
    endtask : write_read


    task automatic fifo_rst();
        $display("\nResetting the FIFO...");

        foreach (mem[i])
            mem[i] = 0;

        mem_intf.fifo_rst_n = 0;

        #10;

        assert (mem_intf.fifo_numel == 0) else begin
            $error("FIFO reset failed: FIFO count is not zero");
        end

        assert (mem_intf.fifo_empty == 1) else begin
            $error("FIFO reset failed: FIFO is not empty");
        end

        assert (mem_intf.fifo_full == 0) else begin
            $error("FIFO reset failed: FIFO is not full");
        end

        assert (mem_intf.fifo_wr_ptr == 0) else begin
            $error("FIFO reset failed: FIFO write pointer is not zero");
        end

        assert (mem_intf.fifo_rd_ptr == 0) else begin
            $error("FIFO reset failed: FIFO read pointer is not zero");
        end

        $display("FIFO reset successful");

        mem_intf.fifo_rst_n = 1;
        #10;
    endtask : fifo_rst

endmodule : sram_fifo_wrapper_tb
