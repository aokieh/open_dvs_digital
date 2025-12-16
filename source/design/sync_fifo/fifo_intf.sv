//---------------------------------------------------------------------------
// Author: Kwesi Buabeng Debrah
// Author: Ababakar Okieh
// Date  : Dec 15th, 2025
//
// Module: fifo_intf
//
// Description: 
//  Behavioral FIFO model for OpenDVS.
//---------------------------------------------------------------------------


module sync_fifo #(parameter DWIDTH=136, DEPTH=16) (
    input  logic                  clk,
    input  logic                  rst_n,
    input logic [   DWIDTH-1 : 0] rdata_fifo,       // data bus - from FIFO
    input logic                   shift_en,         // shift every 8-bits - from QSPI
    output logic [15:0]           rdata_spi,        // data bus - to Q-SPI
    output logic                  fifo_rd_en_next   // read next row - to FIFO
);

    logic [6:0] ptr_1, ptr_2;
    logic [3:0] fifo_shift_count;

    // Reading data from FIFO
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin   //initiated by Q-SPI, after row read out?
            ptr_1 <= 7'd135;           // first  tile - intial location
            ptr_2 <= 7'd71;            // second tile - initial location
            fifo_shift_count <= 4'd0;  // total of 8 data TX, 1 addr TX (136 bits)
        end
        else if (shift_en) begin
            if (fifo_shift_count < 8) begin  // data shifting case, last one is addr          
                ptr_1 <= ptr_1 - 7'd8; 
                ptr_2 <= ptr_2 - 7'd8;
            end
             fifo_shift_count <= fifo_shift_count + 4'd1;
        end
    end

    // select data for SPI bus
    // always_comb begin
    //     if (fifo_shift_count < 8)
    //         rdata_spi = { rdata_fifo[ptr_1 -: 8], rdata_fifo[ptr_2 -: 8] }; //holds data
    //     else
    //         rdata_spi = { rdata_fifo[7:0], rdata_fifo[7:0] }; // holds addr twice
    // end

    always @* begin
        if (fifo_shift_count < 8)
            rdata_spi = { rdata_fifo[ptr_1 : ptr_1-7], rdata_fifo[ptr_2 : ptr_2-7] }; // holds data
        else
            rdata_spi = { rdata_fifo[7:0], rdata_fifo[7:0] }; // holds addr twice
    end

    // Next-row read enable
    assign fifo_rd_en_next = (fifo_shift_count == 8) && shift_en; //TODO: there may be a 1 cycle delay here