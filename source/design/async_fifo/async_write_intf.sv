//---------------------------------------------------------------------------
// Author: Ababakar Okieh
// Date  : March 6th, 2026
//
// Module: write_intf
//
// Description: 
//  Behavioral interface for OpenDVS.
//---------------------------------------------------------------------------


module async_write_intf (
    `ifdef USE_POWER_PINS
        inout vccd1, // OpenLane Power  - comment out if needed
        inout vssd1, // OpenLane Ground - comment out if needed
    `endif
    
    input  logic                  clk,
    input  logic                  rst_n,
    
    // Asynchronous Interface
    input logic [`FIFO_WIDTH_ASYNC-1 : 0] wdata_async, // data bus - from FIFO
    output logic [`FIFO_WIDTH_ASYNC-1 : 0] wdata_fifo,  // passthrough of data
    
    input logic                   fifo_ack,
    output logic                   data_ack,         // shift every 8-bits - from QSPI
    
    input logic                   data_req,
    output logic                  sync_req          // data bus - to Q-SPI
    // output logic                  fifo_rd_en_next   // read next row - to FIFO
);

    // logic req_delay_1, req_delay_2;
    (* ASYNC_REG = "TRUE" *) logic req_delay_1;
    (* ASYNC_REG = "TRUE" *) logic req_delay_2;

            // Row_req Synchronizer - coming from async source into a FIFO
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin           //data won't get latched in FIFO, don't ack
            req_delay_1 <= 1'b0;
            req_delay_2 <= 1'b0;
        end
        else begin
            req_delay_1 <= data_req;
            req_delay_2 <= req_delay_1;
        end
    end

    assign sync_req = req_delay_2;
    assign wdata_fifo = wdata_async;
    assign data_ack = fifo_ack;

endmodule : async_write_intf