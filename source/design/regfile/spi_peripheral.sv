
module spi_peripheral (
    // SPI Interface
    input  logic CS_N,
    input  logic SCK,
    input  logic COPI,
    output logic CIPO,
    
    // Memory Interface (SPI <-> Mem)
    output logic [`RF_AWIDTH-1:0] addr,
    output logic                  we,
    output logic [ `RF_WIDTH-1:0] wdata,
    output logic [  `RF_MASK-1:0] wmask,
    input  logic [ `RF_WIDTH-1:0] rdata
);

    // 8 Bit opcode + 8 bit address + 8*4 bit data
    logic [ 7:0] spi_opcode;
    logic [ 7:0] spi_addr  ;  // Byte-addressed
    logic [30:0] spi_rx_data; // the 32nd bit isnt needed due to the write mechanism
    logic [31:0] spi_tx_data;
    logic [ 5:0] bit_count;
    logic        en_rx_opcode;
    logic        en_rx_addr;
    logic        en_rx_rdata;
    logic        mem_write_next_re; // write next rising edge


    // Count bits being transmitted.
    // Used to decode opcode, addr, and data
    always_ff @(posedge SCK, posedge CS_N) begin
        if (CS_N) begin
            // Reset bit count when chip select is released
            bit_count <= '0; 

        end else begin
            // Increment count if chip select is asserted
            bit_count <= bit_count + 1'b1;
        end
    end


    // Assert flags for opcode, address, and rx_data
    always_comb begin
        en_rx_opcode      = bit_count inside {[0:7]};  // LSByte is opcode
        en_rx_addr        = bit_count inside {[8:15]}; // Next Byte is address
        // Decode rx_data flag from opcode
        en_rx_rdata       = bit_count inside {[16:15+(8 << spi_opcode[1:0])-1]};
        // Decode when to write data to memory
        mem_write_next_re = determine_write_next_re(spi_opcode, bit_count);
    end

    function automatic logic determine_write_next_re(input logic [7:0] opcode, input logic [5:0] bit_count);
        if (opcode[2] == 0 | bit_count < 16)
            // Return 0 for read ops and opcode/addr transmission
            return 1'b0;
        else
            return bit_count == (8 << opcode[1:0])+15;
    endfunction : determine_write_next_re


    //---------------------------------------------------
    // SPI RX from Controller on rising edge
    //---------------------------------------------------
    // Sample opcode, address, and rx_data on rising edge
    always_ff @(posedge SCK, posedge CS_N) begin
        if (CS_N) 
            // Reset when chip select is released
            {spi_opcode, spi_addr, spi_rx_data} <= '0;

        else begin
            if (en_rx_opcode) // Sample opcode
                spi_opcode  <= {spi_opcode[6:0], COPI};
            if (en_rx_addr)   // Sample address
                spi_addr    <= {spi_addr[6:0], COPI};
            if (en_rx_rdata)  // Sample rx_data
                spi_rx_data <= {spi_rx_data[30:0], COPI}; 
        end
    end


    //---------------------------------------------------
    // SPI TX data to Controller on falling edge
    //---------------------------------------------------
    always_ff @(negedge SCK, posedge CS_N) begin
        if (CS_N) begin
            // Don't transmit when chip select is released
            CIPO <= '0;

        end else begin
            // Read op: send data out
            if (spi_opcode[2] == 0 && bit_count > 15) begin
                if (bit_count <= 31+16)
                    CIPO <= spi_tx_data[31+16-bit_count];
                else
                    CIPO <= '0;
            end
        end
    end


    //---------------------------------------------------
    // Memory Interface Decoding
    //---------------------------------------------------
    
    // Write sampled data to memory (falling edge)
    always_ff @(negedge SCK, posedge CS_N) begin
        if (CS_N) begin
            // Don't write to mem when chip select is released
            we <= '0;

        end else begin
            if (mem_write_next_re)
                we <= '1;
            else
                we <= '0;
        end
    end

    // Get word address (memory) from byte address (spi)
    // Memory is word addressed. SPI is byte-addressed.
    // Memory uses masks for byte write ops.
    assign addr = spi_addr[$high(addr)+2 : 2];

    // Decode data to be read from memory
    always_comb begin
        spi_tx_data = '0;

        case (spi_opcode[2:0])
            3'b000  : spi_tx_data[31-: 8] = rdata[8*(spi_addr[1:0])+: 8];
            3'b001  : spi_tx_data[31-:16] = rdata[8*(spi_addr[1:0])+:16];
            3'b010  : spi_tx_data 		  = rdata;
            default : spi_tx_data		  = '0;
        endcase
    end

    // Decode data to be written to memory
    always_comb begin
        case (spi_opcode[2:0])
            3'b100  : wdata = {(4){{spi_rx_data[ 6:0], COPI}}};
            3'b101  : wdata = {(2){{spi_rx_data[14:0], COPI}}};
            3'b110  : wdata = {(1){{spi_rx_data[30:0], COPI}}};
            default : wdata = '0;
        endcase
    end

    // Decode byte masks from SPI address
    always_comb begin
        wmask = '0;
        
        case (spi_opcode[2:0])
            3'b100  : wmask[ spi_addr[1:0]] 	= 1'b1;
            3'b101  : wmask[(spi_addr[1:0])+:2] = 2'b11;
            3'b110  : wmask[(spi_addr[1:0])+:4] = 4'hf;
            // 3'b111  : wmask[(spi_addr[2:0])+:8] = 8'hff;
            default : wmask 					=  '0;
        endcase
    end

endmodule : spi_peripheral
