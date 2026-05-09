
// Memory map: read/write configuration
`define mem_map(signal, byte_addr) \
    begin \
        int __row, __lsb; \
        __row = (byte_addr) >> ROW_DIV; \
        __lsb = (byte_addr) % `LSB_DIV; \
        signal = mem_in[__row][8*__lsb +: $bits(signal)]; \
        mem_out[__row][8*__lsb +: $bits(signal)] = signal; \
    end

// Memory map: read-only configuration
`define mem_map_ro(signal, byte_addr) \
    begin \
        int __row, __lsb; \
        __row = (byte_addr) >> ROW_DIV; \
        __lsb = (byte_addr) % `LSB_DIV; \
        mem_out[__row][8*__lsb +: $bits(signal)] = signal; \
    end

// Memory map: pulse on write - LEAST SIG BYTE
`define mem_map_pulse(signal, row, lsb) \
    signal <= 0; \
    if (we_reg && (addr_reg==row) && wmask_reg[lsb]) \
	    signal <= 1;



module regfile (
    `ifdef USE_POWER_PINS
        inout vccd1, 
        inout vssd1, 
    `endif
    input  logic                  clk,
    input  logic                  rst_n,

    // Memory Interface (SPI <-> Mem)
    input  logic [`RF_AWIDTH-1:0] addr_reg,
    input  logic                  we_reg,
    input  logic [ `RF_WIDTH-1:0] wdata_reg,
    input  logic [  `RF_MASK-1:0] wmask_reg,
    output logic [ `RF_WIDTH-1:0] rdata_reg,

    input logic     [7:0]            opcode_0_reg, // last addr
    input logic     [7:0]              addr_0_reg, // last opcode
    // input logic  [ `RF_WIDTH-1:0] spi_last_write_data_reg, // last mem_read
    input logic  [ `RF_WIDTH-1:0] spi_last_read_data_reg,  // last mem_write

    // FIFO
    output logic                    fifo_rst_n_reg,
    // input  logic                    fifo_empty,
    // input  logic                    fifo_full,
    // output logic                    fifo_rd_en_reg,
    input  logic [`FIFO_AWIDTH-1:0] fifo_numel_reg,
    input  logic [`FIFO_AWIDTH-1:0] fifo_debug_top,
    input  logic [`FIFO_AWIDTH-1:0] fifo_debug_bot,
    // input  logic [ `FIFO_WIDTH-1:0] fifo_rdata,

    // IRQ
    // output logic [9:0] irq_deassert_thresh_reg,
    // output logic [9:0] irq_assert_thresh_reg,

    // DAC
    // output logic [`DAC_WIDTH-1:0] dac_config [`NUM_DACS],
    output logic [`DAC_WIDTH-1:0] dac_config_0,
    output logic [`DAC_WIDTH-1:0] dac_config_1,
    output logic [`DAC_WIDTH-1:0] dac_config_2,
    output logic [`DAC_WIDTH-1:0] dac_config_3,
    output logic [`DAC_WIDTH-1:0] dac_config_4, 
    output logic [`DAC_WIDTH-1:0] dac_config_5,
    output logic [`DAC_WIDTH-1:0] dac_config_6,
    output logic [`DAC_WIDTH-1:0] dac_config_7,
    output logic [`DAC_WIDTH-1:0] dac_config_8,
    output logic [`DAC_WIDTH-1:0] dac_config_9,

    // FSM
    output logic                     fsm_rst_n_reg,
    input logic [7:0]            fsm_ctrl_byte_top,
    input logic [7:0]            fsm_ctrl_byte_bot,
    // Programmable Imager Speed
    output logic [7:0] event_rate_reg,

    // Programmable Timing Inputs (14-BIT TUNING)
    output logic [13:0]  p_pre_charge,
    output logic [13:0]  p_buffer,
    output logic [13:0]  p_detect,
    output logic [13:0]  p_on_detect,
    output logic [13:0]  p_off_detect,
    output logic [13:0]  p_rst,

    // Rui
    // output logic [7:0]            fine_code,
    // output logic [7:0]            nfine_code,
    // output logic [7:0]            coarse_onehot,
    // output logic [9:0]            bias_combined,

    output logic [`FINE_CODE_WIDTH-1:0] fine_code_0,
    output logic [`FINE_CODE_WIDTH-1:0] fine_code_1,
    output logic [`FINE_CODE_WIDTH-1:0] fine_code_2,
    output logic [`FINE_CODE_WIDTH-1:0] fine_code_3,
    output logic [`FINE_CODE_WIDTH-1:0] fine_code_4,
    output logic [`FINE_CODE_WIDTH-1:0] fine_code_5,
    output logic [`FINE_CODE_WIDTH-1:0] fine_code_6,
    output logic [`FINE_CODE_WIDTH-1:0] fine_code_7,
    output logic [`FINE_CODE_WIDTH-1:0] fine_code_8,
    output logic [`FINE_CODE_WIDTH-1:0] fine_code_9,

    output logic [`nFINE_CODE_WIDTH-1:0] nfine_code_0,
    output logic [`nFINE_CODE_WIDTH-1:0] nfine_code_1,
    output logic [`nFINE_CODE_WIDTH-1:0] nfine_code_2,
    output logic [`nFINE_CODE_WIDTH-1:0] nfine_code_3,
    output logic [`nFINE_CODE_WIDTH-1:0] nfine_code_4,
    output logic [`nFINE_CODE_WIDTH-1:0] nfine_code_5,
    output logic [`nFINE_CODE_WIDTH-1:0] nfine_code_6,
    output logic [`nFINE_CODE_WIDTH-1:0] nfine_code_7,
    output logic [`nFINE_CODE_WIDTH-1:0] nfine_code_8,
    output logic [`nFINE_CODE_WIDTH-1:0] nfine_code_9,

    output logic [`COARSE_CODE_WIDTH-1:0] coarse_code_0,
    output logic [`COARSE_CODE_WIDTH-1:0] coarse_code_1,
    output logic [`COARSE_CODE_WIDTH-1:0] coarse_code_2,
    output logic [`COARSE_CODE_WIDTH-1:0] coarse_code_3,
    output logic [`COARSE_CODE_WIDTH-1:0] coarse_code_4,
    output logic [`COARSE_CODE_WIDTH-1:0] coarse_code_5,
    output logic [`COARSE_CODE_WIDTH-1:0] coarse_code_6,
    output logic [`COARSE_CODE_WIDTH-1:0] coarse_code_7,
    output logic [`COARSE_CODE_WIDTH-1:0] coarse_code_8,
    output logic [`COARSE_CODE_WIDTH-1:0] coarse_code_9,

    output logic [`BIAS_COMBINED_WIDTH-1:0] LowBiasInterfaceEn,
    output logic [`BIAS_COMBINED_WIDTH-1:0] nLowBiasInterfaceEn,//inv LowBiasInterfaceEn
    output logic [`BIAS_COMBINED_WIDTH-1:0] CoarseOneHotLowBiasEn,
    output logic [`BIAS_COMBINED_WIDTH-1:0] LowBiasBuffEn,
    output logic [`BIAS_COMBINED_WIDTH-1:0] nLowBiasBuffEn, //inv nLowBiasBuffEn
    output logic [`BIAS_COMBINED_WIDTH-1:0] nBiasEn,
    output logic [`BIAS_COMBINED_WIDTH-1:0] pBiasEn,        //inv pBiasEn
    output logic [`BIAS_COMBINED_WIDTH-1:0] BiasEnable,
    output logic [`BIAS_COMBINED_WIDTH-1:0] BiasDisable     //inv BiasEnable
);
    localparam ROW_DIV = $clog2(`LSB_DIV);
    logic [`RF_WIDTH-1:0] mem_in  [`RF_DEPTH];
    logic [`RF_WIDTH-1:0] mem_out [`RF_DEPTH];

    //  DAC assignments (Registers <--> Ports)
    logic [`DAC_WIDTH-1:0] dac_configs [`NUM_DACS];

    assign dac_config_0 = dac_configs[0];
    assign dac_config_1 = dac_configs[1];
    assign dac_config_2 = dac_configs[2];
    assign dac_config_3 = dac_configs[3];

    assign dac_config_4 = dac_configs[4];
    assign dac_config_5 = dac_configs[5];
    assign dac_config_6 = dac_configs[6];
    assign dac_config_7 = dac_configs[7];
    assign dac_config_8 = dac_configs[8];
    assign dac_config_9 = dac_configs[9];

    //  Fine Code assignments (Registers <--> Bias Gen)
    logic [`FINE_CODE_WIDTH-1:0] fine_codes [`NUM_FINE_CODES];

    assign fine_code_0 = fine_codes[0];
    assign fine_code_1 = fine_codes[1];
    assign fine_code_2 = fine_codes[2];
    assign fine_code_3 = fine_codes[3];
    assign fine_code_4 = fine_codes[4];

    assign fine_code_5 = fine_codes[5];
    assign fine_code_6 = fine_codes[6];
    assign fine_code_7 = fine_codes[7];
    assign fine_code_8 = fine_codes[8];
    assign fine_code_9 = fine_codes[9];

    //  nFine Code assignments (Registers <--> Bias Gen)
    logic [`nFINE_CODE_WIDTH-1:0] nfine_codes [`NUM_nFINE_CODES];

    assign nfine_code_0 = nfine_codes[0];
    assign nfine_code_1 = nfine_codes[1];
    assign nfine_code_2 = nfine_codes[2];
    assign nfine_code_3 = nfine_codes[3];
    assign nfine_code_4 = nfine_codes[4];

    assign nfine_code_5 = nfine_codes[5];
    assign nfine_code_6 = nfine_codes[6];
    assign nfine_code_7 = nfine_codes[7];
    assign nfine_code_8 = nfine_codes[8];
    assign nfine_code_9 = nfine_codes[9];

    //  Coarse Code assignments (Registers <--> Bias Gen)
    logic [`COARSE_CODE_WIDTH-1:0] coarse_one_hot_codes [`NUM_COARSE_CODES];

    assign coarse_code_0 = coarse_one_hot_codes[0];
    assign coarse_code_1 = coarse_one_hot_codes[1];
    assign coarse_code_2 = coarse_one_hot_codes[2];
    assign coarse_code_3 = coarse_one_hot_codes[3];
    assign coarse_code_4 = coarse_one_hot_codes[4];

    assign coarse_code_5 = coarse_one_hot_codes[5];
    assign coarse_code_6 = coarse_one_hot_codes[6];
    assign coarse_code_7 = coarse_one_hot_codes[7];
    assign coarse_code_8 = coarse_one_hot_codes[8];
    assign coarse_code_9 = coarse_one_hot_codes[9];

    //---------------------------------------------------------------
    // RW/RO Mappings
    //---------------------------------------------------------------
    always_comb begin
        // foreach(mem_out[i])
        //     // mem_out[i] = '0;
        //     mem_out[i] = 32'b0;
        for (int i = 0; i < `RF_DEPTH; i++) begin
            mem_out[i] = 32'b0;
        end

        mem_out[0][7:0] = `CHIP_ID; // Hardwired RF ID

        // `mem_map_ro(spi_last_write_data_reg, 4)
        // SPI Debug
        `mem_map_ro(spi_last_read_data_reg, 4)
        `mem_map_ro(opcode_0_reg, 8)
        `mem_map_ro(addr_0_reg, 9)
        // FIFO
        // `mem_map_ro(fifo_empty, 2)
        // `mem_map_ro(fifo_full,  3)
        // `mem_map_ro(fifo_numel_reg, 4)
        // `mem_map_ro(`CHIP_ID, 0)
        // `mem_map_ro(fifo_rdata, 8)
        
        // IRQ
        // `mem_map(irq_deassert_thresh_reg, 12)
        // `mem_map(irq_assert_thresh_reg, 14)
        // `mem_map(fine_code,8)
        // `mem_map(nfine_code,9)
        // `mem_map(coarse_onehot,10)
        // `mem_map(bias_combined,12)
        // FIFO Debug
        `mem_map_ro(fifo_debug_top, 10)
        `mem_map_ro(fifo_debug_bot, 11)

        // DACs 
        for (int i = 0; i < `NUM_DACS; i++) begin
            `mem_map(dac_configs[i], i*2 + 20)
        end

        // Fine Code Regs (8-bit) - Addresses 40 to 49 (Starting at Row 10)
        for (int i = 0; i < `NUM_FINE_CODES; i++) begin
            `mem_map(fine_codes[i], i + 40)
        end

       // nFine Code Regs (8-bit) - Addresses 50 to 59 (Starting at Row 13)
        for (int i = 0; i < `NUM_nFINE_CODES; i++) begin
            `mem_map(nfine_codes[i], i + 52)
        end

        // Coarse Regs (8-bit) - Addresses 64 to 73 (Starting at Row 16)
        for (int i = 0; i < `NUM_COARSE_CODES; i++) begin
            `mem_map(coarse_one_hot_codes[i], i + 64)
        end

        // Rui's Analog Registers
        // 10-Bit Bias Enables (Starting at Address 76 / Row 19)
        `mem_map(LowBiasInterfaceEn,    76) // takes 2 bytes for 10-bits
        `mem_map(nLowBiasInterfaceEn,   78)
        `mem_map(CoarseOneHotLowBiasEn, 80)
        `mem_map(LowBiasBuffEn,         82)
        `mem_map(nLowBiasBuffEn,        84)
        `mem_map(nBiasEn,               86)
        `mem_map(pBiasEn,               88)
        `mem_map(BiasEnable,            90)
        `mem_map(BiasDisable,           92)

        // next available address is byte 94


        //INTERNAL EVENT RATE
        `mem_map(event_rate_reg, 108) //addressing byte 
        `mem_map_ro(fsm_ctrl_byte_top,110)
        `mem_map_ro(fsm_ctrl_byte_bot,111)

        // 14-BIT PHASE TUNINGS (2 bytes each)
        `mem_map(p_pre_charge, 112)
        `mem_map(p_buffer,     114)
        `mem_map(p_detect,     116)
        `mem_map(p_on_detect,  118)
        `mem_map(p_off_detect, 120)
        `mem_map(p_rst,        122)
    end


    //---------------------------------------------------------------
    // Pulsed Mappings
    //---------------------------------------------------------------
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            // fifo_rd_en_reg <= 0;
            fifo_rst_n_reg <= 0;
            fsm_rst_n_reg  <= 0;
        end 
        else begin
            `mem_map_pulse(fifo_rst_n_reg, 0, 1)
            `mem_map_pulse( fsm_rst_n_reg, 0, 2)
            // `mem_map_pulse(fifo_rd_en_reg, 2, 0)
        end
    end

//---------------------------------------------------------------
// Write data - altered for yosys
//---------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (int i = 0; i < `RF_DEPTH; i++) begin
            mem_in[i] <= '0;
        end
    end 
    else begin
        if (we_reg) begin
            for (int i = 0; i < `RF_MASK; i++) begin
                if (wmask_reg[i]) begin
                    mem_in[addr_reg][i*8 +: 8] <= wdata_reg[i*8 +: 8];
                end
            end
        end
    end
end

//---------------------------------------------------------------
// Read data
//---------------------------------------------------------------
always_comb begin
    rdata_reg = mem_out[addr_reg];  // Changed <= to = in combinational block
end



endmodule : regfile


`undef mem_map

`undef mem_map_ro

`undef mem_map_pulse