//---------------------------------------------------------------------------
// Author: Kwesi Buabeng Debrah
// Author: Ababakar Okieh
// Date  : Dec 16th, 2025
//
// Module: sync_fifo_top
//
// Description: 
//  Behavioral FIFO model for OpenDVS.
//---------------------------------------------------------------------------

module sync_fifo_top#(parameter DWIDTH=136, DEPTH=16) (
    input  logic                   clk,
    input  logic                   rst_n,

    // FIFO signals
    input  logic                   wr_en,
    input  logic [   DWIDTH-1 : 0] wdata,
    output logic                   empty,
    output logic                   full,
    output logic [$clog2(DEPTH)-1:0] numel,

    // Interface signals
    input logic                   shift_en,
    output logic [15:0]           rdata_spi
);

    logic fifo_rd_en_next;
    logic [DWIDTH-1:0] rdata;

// FIFO instance
sync_fifo i_sync_fifo(
    .clk(clk),
    .rst_n(rst_n),
    .wr_en(wr_en),                      // write next row
    .rd_en(fifo_rd_en_next),            // read next row - from intf
    .wdata(wdata),                      // write data bus - [write_addr]
    .empty(empty),                      // fifo flag - empty
    .full(full),                        // fifo flag - full
    .numel(numel),                      // internal counter
    .rdata(rdata)                       // read data bus - [read_addr]
);

fifo_intf #(DWIDTH, DEPTH) i_fifo_intf(
    .clk(clk),
    .rst_n(rst_n),
    .rdata_fifo(rdata),                 // data bus - from FIFO
    .shift_en(shift_en),                // shift every 8-bits locally - from QSPI
    .rdata_spi(rdata_spi),              // data bus - to Q-SPI
    .fifo_rd_en_next(fifo_rd_en_next)   // read next row - to FIFO
);

endmodule : sync_fifo_top
