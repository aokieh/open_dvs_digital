//---------------------------------------------------------------------------
// Author: Ababakar Okieh
// Date  : March 23, 2026
//
// Module: spi_peripheral_cr
//
// Description: 
//  Package that defines Quad-SPI communication.
//---------------------------------------------------------------------------
`timescale 1ns/1ps

module spi_peripheral_cr (
    `ifdef USE_POWER_PINS
        inout vccd1, 
        inout vssd1, 
    `endif
    // SPI Interface
    input  logic CS_N,
    input  logic SCK,
    input  logic [3:0] COPI,
    output logic [3:0] CIPO,
    
    // Memory Interface (SPI <---> Mem)
    output logic [`RF_AWIDTH-1:0] addr_reg,
    output logic                  we_reg,
    output logic                  we_out,
    output logic [ `RF_WIDTH-1:0] wdata_reg,
    output logic [  `RF_MASK-1:0] wmask_reg,
    input  logic [ `RF_WIDTH-1:0] rdata_reg,

    //FIFO Interface (SPI <---> FIFO)
    // input  logic [15:0] rdata_spi_0,
    // input  logic [15:0] rdata_spi_1,
    // output logic [1:0] shift_en_fifo,

    // FIFO Interface (SPI <---> 4x FIFOs)
    input  logic [ 9:0] fifo_rdata_0, fifo_rdata_1, fifo_rdata_2, fifo_rdata_3,
    input  logic        fifo_empty_0, fifo_empty_1, fifo_empty_2, fifo_empty_3,
    output logic        fifo_rd_en_0, fifo_rd_en_1, fifo_rd_en_2, fifo_rd_en_3

    // output logic global_data_ready
);

    logic [7:0] opcode_0;
    logic [2:0] opcode_valid;
    logic [7:0] addr_0;
    logic [4:0] addr_valid; 

    // 7-bit registers for the combinational write bypass
    logic [6:0] rx_data_3;
    logic [6:0] rx_data_2;
    logic [6:0] rx_data_1;
    logic [6:0] rx_data_0;
    
    logic [31:0] spi_tx_data;
    logic [7:0] tx_data_3;
    logic [7:0] tx_data_2;
    logic [7:0] tx_data_1;
    logic [7:0] tx_data_0;
    
    logic [4:0] cycle_count;

    logic        en_rx_opcode;
    logic        en_rx_addr;
    logic        en_rx_rdata;
    logic        mem_write_next_re; 

    logic       en_tx_fifo_opcode;
    logic       en_tx_fifo_data;
    logic       en_regfile_write;
    logic       en_fifo_read;
    
    localparam [9:0] DUMMY_PATTERN = 10'h2AA;
    localparam [9:0] EMPTY_PAD = 10'h3CC; 
    logic dummy_phase;

    // 1. Declare Shadow Registers to freeze the data
    logic [9:0] shadow_reg_0, shadow_reg_1, shadow_reg_2, shadow_reg_3;

    //---------------------------------------------------
    // SPI Control, FIFO Handshake, and Data Pipeline 
    //---------------------------------------------------
    always_ff @(posedge SCK or posedge CS_N) begin
        if (CS_N) begin
            cycle_count   <= '0;
            dummy_phase   <= 1'b1;
            {fifo_rd_en_3, fifo_rd_en_2, fifo_rd_en_1, fifo_rd_en_0} <= 4'b0;
        end else begin
            if (opcode_valid == 3'b111) begin
                cycle_count <= (cycle_count < 5'd17) ? cycle_count + 1 : 5'd8;
                if (cycle_count == 5'd17) dummy_phase <= 1'b0;

                // 1. THE READ REQUEST (Decided strictly at Cycle 16)
                {fifo_rd_en_3, fifo_rd_en_2, fifo_rd_en_1, fifo_rd_en_0} <= 
                    (cycle_count == 16) ? {~fifo_empty_3, ~fifo_empty_2, ~fifo_empty_1, ~fifo_empty_0} : 4'b0;

                // 2. THE CDC FIREWALL (Latched at Cycle 17 based ONLY on the Cycle 16 decision)
                if (cycle_count == 17) begin
                    shadow_reg_0 <= fifo_rd_en_0 ? fifo_rdata_0 : EMPTY_PAD;
                    shadow_reg_1 <= fifo_rd_en_1 ? fifo_rdata_1 : EMPTY_PAD;
                    shadow_reg_2 <= fifo_rd_en_2 ? fifo_rdata_2 : EMPTY_PAD;
                    shadow_reg_3 <= fifo_rd_en_3 ? fifo_rdata_3 : EMPTY_PAD;
                end
            end else begin
                cycle_count <= cycle_count + 1; 
                {fifo_rd_en_3, fifo_rd_en_2, fifo_rd_en_1, fifo_rd_en_0} <= 4'b0;
            end
        end
    end

    // Assert flags for opcode, address, and rx_data
    always_comb begin
        opcode_valid = opcode_0[2:0]; 

        en_rx_opcode      = (cycle_count <= 7);  
        en_rx_addr        = (cycle_count <= 7);  
        
        en_rx_rdata       = (cycle_count >= 8 && cycle_count <= 14) && (opcode_valid != 3'b111); 

        en_regfile_write  = (opcode_valid[2] == 1'b0 &&
                             cycle_count > 7 && 
                             cycle_count <= 15);
                             
        en_fifo_read      = (opcode_valid == 3'b111 && 
                            cycle_count >= 8 && 
                            cycle_count <= 17);
        
        mem_write_next_re = determine_write_next_re(opcode_valid, cycle_count);
        addr_valid   = {addr_0[4:0]};
    end

    function automatic logic determine_write_next_re(input logic [2:0] _opcode_bits, input logic [4:0] _cycle_count);
        if (_opcode_bits <= 3'd3 || _opcode_bits == 3'd7)
            determine_write_next_re = 1'b0; 
        else
            determine_write_next_re = (_cycle_count == 5'd15);
    endfunction                             


    //---------------------------------------------------
    // SPI RX from Controller on rising edge
    //---------------------------------------------------
    always_ff @(posedge SCK, posedge CS_N) begin
        if (CS_N) begin
            {addr_0, opcode_0} <= '0;
            {rx_data_3, rx_data_2, rx_data_1, rx_data_0} <= '0;
        end else begin
                if (en_rx_opcode) begin 
                    opcode_0 <= {opcode_0[6:0], COPI[0]};
                end 
                if (en_rx_addr) begin   
                    addr_0 <= {addr_0[6:0], COPI[1]};
                end 
                if (en_rx_rdata) begin  
                    rx_data_3 <= {rx_data_3[5:0], COPI[3]};
                    rx_data_2 <= {rx_data_2[5:0], COPI[2]};
                    rx_data_1 <= {rx_data_1[5:0], COPI[1]};
                    rx_data_0 <= {rx_data_0[5:0], COPI[0]};
                end
        end
    end

    //---------------------------------------------------
    // SPI TX Data Shift-Out
    //---------------------------------------------------
    always_ff @(negedge SCK, posedge CS_N) begin
        if (CS_N) begin
            CIPO <= 4'd0;
        end else begin
            if (opcode_valid == 3'b111 && cycle_count >= 8 && cycle_count <= 17) begin
                if (dummy_phase) begin 
                    CIPO[0] <= DUMMY_PATTERN[17 - cycle_count];
                    CIPO[1] <= DUMMY_PATTERN[17 - cycle_count];
                    CIPO[2] <= DUMMY_PATTERN[17 - cycle_count];
                    CIPO[3] <= DUMMY_PATTERN[17 - cycle_count];
                end else begin 
                    // 3. SHIFT FROM THE FROZEN SHADOW REGISTER
                    CIPO[0] <= shadow_reg_0[17 - cycle_count];
                    CIPO[1] <= shadow_reg_1[17 - cycle_count];
                    CIPO[2] <= shadow_reg_2[17 - cycle_count];
                    CIPO[3] <= shadow_reg_3[17 - cycle_count];
                end
            end 
            else if (en_regfile_write || en_fifo_read) begin 
                if (cycle_count <= 15) begin
                    CIPO[3] <= tx_data_3[15 - cycle_count];
                    CIPO[2] <= tx_data_2[15 - cycle_count];
                    CIPO[1] <= tx_data_1[15 - cycle_count];
                    CIPO[0] <= tx_data_0[15 - cycle_count];
                end else begin
                    CIPO <= 4'd0;
                end
            end
        end
    end


    //---------------------------------------------------
    // Memory Interface Decoding
    //---------------------------------------------------
    always_ff @(negedge SCK, posedge CS_N) begin
        if (CS_N) begin
            we_reg <= '0;
            we_out <='0;
        end else begin
            if (mem_write_next_re) begin
                we_reg <= '1;
                we_out <='1;
            end else begin
                we_reg <= '0;
                we_out <='0;
            end
        end
    end

    assign addr_reg = addr_0[$high(addr_reg)+2 : 2];
    // assign global_data_ready = ~(fifo_empty_0 & fifo_empty_1
    //                              fifo_empty_2 & fifo_empty_3);

    always_comb begin
        spi_tx_data = 32'd0;
        case (opcode_valid[2:0])
            3'b000  : spi_tx_data[0+: 8] = rdata_reg[8*(addr_valid[1:0])+: 8];
            3'b001  : spi_tx_data[0+:16] = rdata_reg[8*(addr_valid[1:0])+:16];
            3'b010  : spi_tx_data        = rdata_reg;
            3'b111  : spi_tx_data        = 32'd0; 
            default : spi_tx_data        = 32'd0;
        endcase
        tx_data_3 = spi_tx_data[31:24];
        tx_data_2 = spi_tx_data[23:16];
        tx_data_1 = spi_tx_data[ 15:8];
        tx_data_0 = spi_tx_data[  7:0];
    end

    always_comb begin
        wdata_reg = 32'd0;
        case (opcode_valid[2:0])
            3'b100  : wdata_reg = {4{rx_data_0[6:0], COPI[0]}};
            3'b101  : wdata_reg = {2{{rx_data_1[6:0], COPI[1]}, {rx_data_0[6:0], COPI[0]}}};
            3'b110  : wdata_reg = { {rx_data_3[6:0], COPI[3]},
                                    {rx_data_2[6:0], COPI[2]},
                                    {rx_data_1[6:0], COPI[1]},
                                    {rx_data_0[6:0], COPI[0]} };
            default : wdata_reg = 32'd0;
        endcase
    end

    always_comb begin
        wmask_reg = '0;
        case (opcode_valid[2:0])
            3'b100  : wmask_reg[ addr_0[1:0]    ] = 1'b1;  
            3'b101  : wmask_reg[(addr_0[1:0])+:2] = 2'b11; 
            3'b110  : wmask_reg[(addr_0[1:0])+:4] = 4'hf;  
            default : wmask_reg                   =  '0;
        endcase
    end

endmodule : spi_peripheral_cr