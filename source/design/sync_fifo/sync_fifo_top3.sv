//---------------------------------------------------------------------------
// Author: Ababakar Okieh
// Date  : Dec 16th, 2025
//
// Module: sync_fifo_top
//
// Description: 
//  Behavioral FIFO model for OpenDVS.
//---------------------------------------------------------------------------

//---------------------------------------------------------------------------
// Module: sync_fifo_top3
// Description: 
//  Top-level wrapper bridging the FWFT Synchronous FIFO and the 
//  Q-SPI State Machine Interface.
//---------------------------------------------------------------------------

module sync_fifo_top3 (
    `ifdef USE_POWER_PINS
        inout vccd1, // OpenLane Power
        inout vssd1, // OpenLane Ground
    `endif

    input  logic                   clk,
    input  logic                   rst_n,

    // FIFO Write Interface (From ROIC Micro-Sequencer)
    input  logic                   wr_en_fifo,
    input  logic [   `FIFO_WIDTH-1 : 0] wdata_fifo,
    output logic                   empty_fifo,
    output logic                   full_fifo,
    output logic [`FIFO_AWIDTH-1:0] numel_fifo,

    // Q-SPI Read Interface (From/To SPI Master)
    input  logic                   shift_en_fifo,
    output logic [15:0]            rdata_spi
);

    // -----------------------------------------------------------------
    // Internal Interconnects
    // -----------------------------------------------------------------
    logic                   fifo_rd_en_next;
    logic [`FIFO_WIDTH-1:0] rdata_fifo;

    // -----------------------------------------------------------------
    // FWFT Synchronous FIFO Instance
    // -----------------------------------------------------------------
    sync_fifo i_sync_fifo (
        `ifdef USE_POWER_PINS
            .vccd1 (vccd1),
            .vssd1 (vssd1),
        `endif
        .clk   (clk),
        .rst_n (rst_n),
        .wr_en (wr_en_fifo),
        .rd_en (fifo_rd_en_next),       // Driven by fifo_intf3 Look-Ahead Pop
        .wdata (wdata_fifo),
        .empty (empty_fifo),            // Exported to top AND routed to fifo_intf3
        .full  (full_fifo),
        .numel (numel_fifo),
        .rdata (rdata_fifo)             // Routed to fifo_intf3
    );

    // -----------------------------------------------------------------
    // Q-SPI to FIFO State Machine Interface Instance
    // -----------------------------------------------------------------
    fifo_intf3 i_fifo_intf3 (
        `ifdef USE_POWER_PINS
            .vccd1 (vccd1),
            .vssd1 (vssd1),
        `endif
        .clk        (clk),
        .rst_n      (rst_n),
        .rdata_fifo (rdata_fifo),       // Read data bus from FIFO
        .fifo_empty (empty_fifo),       // Prevents shifting garbage data
        .shift_en   (shift_en_fifo),    // Shift trigger from QSPI
        .rdata_spi  (rdata_spi),        // 16-bit formatted output to QSPI
        .fifo_rd_en (fifo_rd_en_next)   // Look-Ahead Pop trigger to FIFO
    );

endmodule : sync_fifo_top3