//---------------------------------------------------------------------------
// Module: fifo_intf3
// Description: 
//  Parallel Q-SPI bridge streaming LSB to MSB for two 64-bit data segments.
//  Row format: {CTRL[135:128], DATA_TOP[127:64], DATA_BOT[63:0]}
//  Transmission Sequence: 8 Data Shifts -> 1 Control Shift
//---------------------------------------------------------------------------

module fifo_intf3 (
    `ifdef USE_POWER_PINS
        inout vccd1, 
        inout vssd1, 
    `endif
    
    input  logic               clk,
    input  logic               rst_n,
  
    // Data from FWFT FIFO
    input  logic [135:0]       rdata_fifo, 
    input  logic               fifo_empty, 
    
    // Interface to Q-SPI Master
    input  logic               shift_en,   
    output logic [15:0]        rdata_spi,  
    
    // Control to FIFO
    output logic               fifo_rd_en  
);

    // FSM State Definitions
    localparam [1:0]
        ST_IDLE       = 2'd0,
        ST_SHIFT_DATA = 2'd1,
        ST_SHIFT_CTRL = 2'd2;

    logic [1:0] state;
    logic [3:0] shift_ctr;
    // logic [6:0] offset;
    logic [7:0] byte_offset; // <-- YOU MUST ADD THIS LINE
    assign byte_offset = {2'b00, shift_ctr[2:0], 3'b000};
    // logic [6:0] offset; //linter warning

    // -----------------------------------------------------------------
    // Combinational Data Multiplexer (DATA First, then CTRL)
    // -----------------------------------------------------------------
    // always_comb begin
    //     rdata_spi = 16'd0; 

    //     if (!fifo_empty) begin
    //         if (state == ST_SHIFT_CTRL) begin
    //             // TRANSMISSION 9: Header [135:128]
    //             rdata_spi[15:8] = rdata_fifo[135:128];
    //             rdata_spi[7:0]  = rdata_fifo[135:128];
    //         end 
    //         else begin
    //             // TRANSMISSIONS 1-8: Data Streaming LSB -> MSB
    //             // logic [6:0] offset;
    //             offset = {shift_ctr[2:0], 3'b000}; 
                
    //             // Channel A: Top Macro [127:64]
    //             rdata_spi[15:8] = rdata_fifo[(7'd64 + offset) +: 8]; 
    //             // Channel B: Bottom Macro [63:0]
    //             rdata_spi[7:0]  = rdata_fifo[(7'd0  + offset) +: 8]; 
    //         end
    //     end
    // end

    // -----------------------------------------------------------------
    // Registered Data Multiplexer (Breaks the critical timing path)
    // -----------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rdata_spi <= 16'd0;
        end 
        else if (!fifo_empty) begin
            if (state == ST_SHIFT_CTRL) begin
                // TRANSMISSION 9: Header [135:128]
                rdata_spi[15:8] <= rdata_fifo[135:128];
                rdata_spi[7:0]  <= rdata_fifo[135:128];
            end 
            else begin
                // TRANSMISSIONS 1-8: Data Streaming LSB -> MSB
                // The slicing logic is now captured directly into a flip-flop
                // rdata_spi[15:8] <= rdata_fifo[(7'd64 + {shift_ctr[2:0], 3'b000}) +: 8]; 
                // rdata_spi[7:0]  <= rdata_fifo[(7'd0  + {shift_ctr[2:0], 3'b000}) +: 8];
                rdata_spi[15:8] <= rdata_fifo[64 + byte_offset +: 8]; // linter warning, 8-bits wide
                rdata_spi[7:0]  <= rdata_fifo[0  + byte_offset +: 8]; // more readable
            end
        end
        else begin
            rdata_spi <= 16'd0;
        end
    end

    // Look-Ahead FIFO Pop
    // Triggers exactly as the 9th byte (Control) is being shifted out.
    assign fifo_rd_en = (state == ST_SHIFT_CTRL) && shift_en;

    // -----------------------------------------------------------------
    // Sequential Control Engine (DATA -> CTRL Sequence)
    // -----------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= ST_IDLE;
            shift_ctr <= 4'd0;
        end 
        else begin
            case (state)
                ST_IDLE: begin
                    // Prime the pump: move to DATA state as soon as FIFO has data
                    if (!fifo_empty) begin
                        state <= ST_SHIFT_DATA; 
                    end
                end

                ST_SHIFT_DATA: begin
                    if (shift_en) begin
                        if (shift_ctr == 4'd7) begin
                            // Finished the 8 data bytes, move unconditionally to CTRL
                            state <= ST_SHIFT_CTRL; 
                        end else begin
                            shift_ctr <= shift_ctr + 4'd1;
                        end
                    end
                end

                ST_SHIFT_CTRL: begin
                    if (shift_en) begin
                        // Row complete. Go to IDLE. 
                        // If more data is ready, the FSM will jump right back to ST_SHIFT_DATA
                        // on the next system clock edge, safely before the next SPI shift.
                        state     <= ST_IDLE;
                        shift_ctr <= 4'd0;
                    end
                end
                
                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule : fifo_intf3