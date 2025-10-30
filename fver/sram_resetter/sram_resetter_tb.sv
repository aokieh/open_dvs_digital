//---------------------------------------------------------------------------
// Author: Kwesi Buabeng Debrah
// Date  : Apr 4, 2025
//
// Module: sram_resetter_tb
//
// Description: 
//  Testbench for the sram_resetter module.
//---------------------------------------------------------------------------


import aer_pkg::*;


module sram_resetter_tb ();

    // Inputs
    logic clk   = 0;
    logic rst_n = 0;
    logic enable = 0;
    logic irq_ack = 0;
    logic rst_irq;


    sram_fifo_wrapper_intf #(RX_MEM_DWIDTH, RX_MEM_DEPTH, SIZE_DW) mem_intf (clk, rst_n);


    // Instantiate the SRAM memory module
    sram_resetter #(RX_MEM_DEPTH) i_resetter (
        .mem_intf,
        .enable,
        .irq_ack,
        .rst_irq
    );


    // Instantiate the SRAM memory module
    sram_memory #(RX_MEM_DWIDTH, RX_MEM_DEPTH) i_sram (
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


    // Interrupt acknowledgment
    always begin
        @(posedge rst_irq);

        repeat (2) @(posedge clk);
        irq_ack = 1;
        @(posedge clk);
        irq_ack = 0;

        repeat (5) @(posedge clk);
        $stop;
    end


    // Testbench
    initial begin
        
        #10;
        rst_n = 1;

        @(posedge clk);
        enable = 1;


        // Wait for the reset interrupt
        @(posedge rst_irq);

        // Acknowledge the reset interrupt
        repeat (2) @(posedge clk);
        enable  = 0;
        irq_ack = 1;
        @(posedge clk);
        irq_ack = 0;


        confirm_reset();

        
        repeat (5) @(posedge clk);
        $stop;
    end


    task automatic confirm_reset();
        int errors = 0;

        // Confirm all memory contents are reset
        foreach (i_sram.mem[i]) begin
            if (i_sram.mem[i] !== 0) begin
                $display("SRAM memory at index %0d is not reset. Value: %0h", i, i_sram.mem[i]);
                errors++;
            end
        end

        if (errors == 0) begin
            $display("\n[SUCCESS] All SRAM memory contents are reset.\n");
        end else begin
            $error("\n[**FAILURE] %0d SRAM memory locations are not reset.\n", errors);
        end
    endtask : confirm_reset

endmodule : sram_resetter_tb
