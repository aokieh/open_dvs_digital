//---------------------------------------------------------------------------
// Author: Kwesi Buabeng Debrah
// Date  : June 13, 2025
//
// Module: sram_fifo_wrapper_1port
//
// Description: 
//  Module that handles FIFO-to-SRAM interface with First Word Fall Through
//  and look-ahead.
//  Read data is available in the same cycle rd_en is asserted.
//
//  NOTE: This is a single-port variant.
//---------------------------------------------------------------------------


import aer_pkg::*;


module sram_fifo_wrapper_1port #(
    parameter WIDTH=16, DEPTH=16, SIZE=SIZE_BT,
    localparam AWIDTH     = $clog2(DEPTH * WIDTH / 8), // Byte address width
    localparam FIFO_DEPTH = DEPTH * WIDTH / 2**(3+SIZE),
    localparam BIT_END    = $clog2(WIDTH / 8)
) (
    sram_fifo_wrapper_intf.fifo fifo_intf,
    sram_fifo_wrapper_intf.sram sram_intf
);

    logic              first_word;
    logic              write, read; // Track actual write/read operations
    logic [AWIDTH-1:0] wr_ptr, rd_ptr, rd_ptr_prev;
    logic [ WIDTH-1:0] temp_sram_rdata;
    logic [$clog2(FIFO_DEPTH):0] counter; // Keep track of number of elements in FIFO

    logic             fwft_valid; // Valid signal for first word fall through
    logic [WIDTH-1:0] fwft_reg; // Register to hold first word fall through data


    //---------------------------------------------------------------------------
    // FIFO Interface
    //---------------------------------------------------------------------------
    assign fifo_intf.fifo_empty  = (counter == 0);
    assign fifo_intf.fifo_full   = (counter == FIFO_DEPTH);
    assign fifo_intf.fifo_numel  = counter;
    
    assign write                 = fifo_intf.fifo_wr_en && !fifo_intf.fifo_full;
    assign read                  = fifo_intf.fifo_rd_en && !fifo_intf.fifo_empty;


    //---------------------------------------------------------------------------
    // SRAM Interface
    //---------------------------------------------------------------------------
    assign sram_intf.ce_a    = write || read;
    assign sram_intf.ce_b    = '0;
    assign sram_intf.we_b    = '0;
    assign sram_intf.wdata_a = {WIDTH/$bits(fifo_intf.fifo_wdata){fifo_intf.fifo_wdata}};
    assign sram_intf.wdata_b = '0;


    //---------------------------------------------------------------------------
    // Signal Multiplexer (Write Enable A & Address A)
    //---------------------------------------------------------------------------
    always_comb begin
        case ({write, read})
            2'b01: begin // Read
                sram_intf.we_a        = 0;
                fifo_intf.fifo_wr_ptr = rd_ptr;
            end
            2'b10: begin // Write
                sram_intf.we_a        = 1;
                fifo_intf.fifo_wr_ptr = wr_ptr;
            end
            default: begin
                sram_intf.we_a        = 0;
                fifo_intf.fifo_wr_ptr = '0;
            end
        endcase
    end


    //---------------------------------------------------------------------------
    // Decode FIFO rdata
    //---------------------------------------------------------------------------
    always_comb begin
        temp_sram_rdata = first_word ? fwft_reg : sram_intf.rdata_a;

        case (SIZE)
            SIZE_BT: begin
                rd_ptr_prev          = rd_ptr - 1;
                fifo_intf.fifo_rdata = temp_sram_rdata[8*(rd_ptr_prev[BIT_END-1:0]) +:  8];
            end
            SIZE_HW: begin
                rd_ptr_prev          = rd_ptr - 2;
                fifo_intf.fifo_rdata = temp_sram_rdata[8*(rd_ptr_prev[BIT_END-1:0]) +: 16];
            end
            SIZE_WD: begin
                rd_ptr_prev          = rd_ptr - 4;
                fifo_intf.fifo_rdata = temp_sram_rdata[8*(rd_ptr_prev[BIT_END-1:0]) +: 32];
            end
            SIZE_DW: begin
                rd_ptr_prev          = rd_ptr - 8;
                fifo_intf.fifo_rdata = temp_sram_rdata[8*(rd_ptr_prev[BIT_END-1:0]) +: 64];
            end
            default: begin
                rd_ptr_prev          = rd_ptr - 1;
                fifo_intf.fifo_rdata = temp_sram_rdata[8*(rd_ptr_prev[BIT_END-1:0]) +:  8];
            end
        endcase
        
    end


    //---------------------------------------------------------------------------
    // FIFO Numel Counter
    //---------------------------------------------------------------------------
    always_ff @(posedge fifo_intf.clk, negedge fifo_intf.rst_n) begin
        if (!fifo_intf.rst_n)
            counter <= '0;

        else begin
            if (!fifo_intf.fifo_rst_n) // Synchronous reset from RF Interface
                counter <= '0;

            else begin
                if (write && !read)
                    counter <= counter + 1;
                else if (!write && read)
                    counter <= counter - 1;
            end
        end
    end


    //---------------------------------------------------------------------------
    // Write to FIFO
    //---------------------------------------------------------------------------
    always_ff @(posedge fifo_intf.clk, negedge fifo_intf.rst_n) begin
        if (!fifo_intf.rst_n)
            wr_ptr <= '0;

        else begin
            if (!fifo_intf.fifo_rst_n) // Synchronous reset from RF Interface
                wr_ptr <= '0;

            else begin
                if (write) begin
                    case (SIZE)
                        SIZE_BT: wr_ptr <= wr_ptr + 1; // Byte
                        SIZE_HW: wr_ptr <= wr_ptr + 2; // Half-word
                        SIZE_WD: wr_ptr <= wr_ptr + 4; // Word
                        SIZE_DW: wr_ptr <= wr_ptr + 8; // Double-word
                        default: wr_ptr <= wr_ptr + 1; // Default to byte
                    endcase
                end
            end
        end
    end


    //---------------------------------------------------------------------------
    // Read from FIFO
    //---------------------------------------------------------------------------
    always_ff @(posedge fifo_intf.clk, negedge fifo_intf.rst_n) begin
        if (!fifo_intf.rst_n)
            rd_ptr <= '0;
            
        else begin
            if (!fifo_intf.fifo_rst_n) // Synchronous reset from RF Interface
                rd_ptr <= '0;

            else begin
                if (
                    (read) || 
                    (fwft_valid && rd_ptr == 0) // Only increment if starting from initial empty state
                ) begin
                    case (SIZE)
                        SIZE_BT: rd_ptr <= rd_ptr + 1; // Byte
                        SIZE_HW: rd_ptr <= rd_ptr + 2; // Half-word
                        SIZE_WD: rd_ptr <= rd_ptr + 4; // Word
                        SIZE_DW: rd_ptr <= rd_ptr + 8; // Double-word
                        default: rd_ptr <= rd_ptr + 1; // Default to byte
                    endcase
                end
            end
        end
    end


    //---------------------------------------------------------------------------
    // First Word Fall Through (FWFT) Logic
    //---------------------------------------------------------------------------
    always_ff @(posedge fifo_intf.clk, negedge fifo_intf.rst_n) begin
        if (!fifo_intf.rst_n) begin
            fwft_reg   <= '0;
            fwft_valid <= 0;
            first_word <= 0;
        end

        else begin
            if (!fifo_intf.fifo_rst_n) begin // Synchronous reset from RF Interface
                fwft_reg   <= '0;
                fwft_valid <= 0;
                first_word <= 0;
            end

            else begin

                if (write && counter == 0 && !fwft_valid) begin
                    fwft_valid <= 1;
                    fwft_reg   <= {WIDTH/$bits(fifo_intf.fifo_wdata){fifo_intf.fifo_wdata}};

                    first_word <= 1; // Update first word when setting fwft_valid
                end
                else begin
                    fwft_valid <= 0;
                end

                if (read)
                    first_word <= 0; // Clear first word when reading

            end
        end

    end


endmodule : sram_fifo_wrapper_1port
