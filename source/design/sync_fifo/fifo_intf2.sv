// //---------------------------------------------------------------------------
// // Author: Ababakar Okieh
// // Date  : March 30th, 2026
// //
// // Module: fifo_intf2
// //
// // Description: 
// //  Behavioral FIFO model for OpenDVS.
// //---------------------------------------------------------------------------

// module fifo_intf2 (
//     `ifdef USE_POWER_PINS
//         inout vccd1, 
//         inout vssd1, 
//     `endif
    
//     input  logic                  clk,
//     input  logic                  rst_n,
//     input  logic [135:0]          rdata_fifo,
//     input  logic [63:0]           rdata_0,      // 64 bits (Tile1)
//     input  logic [63:0]           rdata_1,      // 64 bits (Tile2)
//     input  logic [5:0]            row_addr,     // 6 bits   (Addr)

//     input  logic                  shift_en,
//     output logic [15:0]           rdata_spi,
//     output logic                  fifo_rd_en_next
// );

//     logic [3:0]  fifo_shift_count;
    
//     // Dedicated Shift Registers
//     logic [63:0]    tile1_shift_reg;
//     logic [63:0]    tile2_shift_reg;
//     logic [7:0]     row_addr_reg;

//     //combined data bus
//     logic [135:0]   rdata_fifo = {rdata_1, rdata_0, 2'b00, row_addr};

//     // Gated shift logic (The FWFT empty-check we discussed earlier)
//     // NOTE: You will need to bring empty_fifo into this module's ports!
//     logic data_ready;
//     // assign data_ready = (fifo_shift_count > 0) || !empty_fifo; 
//     // assign safe_shift_en = shift_en && data_ready;
//     logic safe_shift_en;
//     assign safe_shift_en = shift_en; // Assuming you add the empty_fifo gate here

//     always_ff @(posedge clk or negedge rst_n) begin
//         if (!rst_n) begin   
//             fifo_shift_count <= 4'd0;
//             tile1_shift_reg  <= '0;
//             tile2_shift_reg  <= '0;
//             row_addr_reg     <= '0;
//         end
//         else if (safe_shift_en) begin
            
//             if (fifo_shift_count == 0) begin
//                 // LOAD PHASE: Grab the FWFT data and perform the FIRST shift simultaneously
//                 // We drop the top 8 bits (since they are output combinationally right now)
//                 // and load the remaining 56 bits into the top of the register.
//                 tile1_shift_reg  <= {rdata_fifo[127:72], 8'd0}; 
//                 tile2_shift_reg  <= {rdata_fifo[63:8],   8'd0};
//                 row_addr_reg     <= rdata_fifo[7:0];
                
//                 fifo_shift_count <= 4'd1;
//             end
//             else if (fifo_shift_count < 8) begin  
//                 // SHIFT PHASE: Shift left by 8 bits
//                 tile1_shift_reg  <= {tile1_shift_reg[55:0], 8'd0};
//                 tile2_shift_reg  <= {tile2_shift_reg[55:0], 8'd0};
                
//                 fifo_shift_count <= fifo_shift_count + 4'd1;
//             end
//             else if (fifo_shift_count == 8) begin 
//                 // ADDRESS PHASE COMPLETE: Reset for the next row
//                 fifo_shift_count <= 4'd0;
//             end
//         end
//     end

//     // ZERO-DEPTH COMBINATIONAL OUTPUT
//     // Because the data physically moves to the top of the register, 
//     // we hardcode the output wires. No multiplexers generated!
//     always_comb begin
//         if (fifo_shift_count == 0) begin
//             // On the 0th count, bypass the register to output the FWFT data instantly
//             rdata_spi[15:8] = rdata_fifo[135:128];
//             rdata_spi[7:0]  = rdata_fifo[71:64];
//         end 
//         else if (fifo_shift_count < 8) begin
//             // Read directly from the top of the shift registers
//             rdata_spi[15:8] = tile1_shift_reg[63:56];
//             rdata_spi[7:0]  = tile2_shift_reg[63:56];
//         end 
//         else if (fifo_shift_count == 8) begin
//             // Output the latched row address
//             rdata_spi[15:8] = row_addr_reg;
//             rdata_spi[7:0]  = row_addr_reg;
//         end 
//         else begin
//             rdata_spi = 16'd0;
//         end
//     end

