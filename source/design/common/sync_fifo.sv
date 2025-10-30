//---------------------------------------------------------------------------
// Author: Kwesi Buabeng Debrah
// Date  : Mar 3, 2025
//
// Module: sync_fifo
//
// Description: 
//  Behavioral FIFO model.
//---------------------------------------------------------------------------


module sync_fifo #(parameter DWIDTH=8, DEPTH=8) (
    input  logic                   clk,
    input  logic                   rst_n,
    input  logic                   wr_en,
    input  logic                   rd_en,
    input  logic [   DWIDTH-1 : 0] wdata,
    output logic                   empty,
    output logic                   full,
    output logic [$clog2(DEPTH):0] numel,
    output logic [   DWIDTH-1 : 0] rdata
);

    logic [$clog2(DEPTH)   : 0] counter; // Keep track of data in FIFO
    logic [$clog2(DEPTH)-1 : 0] wr_ptr, rd_ptr;
    logic [       DWIDTH-1 : 0] fifo [DEPTH];

    logic read, write;

    assign write = wr_en && !full;
    assign read  = rd_en && !empty;


    // Empty and full flags
    assign empty = (counter == 0);
    assign full  = (counter == DEPTH);

    // Assign numel
    assign numel = counter;


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
