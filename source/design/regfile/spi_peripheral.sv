module spi_peripheral (
    // SPI Interface
    input  logic CS_N,
    input  logic SCK,
    input  logic [3:0] COPI,
    //TODO make 4 of these 
    output logic [3:0] CIPO,
    
    // Memory Interface (SPI <-> Mem)
    output logic [`RF_AWIDTH-1:0] addr,
    output logic                  we,
    output logic [ `RF_WIDTH-1:0] wdata,
    output logic [  `RF_MASK-1:0] wmask,
    input  logic [ `RF_WIDTH-1:0] rdata
);

    // 8 Bit opcode + 8 bit address + 8*4 bit data
    // logic [ 7:0] spi_opcode;  //TODO merge from 2 lanes
    // logic [3:0] opcode_1;
    logic [7:0] opcode_0;
    logic [2:0] opcode_valid; //opcode_0{2:0}
    
    // logic [ 7:0] spi_addr  ;  // TODO merge from 2 lanes - Byte-addressed
    // logic [3:0] addr_1;
    logic [7:0] addr_0;
    logic [4:0] addr_valid; //{addr_1[0], addr_0[3:0]}

    // logic [30:0] spi_rx_data; // the 32nd bit isnt needed due to the write mechanism
    // TODO make 4 of these
    logic [6:0] rx_data_3;
    logic [6:0] rx_data_2;
    logic [6:0] rx_data_1;
    logic [6:0] rx_data_0;
    // logic [3:0] rx_bit_count; //count to 12
    
    logic [31:0] spi_tx_data;
    //TODO make 4 of these
    logic [7:0] tx_data_3;
    logic [7:0] tx_data_2;
    logic [7:0] tx_data_1;
    logic [7:0] tx_data_0;
    // logic [2:0] tx_bit_count; //count to 8

    // logic [ 5:0] bit_count; //TODO remove this one and change
    logic [ 3:0] cycle_count;
    logic        en_rx_opcode;
    logic        en_rx_addr;
    logic        en_rx_rdata;
    logic        mem_write_next_re; // write next rising edge


    // Count bits being transmitted.
    // Used to decode opcode, addr, and data
    always_ff @(posedge SCK, posedge CS_N) begin
        if (CS_N) begin
            // Reset bit count when chip select is released
            // bit_count <= '0; 
            cycle_count <= '0;
            // tx_bit_count <= '0;
            // rx_bit_count <= '0;
        end else begin
            // Increment count if chip select is asserted
            // bit_count <= bit_count + 1'b1;
            cycle_count <= cycle_count + 1'b1;
        end
    end

    //TODO: recode the combinational flags?
    // Assert flags for opcode, address, and rx_data
    always_comb begin
        en_rx_opcode      = cycle_count inside {[0:7]};  // opcode is split CH0&1
        en_rx_addr        = cycle_count inside {[0:7]};  // addr is split across CH3&4
        // Decode rx_data flag from opcode
        en_rx_rdata       = cycle_count inside {[8:14]};
        // en_rx_rdata       = bit_count inside {[16:15+(8 << spi_opcode[1:0])-1]};
        // Decode when to write data to memory
        // mem_write_next_re = determine_write_next_re(spi_opcode, bit_count);
        opcode_valid = opcode_0[2:0];
        mem_write_next_re = determine_write_next_re(opcode_valid, cycle_count);
        // addr_valid   = {addr_1[0], addr_0[3:0]};
        addr_valid   = {addr_0[4:0]};
    end

    //TODO: proper address decoding
    function automatic logic determine_write_next_re(input logic [2:0] opcode_valid, input logic [5:0] cycle_count);
        // if (opcode[2] == 0 | bit_count < 16)
        if (opcode_valid[2] == 0)
            // Return 0 for read ops and opcode/addr transmission
            return 1'b0; //not write mode
        else
            // return bit_count == (8 << opcode[1:0])+15;
            // return (cycle_count == 4'd11); // write on last data cycle
            return (cycle_count == 4'd15);
    endfunction : determine_write_next_re


    //---------------------------------------------------
    // SPI RX from Controller on rising edge
    //---------------------------------------------------
    // Sample opcode, address, and rx_data on rising edge
    always_ff @(posedge SCK, posedge CS_N) begin
        if (CS_N) begin
            // Reset when chip select is released
                // {spi_opcode, spi_addr, spi_rx_data} <= '0;  
            // {opcode_1, opcode_0} <= '0;
            // {addr_1, addr_0} <= '0;
            {addr_0, opcode_0} <= '0;
            {rx_data_3, rx_data_2, rx_data_1, rx_data_0} <= '0;
        end else begin //TODO 
                if (en_rx_opcode) begin// Sample opcode
                    // spi_opcode  <= {spi_opcode[6:0], COPI};
                    // opcode_1 <= {opcode_1[2:0], COPI[1]};
                    opcode_0 <= {opcode_0[6:0], COPI[0]};
                end 
                if (en_rx_addr) begin   // Sample address
                // spi_addr    <= {spi_addr[6:0], COPI};
                // addr_1 <= {addr_1[2:0], COPI[3]};
                addr_0 <= {addr_0[6:0], COPI[1]};
                end 
                if (en_rx_rdata) begin // Sample rx_data TODO: this may be incorrect
                    // spi_rx_data <= {spi_rx_data[30:0], COPI}; 
                    rx_data_3 <= {rx_data_3[6:0], COPI[3]};
                    rx_data_2 <= {rx_data_2[6:0], COPI[2]};
                    rx_data_1 <= {rx_data_1[6:0], COPI[1]};
                    rx_data_0 <= {rx_data_0[6:0], COPI[0]};
                end
        end
    end

    //---------------------------------------------------
    // SPI TX data to Controller on falling edge
    //---------------------------------------------------
    always_ff @(negedge SCK, posedge CS_N) begin
        if (CS_N) begin
            // Don't transmit when chip select is released
            // CIPO <= '0;
            CIPO[3:0] <= 4'd0;

        end else begin //TODO: sending out MSB downto LSB
            // Read op: send data out
            // if (spi_opcode [2] == 0 && bit_count > 15) begin
            if (opcode_valid[2] == 0 && cycle_count > 7) begin
                // if (bit_count <= 31+16)
                if (cycle_count <= 15) begin//could use inside {[11:4]}
                    // CIPO <= spi_tx_data[31+16-bit_count];
                    CIPO[3] <= tx_data_3[15-(cycle_count)];
                    CIPO[2] <= tx_data_2[15-(cycle_count)];
                    CIPO[1] <= tx_data_1[15-(cycle_count)];
                    CIPO[0] <= tx_data_0[15-(cycle_count)];
                end else
                    // CIPO <= '0;
                    CIPO[3:0] <= 4'd0;
            end
        end
    end

    //---------------------------------------------------
    // Memory Interface Decoding
    //---------------------------------------------------
    
    //TODO: Write sampled data to memory (falling edge)
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
    // assign addr = spi_addr[$high(addr)+2 : 2];
    //regfile is word addressing, spi is byte addressing
    // top 3 bits are word addr, bottom 2 bits are byte mask
    assign addr = addr_0[$high(addr)+2 : 2]; //Kwesi said so

    // TODO: Decode data to be read from memory
    always_comb begin
        spi_tx_data = 32'd0;

        // case (spi_opcode[2:0])
        case (opcode_valid[2:0])
            // 3'b000  : spi_tx_data[31-: 8] = rdata[8*(spi_addr[1:0])+: 8];
            // 3'b001  : spi_tx_data[31-:16] = rdata[8*(spi_addr[1:0])+:16];
            // 3'b010  : spi_tx_data 		  = rdata;
            3'b000  : spi_tx_data[31-: 8] = rdata[8*(addr_valid[1:0])+: 8];
            3'b001  : spi_tx_data[31-:16] = rdata[8*(addr_valid[1:0])+:16];
            3'b010  : spi_tx_data 		  = rdata;
            default : spi_tx_data		  = 32'd0;
        endcase
        // assigning the readout data from memory
        tx_data_3 = spi_tx_data[31:24];
        tx_data_2 = spi_tx_data[23:16];
        tx_data_1 = spi_tx_data[ 15:8];
        tx_data_0 = spi_tx_data[  7:0];
    end

    // TODO: Decode data to be written to memory
    always_comb begin
        // case (spi_opcode[2:0])
        case (opcode_valid[2:0])
            // 3'b100  : wdata = {(4){{spi_rx_data[ 6:0], COPI}}};
            // 3'b101  : wdata = {(2){{spi_rx_data[14:0], COPI}}};
            // 3'b110  : wdata = {(1){{spi_rx_data[30:0], COPI}}};
            //write byte 4 times over
            // 3'b100  : wdata = {(4){{rx_data_0[6:0], COPI[0]}}};
            3'b100  : wdata = {(4){{rx_data_0[7:0]}}};
            //write half-word two times over
            3'b101  : wdata = {(2){
                                    // {rx_data_1[7:0]},
                                    // {rx_data_1[7:0]}
                                {rx_data_1[6:0], COPI[1]},
                                {rx_data_0[6:0], COPI[0]}
                                }};
            //write full word once
            3'b110  : wdata = {(1){
                                {rx_data_3[6:0], COPI[3]},
                                {rx_data_2[6:0], COPI[2]},
                                {rx_data_1[6:0], COPI[1]},
                                {rx_data_0[6:0], COPI[0]}}
                                // {rx_data_3[7:0]},
                                // {rx_data_2[7:0]},
                                // {rx_data_1[7:0]},
                                // {rx_data_0[7:0]}}
                            };
            default : wdata = '0;
        endcase
    end

    // TODO: Decode byte masks from SPI address
    always_comb begin
        wmask = '0;
        
        // case (spi_opcode[2:0]) //this code stays the same?
        case (opcode_valid[2:0])
            // 3'b100  : wmask[ spi_addr[1:0]] 	= 1'b1;
            // 3'b101  : wmask[(spi_addr[1:0])+:2] = 2'b11;
            // 3'b110  : wmask[(spi_addr[1:0])+:4] = 4'hf;
            3'b100  : wmask[ addr_0[1:0]    ] = 1'b1;   //byte write
            3'b101  : wmask[(addr_0[1:0])+:2] = 2'b11;  //hw write
            3'b110  : wmask[(addr_0[1:0])+:4] = 4'hf;   //word write
            // 3'b111  : wmask[(spi_addr[2:0])+:8] = 8'hff;
            default : wmask 					=  '0;
        endcase
    end

endmodule : spi_peripheral