//     // Next-row read enable triggers on the 8th shift (the address phase)
//     assign fifo_rd_en_next = (fifo_shift_count == 8) && safe_shift_en;

// endmodule : fifo_intf2

module fifo_intf2 (
    `ifdef USE_POWER_PINS
        inout vccd1, 
        inout vssd1, 
    `endif
    
    input  logic                  clk,
    input  logic                  rst_n,
    
    input  logic [63:0]           rdata_0,      // 64 bits (Tile1)
    input  logic [63:0]           rdata_1,      // 64 bits (Tile2)
    input  logic [5:0]            row_addr,     // 6 bits  (Addr)
    input  logic                  empty_fifo,   // CRITICAL for safe shifting

    input  logic                  shift_en,
    output logic [15:0]           rdata_spi,
    output logic                  fifo_rd_en_next
);

    logic [3:0]  fifo_shift_count;
    
    // Two perfect 72-bit shift pipelines
    // 64 bits of pixel data + 8 bits of padded address
    logic [71:0] sr_top;
    logic [71:0] sr_bot;

    // =================================================================
    // ZERO-LOGIC OUTPUT
    // The output is literally just wires connected to the flip-flops.
    // No multiplexers. Zero combinational delay.
    // =================================================================
    assign rdata_spi = {sr_top[71:64], sr_bot[71:64]};

    // Gated shift logic (FWFT empty-check)
    logic safe_shift_en;
    assign safe_shift_en = shift_en && !empty_fifo;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin   
            fifo_shift_count <= 4'd0;
            sr_top           <= '0;
            sr_bot           <= '0;
        end
        else begin
            if (fifo_shift_count == 0) begin
                if (!safe_shift_en) begin
                    // PRE-FETCH IDLE STATE: 
                    // Continuously mirror the FWFT data into the shift registers.
                    // If empty, force 0s to prevent X-propagation and output clean blank reads.
                    sr_top <= empty_fifo ? 72'd0 : {rdata_1, 2'b00, row_addr};
                    sr_bot <= empty_fifo ? 72'd0 : {rdata_0, 2'b00, row_addr};
                end 
                else begin
                    // CYCLE 0 SHIFT:
                    // The SPI has requested the first word. Because we pre-fetched, 
                    // it is CURRENTLY reading the correct first byte via the pure wire.
                    // We must now shift the registers to prepare Byte 1 for the next clock.
                    sr_top <= {sr_top[63:0], 8'd0};
                    sr_bot <= {sr_bot[63:0], 8'd0};
                    fifo_shift_count <= 4'd1;
                end
            end
            else if (safe_shift_en) begin
                if (fifo_shift_count < 8) begin  
                    // CYCLES 1-7 SHIFT:
                    sr_top <= {sr_top[63:0], 8'd0};
                    sr_bot <= {sr_bot[63:0], 8'd0};
                    fifo_shift_count <= fifo_shift_count + 4'd1;
                end
                else if (fifo_shift_count == 8) begin 
                    // CYCLE 8: ADDRESS PHASE COMPLETE.
                    // Reset the state machine. The next clock cycle will enter 
                    // the Pre-Fetch Idle State and grab the next row's data.
                    fifo_shift_count <= 4'd0;
                end
            end
        end
    end

    // Next-row read enable triggers on the 8th shift (the address phase)
    assign fifo_rd_en_next = (fifo_shift_count == 8) && safe_shift_en;

endmodule : fifo_intf2