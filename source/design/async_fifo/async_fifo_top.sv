//---------------------------------------------------------------------------
// Author: Ababakar Okieh
// Date  : March 6th, 2025
//
// Module: sync_fifo_top
//
// Description: 
//  Behavioral FIFO model for OpenDVS.
//---------------------------------------------------------------------------

module async_fifo_top (
    `ifdef USE_POWER_PINS
        inout vccd1, // OpenLane Power  - comment out if needed
        inout vssd1, // OpenLane Ground - comment out if needed
    `endif

    input  logic                   clk,
    input  logic                   rst_n,

    // FIFO signals
    output logic                   empty_fifo,
    output logic                   full_fifo,
    output logic [`FIFO_AWIDTH_ASYNC-1:0] numel_fifo,

    // Asynchronous Interface
    input logic [`FIFO_WIDTH_ASYNC-1 : 0] wdata_async, // data bus - from FIFO
    input logic                   data_req,
    output logic                   data_ack,
    // output logic                  sync_req          // data bus - to Q-SPI

    // SPI Interface
    input  logic                   fifo_rd_en,
    output logic [`FIFO_WIDTH_ASYNC-1 : 0] async_rdata_spi
);

    logic sync_req_signal, sync_ack_signal;
    logic async_req_signal;
    logic [`FIFO_WIDTH_ASYNC-1:0] wdata_fifo;

    assign async_req_signal = data_req;

//FIFO Instance
async_fifo i_async_fifo (
    `ifdef USE_POWER_PINS
        .vccd1(vccd1), // OpenLane Power  - comment out if needed
        .vssd1(vssd1), // OpenLane Ground - comment out if needed
    `endif
    .clk(clk),
    .rst_n(rst_n),

    // input  logic                   wr_en,
    .empty(empty_fifo),
    .full(full_fifo),
    .numel(numel_fifo),
 
    // Asynchronous Interface
    .sync_req(sync_req_signal),// syncronized request -> write 
    .wdata_fifo(wdata_fifo),// data bus - write to FIFO
    .data_ack(sync_ack_signal),// output to deassert request

    // SPI Interface
    .rd_en(fifo_rd_en),
    .async_rdata_spi(async_rdata_spi)
);


//FIFO Write Interface
async_write_intf i_async_write_intf(
    `ifdef USE_POWER_PINS
        .vccd1(vccd1), // OpenLane Power  - comment out if needed
        .vssd1(vssd1), // OpenLane Ground - comment out if needed
    `endif
    
    .clk(clk),
    .rst_n(rst_n),
    
    // Asynchronous Interface
    .wdata_fifo(wdata_fifo),      // data bus - write to FIFO
    .wdata_async(wdata_async), // data bus - from async block

    .fifo_ack(sync_ack_signal),   // FIX #1
    .data_ack(data_ack),          // FIX #2: // output to deassert request

    .data_req(async_req_signal),        // async input to request write
    .sync_req(sync_req_signal)         // syncronized request -> write 
);


endmodule : async_fifo_top