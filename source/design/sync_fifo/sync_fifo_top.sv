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

module sync_fifo_top (
    `ifdef USE_POWER_PINS
        inout vccd1, // OpenLane Power  - comment out if needed
        inout vssd1, // OpenLane Ground - comment out if needed
    `endif

    input  logic                   clk,
    input  logic                   rst_n,

    // FIFO signals
    input  logic                   wr_en_fifo,
    input  logic [   `FIFO_WIDTH-1 : 0] wdata_fifo,
    output logic                   empty_fifo,
    output logic                   full_fifo,
    output logic [`FIFO_AWIDTH-1:0] numel_fifo,

    // Interface signals
    input logic                   shift_en_fifo,
    output logic [15:0]           rdata_spi
);

    logic fifo_rd_en_next;
    logic [`FIFO_WIDTH-1:0] rdata;

// FIFO instance
sync_fifo i_sync_fifo(
`ifdef USE_POWER_PINS
    .vccd1(vccd1),  // OpenLane Power  - comment out if needed
    .vssd1(vssd1),  // OpenLane Ground - comment out if needed
`endif
    .clk(clk),
    .rst_n(rst_n),
    .wr_en(wr_en_fifo),                 // write next row
    .rd_en(fifo_rd_en_next),            // read next row - from intf
    .wdata(wdata_fifo),                 // write data bus - [write_addr]
    .empty(empty_fifo),                 // fifo flag - empty
    .full(full_fifo),                   // fifo flag - full
    .numel(numel_fifo),                 // internal counter
    .rdata(rdata)                       // read data bus - [read_addr]
);

fifo_intf i_fifo_intf(
`ifdef USE_POWER_PINS
    .vccd1(vccd1),  // OpenLane Power  - comment out if needed
    .vssd1(vssd1),  // OpenLane Ground - comment out if needed
`endif
    .clk(clk),
    .rst_n(rst_n),
    .rdata_fifo(rdata),                 // data bus - from FIFO
    .shift_en(shift_en_fifo),           // shift every 8-bits locally - from QSPI
    .rdata_spi(rdata_spi),              // data bus - to Q-SPI
    .fifo_rd_en_next(fifo_rd_en_next)   // read next row - to FIFO
);

endmodule : sync_fifo_top
