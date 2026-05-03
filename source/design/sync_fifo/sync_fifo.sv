//---------------------------------------------------------------------------
// Author: Kwesi Buabeng Debrah
// Author: Ababakar Okieh
// Date  : Dec 15th, 2025
//
// Module: sync_fifo
//
// Description: 
//  Behavioral FIFO model for OpenDVS.
//---------------------------------------------------------------------------


module sync_fifo (
    `ifdef USE_POWER_PINS
        inout vccd1, // OpenLane Power  - comment out if needed
        inout vssd1, // OpenLane Ground - comment out if needed
    `endif

    input  logic                   clk,
    input  logic                   rst_n,
    input  logic                   wr_en,
    input  logic                   rd_en,
    input  logic [   `FIFO_WIDTH-1 : 0] wdata,
    output logic                   empty,
    output logic                   full,
    output logic [`FIFO_AWIDTH-1:0] numel,
    output logic [`FIFO_WIDTH-1 : 0] rdata
);

    logic [`FIFO_AWIDTH   : 0] counter; // Keep track of data in FIFO
    logic [`FIFO_AWIDTH-1 : 0] wr_ptr, rd_ptr;
    logic [       `FIFO_WIDTH-1 : 0] fifo [`FIFO_DEPTH];

    logic read, write;

    assign write = wr_en && !full;
    assign read  = rd_en && !empty;


    // Empty and full flags
    assign empty = (counter == 0);
    assign full  = (counter == `FIFO_DEPTH);

    // Assign numel
    // assign numel = counter;
    assign numel = counter[`FIFO_AWIDTH-1:0]; //linter warning


    // Reset FIFO
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            counter <= '0;
        else begin
            if (write && !read) begin
                counter <= counter + 1;
            end
            else if (read && !write) begin
                counter <= counter - 1;
            end
        end
    end


    // Write to FIFO
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            wr_ptr       <= '0;
        else if (wr_en && !full) begin
            fifo[wr_ptr] <= wdata;
            wr_ptr       <= wr_ptr + 1;
        end
    end


    // Read from FIFO
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr   <= '0;
        end
        else if (rd_en && !empty) begin
            rd_ptr   <= rd_ptr + 1;
        end
    end

    assign rdata = fifo[rd_ptr];

endmodule : sync_fifo
