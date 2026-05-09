//---------------------------------------------------------------------------
// Author: Ababakar Okieh
// Date  : May 3, 2026 
//
// Module: spi_peripheral
//
// Description: 
//  Package that defines Quad-SPI communication. (Pure Posedge Modification)
//---------------------------------------------------------------------------
`timescale 1ns/1ps

module spi_peripheral_re (
    `ifdef USE_POWER_PINS
        inout vccd1, 
        inout vssd1, 
    `endif
    // SPI Interface
    input  logic CS_N,
    input  logic SCK,
    input  logic [3:0] COPI,
    //4 channels for data in/out 
    output logic [3:0] CIPO,
    
    // Memory Interface (SPI <---> Mem)
    output logic [`RF_AWIDTH-1:0] addr_reg,
    output logic                  we_reg,
    output logic                  we_out, //TODO: remove top-level later
    output logic [ `RF_WIDTH-1:0] wdata_reg,
    output logic [  `RF_MASK-1:0] wmask_reg,
    input  logic [ `RF_WIDTH-1:0] rdata_reg,

    //FIFO Interface (SPI <---> FIFO)
    input  logic [15:0] rdata_spi_0,
    input  logic [15:0] rdata_spi_1,
    output logic [1:0] shift_en_fifo,

    // Added for SPI Continuous Read Mode
    input logic data_ready_spi,

    // Added for debug from regfile
    output logic [`RF_WIDTH-1:0] spi_last_read_data_reg,
    output logic [7:0]          opcode_0_reg,
    output logic [7:0]          addr_0_reg
);

    logic [7:0] opcode_0;       //opcode comes from COPI[0]
    logic [2:0] opcode_valid;
    
    logic [7:0] addr_0;         //addr_reg comes from COPI[1]
    logic [4:0] addr_valid; 

    // the 8th bit isnt needed due to the write mechanism
    logic [6:0] rx_data_3;
    logic [6:0] rx_data_2;
    logic [6:0] rx_data_1;
    logic [6:0] rx_data_0;
    
    logic [31:0] spi_tx_data;
    
    logic [7:0] tx_data_3;
    logic [7:0] tx_data_2;
    logic [7:0] tx_data_1;
    logic [7:0] tx_data_0;
    
    logic [ 3:0] cycle_count;
    logic [ 3:0] fifo_shift_count;
    // logic [ 6:0] fifo_tx_cycle_count;   //TODO: check if this addition is needed

    // RX mode control - data into chip
    logic        en_rx_opcode;
    logic        en_rx_addr;
    logic        en_rx_rdata;
    logic        mem_write_next_re; // write next rising edge

    // RX mode control - data into chip
    // logic       en_tx_fifo_opcode;
    // logic       en_tx_fifo_data;
    logic       en_regfile_write;
    logic       en_fifo_read;
    // Explicitly sink unused bits to prevent Verilator warnings
    wire _unused_bits = &{1'b0, opcode_0[7], addr_0[7], addr_valid[4:2]};


    //--- Counter Logic ---//
    always_ff @(posedge SCK or posedge CS_N) begin
        if (CS_N) begin
            cycle_count <= 0;
            fifo_shift_count <= 0;
            shift_en_fifo <= 2'b00;
        end else begin
        // In data streaming mode (opcode_valid == 3'b111)
        if (opcode_valid == 3'b111) begin
            // Inside SPI FSM always_ff block:
            
            if (cycle_count < 4'd13) begin          // Changed from 14
                cycle_count <= cycle_count + 1;
                shift_en_fifo <= 2'b00;
            end else if (cycle_count == 4'd13) begin // Changed from 14
                // Look-ahead trigger: Request data now so it's ready by cycle 15
                if (data_ready_spi) begin
                    shift_en_fifo <= 2'b11;
                end else begin
                    shift_en_fifo <= 2'b00;
                end
                cycle_count <= cycle_count + 1;   // To 14
            end else if (cycle_count == 4'd14) begin // New state
                shift_en_fifo <= 2'b00;
                cycle_count <= cycle_count + 1;   // To 15
            end else if (cycle_count == 4'd15) begin
                // By this cycle, rdata_spi is perfectly stable!
                shift_en_fifo <= 2'b00;
                cycle_count <= 4'd8;              // Loop back to start shifting
                fifo_shift_count <= fifo_shift_count + 1;
            end

            // After 9 bursts, reset everything for next transaction
            if (fifo_shift_count == 8 && cycle_count == 15) begin
                // cycle_count <= 0;         // Next CS_N low: fresh transaction
                cycle_count <= 4'd8;         // TODO: True continuous read mode
                fifo_shift_count <= 0;
            end
        end else begin
            // Not in FIFO streaming mode
            shift_en_fifo <= 2'b00;
            // Normal linear count
            cycle_count <= cycle_count + 1;
        end
    end
end

    // Assert flags for opcode, address, and rx_data
    always_comb begin
            // 1. DEFAULT ASSIGNMENTS - Prevents Latches and ALWCOMBORDER errors
        en_rx_opcode      = 1'b0;
        en_rx_addr        = 1'b0;
        en_rx_rdata       = 1'b0;
        opcode_valid      = 3'b000;
        en_regfile_write  = 1'b0;
        en_fifo_read      = 1'b0;
        // en_tx_fifo_opcode = 1'b0;
        // en_tx_fifo_data   = 1'b0;
        mem_write_next_re = 1'b0;
        addr_valid        = 5'b00000;

        // 2. LOGIC EVALUATION

        en_rx_opcode      = (cycle_count <= 7);  // opcode is across CH0
        en_rx_addr        = (cycle_count <= 7);  // addr_reg is across CH1
        en_rx_rdata       = (cycle_count >= 8 && 
                            cycle_count <= 14 && //TODO: glitch here <=15? 
                            !en_regfile_write && //TODO: broken
                            !en_fifo_read);  // rx_data flag from opcode
        
        opcode_valid = opcode_0[2:0];

        en_regfile_write  = (opcode_valid[2] == 1'b0 &&
                             cycle_count > 7); //&& 
                            //  cycle_count <= 15);
        en_fifo_read      = (opcode_valid == 3'b111 && 
                            fifo_shift_count < 9 && 
                            cycle_count >= 8); //&& 
                            // cycle_count <= 15);
        
        mem_write_next_re = determine_write_next_re(opcode_valid, cycle_count);
        addr_valid   = {addr_0[4:0]};

        opcode_0_reg    = {5'b00000, opcode_valid};
        addr_0_reg      = {3'b000, addr_valid};
    end

    //proper address decoding
    function automatic logic determine_write_next_re(input logic [2:0] _opcode_bits, input logic [3:0] _cycle_count);
        if (_opcode_bits <= 3'd3 || _opcode_bits == 3'd7)
            // Return 0 for read ops and opcode/addr_reg transmission
            determine_write_next_re = 1'b0; //not write mode
        else
            determine_write_next_re = (_cycle_count == 4'd15);
    endfunction                             //TODO changed for yosys from SV->V : determine_write_next_re


    //---------------------------------------------------
    // SPI RX from Controller on rising edge
    //---------------------------------------------------
    // Sample opcode, address, and rx_data on rising edge
    always_ff @(posedge SCK, posedge CS_N) begin
        if (CS_N) begin
            {addr_0, opcode_0} <= '0;
            {rx_data_3, rx_data_2, rx_data_1, rx_data_0} <= '0;
        end else begin
                if (en_rx_opcode) begin // Sample opcode
                    opcode_0 <= {opcode_0[6:0], COPI[0]};
                end 
                if (en_rx_addr) begin   // Sample address
                addr_0 <= {addr_0[6:0], COPI[1]};
                end 
                if (en_rx_rdata) begin  // Sample rx_data
                    rx_data_3 <= {rx_data_3[5:0], COPI[3]};
                    rx_data_2 <= {rx_data_2[5:0], COPI[2]};
                    rx_data_1 <= {rx_data_1[5:0], COPI[1]};
                    rx_data_0 <= {rx_data_0[5:0], COPI[0]};
                end
        end
    end

    // =======================================================
    // SPI TX to Controller on rising edge
    // =======================================================
    always_ff @(posedge SCK, posedge CS_N) begin
        if (CS_N) begin
            // Don't transmit when chip select is released
            CIPO[3:0] <= 4'd0;

        end else begin //sending out MSB down to LSB
            //if ((opcode_valid[2] == 0 && cycle_count > 7) || (opcode_valid==3'b11 && fifo_shift_count <9 )) begin
            if (en_regfile_write || en_fifo_read) begin 
                // if (cycle_count <= 15) begin
                    CIPO[3] <= tx_data_3[15-(cycle_count)];
                    CIPO[2] <= tx_data_2[15-(cycle_count)];
                    CIPO[1] <= tx_data_1[15-(cycle_count)];
                    CIPO[0] <= tx_data_0[15-(cycle_count)];
                // end else
                    // CIPO[3:0] <= 4'd0;
            end
        end
    end

    //---------------------------------------------------
    // Memory Interface Decoding
    //---------------------------------------------------
    
    // =======================================================
    // CHANGED: negedge SCK -> posedge SCK
    // =======================================================
    //Write sampled data to memory
    always_ff @(posedge SCK, posedge CS_N) begin
        if (CS_N) begin
            // Don't write to mem when chip select is released
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

    // Get word address (memory) from byte address (spi)
    // Memory is word addressed. SPI is byte-addressed.
    // Memory uses masks for byte write ops.

    // regfile is word addressing, spi is byte addressing
    // top 3 bits are word addr_reg, bottom 2 bits are byte mask
    assign addr_reg = addr_0[$high(addr_reg)+2 : 2]; //Kwesi said so - word address

    // Decode data to be read from memory
    always_comb begin
        spi_tx_data = 32'd0;
        case (opcode_valid[2:0])
            // 3'b000  : spi_tx_data[31-: 8] = rdata_reg[8*(addr_valid[1:0])+: 8];
            // 3'b001  : spi_tx_data[31-:16] = rdata_reg[8*(addr_valid[1:0])+:16];
            3'b000  : spi_tx_data[0+: 8] = rdata_reg[8*(addr_valid[1:0])+: 8];
            3'b001  : spi_tx_data[0+:16] = rdata_reg[8*(addr_valid[1:0])+:16];
            3'b010  : spi_tx_data         = rdata_reg;

            3'b111  : spi_tx_data          = {rdata_spi_1, rdata_spi_0}; // TODO: read from FIFO
            // 3'b111  : spi_tx_data        = data_ready_spi ? {rdata_spi_1, rdata_spi_0} : 32'hFFFF_FFFF;
            default : spi_tx_data         = 32'd0;
        endcase
        // assigning the readout data from memory
        tx_data_3 = spi_tx_data[31:24];
        tx_data_2 = spi_tx_data[23:16];
        tx_data_1 = spi_tx_data[ 15:8];
        tx_data_0 = spi_tx_data[  7:0];

        spi_last_read_data_reg = spi_tx_data;
    end

    //Decode data to be written to memory
    always_comb begin
        // case (spi_opcode[2:0])
        wdata_reg = 32'd0;
        case (opcode_valid[2:0])
            //write byte 4 times over
            3'b100  : wdata_reg = {(4){{rx_data_0[6:0], COPI[0]}}};
            
            //write half-word two times over
            3'b101  : wdata_reg = {(2){
                                {rx_data_1[6:0], COPI[1]},
                                {rx_data_0[6:0], COPI[0]}
                                }};
            
            //write full word once
            3'b110  : wdata_reg = {(1){
                                {rx_data_3[6:0], COPI[3]},
                                {rx_data_2[6:0], COPI[2]},
                                {rx_data_1[6:0], COPI[1]},
                                {rx_data_0[6:0], COPI[0]}}
                            };
            // 3'b111 this is used for reading from FIFO
            default : wdata_reg = '0;
        endcase
    end

    //Decode byte masks from SPI address
    always_comb begin
        wmask_reg = '0;
        case (opcode_valid[2:0])
            3'b100  : wmask_reg[ addr_0[1:0]    ] = 1'b1;   //byte      write
            3'b101  : wmask_reg[(addr_0[1:0])+:2] = 2'b11;  //half-word write
            3'b110  : wmask_reg[(addr_0[1:0])+:4] = 4'hf;   //word      write
            // 3'b111  : wmask_reg[(spi_addr[2:0])+:8] = 8'hff;
            default : wmask_reg                   =  '0;
        endcase
    end

endmodule : spi_peripheral_re