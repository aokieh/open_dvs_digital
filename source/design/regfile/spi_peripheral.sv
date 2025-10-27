module spi_peripheral (
    // SPI Interface
    input  logic CS_N,
    input  logic SCK,
    input  logic [3:0] COPI,
    //4 channels for data in/out 
    output logic [3:0] CIPO,
    
    // Memory Interface (SPI <-> Mem)
    output logic [`RF_AWIDTH-1:0] addr,
    output logic                  we,
    output logic                  we_out, //TODO: remove top-level later
    output logic [ `RF_WIDTH-1:0] wdata,
    output logic [  `RF_MASK-1:0] wmask,
    input  logic [ `RF_WIDTH-1:0] rdata
);

    // Two 8-bit transmissions per channel - cycle 1 is op/addr, cycle 2 all data
    // COPI[3]: data_3, xxxx_xxxx
    // COPI[2]: data_2, xxxx_xxxx
    // COPI[1]: data_1, addr
    // COPI[0]: data_0, opcode

    logic [7:0] opcode_0;       //opcode comes from COPI[0]
    logic [2:0] opcode_valid;
    
    logic [7:0] addr_0;         //addr comes from COPI[1]
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
    logic        en_rx_opcode;
    logic        en_rx_addr;
    logic        en_rx_rdata;
    logic        mem_write_next_re; // write next rising edge


    // Count bits being transmitted.
    // Used to decode opcode, addr, and data
    always_ff @(posedge SCK, posedge CS_N) begin
        if (CS_N) begin
            cycle_count <= '0;
        end else begin
            // Increment count if chip select is asserted
            cycle_count <= cycle_count + 1'b1;
        end
    end

    // Assert flags for opcode, address, and rx_data
    always_comb begin
        en_rx_opcode      = (cycle_count <= 7);  // opcode is across CH0
        en_rx_addr        = (cycle_count <= 7);  // addr is across CH1
        // Decode rx_data flag from opcode
        en_rx_rdata       = (cycle_count >= 8 && cycle_count <= 14);
        opcode_valid = opcode_0[2:0];
        mem_write_next_re = determine_write_next_re(opcode_valid[2], cycle_count);
        addr_valid   = {addr_0[4:0]};
    end

    //proper address decoding
    function automatic logic determine_write_next_re(input logic _opcode_msb, input logic [3:0] _cycle_count);
        if (_opcode_msb == 0)
            // Return 0 for read ops and opcode/addr transmission
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

    //---------------------------------------------------
    // SPI TX data to Controller on falling edge
    //---------------------------------------------------
    always_ff @(negedge SCK, posedge CS_N) begin
        if (CS_N) begin
            // Don't transmit when chip select is released
            CIPO[3:0] <= 4'd0;

        end else begin //sending out MSB down to LSB
            if (opcode_valid[2] == 0 && cycle_count > 7) begin
                if (cycle_count <= 15) begin
                    CIPO[3] <= tx_data_3[15-(cycle_count)];
                    CIPO[2] <= tx_data_2[15-(cycle_count)];
                    CIPO[1] <= tx_data_1[15-(cycle_count)];
                    CIPO[0] <= tx_data_0[15-(cycle_count)];
                end else
                    CIPO[3:0] <= 4'd0;
            end
        end
    end

    //---------------------------------------------------
    // Memory Interface Decoding
    //---------------------------------------------------
    
    //Write sampled data to memory (falling edge)
    always_ff @(negedge SCK, posedge CS_N) begin
        if (CS_N) begin
            // Don't write to mem when chip select is released
            we <= '0;
            we_out <='0;

        end else begin
            if (mem_write_next_re) begin
                we <= '1;
                we_out <='1;
            end else begin
                we <= '0;
                we_out <='0;
            end
        end
    end

    // Get word address (memory) from byte address (spi)
    // Memory is word addressed. SPI is byte-addressed.
    // Memory uses masks for byte write ops.

    // regfile is word addressing, spi is byte addressing
    // top 3 bits are word addr, bottom 2 bits are byte mask
    assign addr = addr_0[$high(addr)+2 : 2]; //Kwesi said so - word address

    // Decode data to be read from memory
    always_comb begin
        spi_tx_data = 32'd0;
        case (opcode_valid[2:0])
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

    //Decode data to be written to memory
    always_comb begin
        // case (spi_opcode[2:0])
        wdata = 32'd0;
        case (opcode_valid[2:0])
            //write byte 4 times over
            3'b100  : wdata = {(4){{rx_data_0[6:0], COPI[0]}}};
            
            //write half-word two times over
            3'b101  : wdata = {(2){
                                {rx_data_1[6:0], COPI[1]},
                                {rx_data_0[6:0], COPI[0]}
                                }};
            
            //write full word once
            3'b110  : wdata = {(1){
                                {rx_data_3[6:0], COPI[3]},
                                {rx_data_2[6:0], COPI[2]},
                                {rx_data_1[6:0], COPI[1]},
                                {rx_data_0[6:0], COPI[0]}}
                            };
            default : wdata = '0;
        endcase
    end

    //Decode byte masks from SPI address
    always_comb begin
        wmask = '0;
        case (opcode_valid[2:0])
            3'b100  : wmask[ addr_0[1:0]    ] = 1'b1;   //byte      write
            3'b101  : wmask[(addr_0[1:0])+:2] = 2'b11;  //half-word write
            3'b110  : wmask[(addr_0[1:0])+:4] = 4'hf;   //word      write
            // 3'b111  : wmask[(spi_addr[2:0])+:8] = 8'hff;
            default : wmask 				  =  '0;
        endcase
    end

endmodule : spi_peripheral