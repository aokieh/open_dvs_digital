//---------------------------------------------------------------------------
// Author: Kwesi Buabeng Debrah
// Date  : Apr 2, 2025
//
// Module: sram_fifo_wrapper
//
// Description: 
//  Module that handles FIFO-to-SRAM interface with First Word Fall Through
//  and look-ahead.
//  Read data is available in the same cycle rd_en is asserted.
//---------------------------------------------------------------------------


import aer_pkg::*;


module sram_fifo_wrapper #(
    parameter DWIDTH=16, DEPTH=16,
    localparam AWIDTH = $clog2(DEPTH),
    localparam WMASK = DWIDTH / 8
) (
    input  logic              clk,
    input  logic              rst_n,
    input  logic              fifo_rst_n,
    input  logic              fifo_wr_en,
    input  logic              fifo_rd_en,
    input  logic [DWIDTH-1:0] fifo_wdata,
    output logic              fifo_empty,
    output logic              fifo_full,
    output logic [AWIDTH  :0] fifo_numel,
    output logic [DWIDTH-1:0] fifo_rdata,

    output logic              ce_a,
    output logic              ce_b,
    output logic [AWIDTH-1:0] addr_a,
    output logic [AWIDTH-1:0] addr_b,
    output logic              we_a,
    output logic              we_b,
    output logic [WMASK-1 :0] wmask_a,
    output logic [WMASK-1 :0] wmask_b,
    output logic [DWIDTH-1:0] wdata_a,
    output logic [DWIDTH-1:0] wdata_b,
    input  logic [DWIDTH-1:0] rdata_a,
    input  logic [DWIDTH-1:0] rdata_b
);

    logic              write, read; // Track actual write/read operations
    logic              write_en_a, write_en_b;
    logic [AWIDTH-1:0] wr_ptr, rd_ptr;

    logic              clk_en_b;
    logic              rdata_valid;
    logic              fwft_valid; // Valid signal for first word fall through
    logic [DWIDTH-1:0] fwft_reg; // Register to hold first word fall through data


    //---------------------------------------------------------------------------
    // FIFO Interface
    //---------------------------------------------------------------------------
    assign fifo_empty  = !rdata_valid;
    assign fifo_full   = (fifo_numel == DEPTH);

    assign fifo_rdata  = rdata_b;


    //---------------------------------------------------------------------------
    // SRAM Interface
    //---------------------------------------------------------------------------
    assign addr_a  = wr_ptr;
    assign addr_b  = rd_ptr;
    assign ce_a    = fifo_wr_en;
    assign ce_b    = clk_en_b;
    assign we_a    = fifo_wr_en;
    assign we_b    = '0;
    assign wmask_a = fifo_wr_en ? '1 : '0;
    assign wmask_b = '0;
    assign wdata_a = fifo_wdata;
    assign wdata_b = '0;        


    //---------------------------------------------------------------------------
    // FIFO Numel
    //---------------------------------------------------------------------------
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            fifo_numel <= '0;

        else begin
            if (!fifo_rst_n) // Synchronous reset from RF Interface
                fifo_numel <= '0;

            else begin
                if (fifo_wr_en && !fifo_rd_en && !fifo_full)
                    fifo_numel <= fifo_numel + 1;
                else if (!fifo_wr_en && fifo_rd_en && !fifo_empty)
                    fifo_numel <= fifo_numel - 1;
            end
        end
    end


    //---------------------------------------------------------------------------
    // Write to FIFO
    //---------------------------------------------------------------------------
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            wr_ptr <= '0;

        else begin
            if (!fifo_rst_n) // Synchronous reset from RF Interface
                wr_ptr <= '0;

            else begin
                if (fifo_wr_en && !fifo_full) begin
                    wr_ptr <= wr_ptr + 1;
                end
            end
        end
    end


    //---------------------------------------------------------------------------
    // Read from FIFO
    //---------------------------------------------------------------------------
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            rd_ptr <= '0;

        else begin
            if (!fifo_rst_n) // Synchronous reset from RF Interface
                rd_ptr <= '0;

            else begin
                if (clk_en_b) begin
                    rd_ptr <= rd_ptr + 1;
                end
            end
        end
    end


    //---------------------------------------------------------------------------
    // Read from FIFO
    //---------------------------------------------------------------------------
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            rdata_valid <= '0;
        end
            
        else begin
            if (!fifo_rst_n) begin // Synchronous reset from RF Interface
                rdata_valid <= '0;
            end

            else begin
                if (fifo_rd_en && !clk_en_b) begin
                    rdata_valid <= '0;
                end
                else if (!fifo_rd_en && clk_en_b) begin
                    rdata_valid <= '1;
                end
            end
        end
    end


    always_comb begin
        clk_en_b = '0;

        if (!rdata_valid) begin
            if (fifo_numel > 0) begin  // if valid data in the fifo
                clk_en_b = '1;
            end
        end 
        else begin
            if (fifo_numel > 1) begin  // if valid data in the fifo
                if (fifo_rd_en) begin
                    clk_en_b = '1;
                end
            end
        end
    end

endmodule : sram_fifo_wrapper
