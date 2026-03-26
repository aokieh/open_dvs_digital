//---------------------------------------------------------------------------
// Author: Ababakar Okieh
// Date  : March 6th, 2026
//
// Module: async_fifo
//
// Description: 
//  Behavioral FIFO model for OpenDVS. 
//  Configured as a continuous-write Circular Buffer with explicit 
//  wrap-around for non-power-of-2 depths (e.g., depth = 10).
//---------------------------------------------------------------------------

module async_fifo (
    `ifdef USE_POWER_PINS
        inout vccd1, // OpenLane Power  - comment out if needed
        inout vssd1, // OpenLane Ground - comment out if needed
    `endif
    input  logic                   clk,
    input  logic                   rst_n,

    // input  logic                   wr_en,
    output logic                   empty,
    output logic                   full,
    output logic [`FIFO_AWIDTH_ASYNC  : 0] numel,
 
    // Asynchronous Interface
    input logic                   sync_req,
    input  logic [`FIFO_WIDTH_ASYNC-1 : 0] wdata_fifo,
    output logic                  data_ack,

    // SPI Interface
    input  logic                   rd_en,
    output logic [`FIFO_WIDTH_ASYNC-1 : 0] async_rdata_spi
);

    logic [`FIFO_AWIDTH_ASYNC   : 0] counter; // Keep track of data in FIFO
    logic [`FIFO_AWIDTH_ASYNC-1 : 0] wr_ptr, rd_ptr;
    logic [`FIFO_WIDTH_ASYNC-1  : 0] fifo [`FIFO_DEPTH_ASYNC];
    logic [`FIFO_AWIDTH_ASYNC   : 0] MAX_CNT = (1 << `FIFO_AWIDTH_ASYNC)-1;

    logic read, write;
    logic sync_req_delay;                       // prev. registered value

    // Continuous write capability
    // assign write = wr_en;
    // assign write = sync_req;
    assign write = sync_req & ~sync_req_delay;  // rising edge write ONLY
    assign read  = rd_en && !empty;

    // Empty and full flags
    assign empty = (counter == 0);
    assign full  = (counter == `FIFO_DEPTH_ASYNC);

    // Assign numel
    assign numel = counter;


    //-----------------------------------------------------------------------
    // Edge Detection & Delay Register
    //-----------------------------------------------------------------------

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            sync_req_delay <= 1'b0;
        else
            sync_req_delay <= sync_req;
    end

    //-----------------------------------------------------------------------
    // Counter Logic
    //-----------------------------------------------------------------------
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            counter <= '0;
        end else begin
            case ({write, read})
                2'b10: begin                    // Normal write
                    if (!full) 
                        counter <= counter + 1; //add safegaurd for inc at MAX_CNT 
                    // If full, counter stays at MAX_CNT. We drop the oldest item 
                    // and add a new one, so the total valid elements is MAX_CNT.
                end
                2'b01: begin                    // Normal read
                    if (!empty)
                        counter <= counter - 1;
                end
                2'b11: begin
                    counter <= counter;
                end
                default: counter <= counter;
            endcase
        end
    end

    //-----------------------------------------------------------------------
    // Write Pointer Logic (Explicit Wrap)
    //-----------------------------------------------------------------------
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= '0;
            data_ack <= 1'b0;
        end else if (write) begin
            fifo[wr_ptr] <= wdata_fifo;
            // Wrap to 0 if we are at the last index (9), otherwise increment
            // if (wr_ptr == `FIFO_DEPTH_ASYNC - 1)
            //     wr_ptr <= '0;
            // else
            //     wr_ptr <= wr_ptr + 1;
            wr_ptr <= (wr_ptr == MAX_CNT) ? '0 : wr_ptr + 1;
        end

        data_ack <= write;
    end

    //-----------------------------------------------------------------------
    // Read Pointer Logic (Explicit Wrap)
    //-----------------------------------------------------------------------
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr <= '0;  //TODO: circular buffer memory offset (new zero)
        end else if (read || (write && full)) begin
            // Advance if reading, OR writing to a full FIFO (dropping oldest)
            // if (rd_ptr == `FIFO_DEPTH_ASYNC - 1)
            //     rd_ptr <= '0;
            // else
            //     rd_ptr <= rd_ptr + 1;
                rd_ptr <= (rd_ptr == MAX_CNT) ? '0 : rd_ptr + 1;
        end
    end

    // Combinational read output
    assign async_rdata_spi = fifo[rd_ptr];

endmodule : async_fifo