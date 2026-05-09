
module digital_top_re (
    `ifdef USE_POWER_PINS
        inout vccd1, 
        inout vssd1, 
    `endif
    input  logic clk,
    input  logic rst_n,
    //Added for ASIC tools
    // input  logic vccd1,  // OpenLane Power  - comment out if needed
    // input  logic vssd1,  // OpenLane Ground - comment out if needed
    // SPI Interface
    input  logic CS_N,
    input  logic SCK,
    input  logic [3:0] COPI,
    output logic [3:0] CIPO,
    // output logic [23:0] bias_0,
    // output logic [23:0] bias_1,
    // output logic [23:0] bias_2,
    // output logic [23:0] bias_3,
    // Added DAC outputs
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

    // TODO: removable signals that we aren't using (at the moment)
    output logic                        we_out,
    // output logic                        we_reg,
    output logic [`NUM_AMUX_IO_PADS-1:0] pad_bias_enable,
    output logic [`NUM_AMUX_IO_PADS-1:0] pad_bias_disable,
    input  logic [`FIFO_AWIDTH-1:0]     fifo_numel_reg,
    // output logic                        fifo_rd_en_reg,
    output logic                        fifo_rst_n_reg,

    output logic [7:0] event_rate_reg,

    //FIFO Interface (SPI <---> FIFO)
    input  logic [15:0] rdata_spi_0,
    input  logic [15:0] rdata_spi_1,
    output logic [1:0] shift_en_fifo,

    // NEW ADDITIONS :( 
    output logic         fsm_rst_n_reg,
    output logic [13:0]  p_pre_charge,
    output logic [13:0]  p_buffer,
    output logic [13:0]  p_detect,
    output logic [13:0]  p_on_detect,
    output logic [13:0]  p_off_detect,
    output logic [13:0]  p_rst,
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
    output logic [`BIAS_COMBINED_WIDTH-1:0] pBiasEn,        //inv nBiasEn
    output logic [`BIAS_COMBINED_WIDTH-1:0] BiasEnable,
    output logic [`BIAS_COMBINED_WIDTH-1:0] BiasDisable     //inv BiasEnable    
);


    // Memory Interface
    logic                  we_reg;
    logic [`RF_AWIDTH-1:0] addr_reg;
    logic [ `RF_WIDTH-1:0] wdata_reg;
    logic [  `RF_MASK-1:0] wmask_reg;
    logic [ `RF_WIDTH-1:0] rdata_reg;

    // --- NEW: Debug Wires ---
    logic [7:0]            opcode_0_reg;
    logic [7:0]            addr_0_reg;
    logic [`RF_WIDTH-1:0]  spi_last_read_data_reg;

    // DAC registers
    logic [`DAC_WIDTH-1:0] dac_config [`NUM_DACS];
    assign dac_config[0] = dac_config_0;
    assign dac_config[1] = dac_config_1;
    assign dac_config[2] = dac_config_2;
    assign dac_config[3] = dac_config_3;

    assign dac_config[4] = dac_config_4;
    assign dac_config[5] = dac_config_5;
    assign dac_config[6] = dac_config_6;
    assign dac_config[7] = dac_config_7;

    assign dac_config[8] = dac_config_8;
    assign dac_config[9] = dac_config_9;
    // logic [`DAC_WIDTH-1:0] dac_config_0; 
    // logic [`DAC_WIDTH-1:0] dac_config_1;
    // logic [`DAC_WIDTH-1:0] dac_config_2;
    // logic [`DAC_WIDTH-1:0] dac_config_3;

    // logic [`DAC_WIDTH-1:0] dac_config_4; 
    // logic [`DAC_WIDTH-1:0] dac_config_5;
    // logic [`DAC_WIDTH-1:0] dac_config_6;
    // logic [`DAC_WIDTH-1:0] dac_config_7;

    //ADDITIONAL SIGNALS - test registers to test ports
    // logic [23:0] bias [`NUM_BIASES];
    // logic [9:0] event_rate = 10'h3FF; //TODO (remove) gets written to mem[27]

    // hard wiring the added memory addresses
    // assign bias[0] = 24'hAAA;
    // assign bias[1] = 24'hBBB;
    // assign bias[2] = 24'hCCC;
    // assign bias[3] = 24'hDDD;
    // assign bias[3] = bias_3; // removed for yosys
    // assign bias[2] = bias_2;
    // assign bias[1] = bias_1;
    // assign bias[0] = bias_0;
    //---------------------------------------------------
    // SPI Peripheral
    //---------------------------------------------------
    spi_peripheral_re i_spi_peripheral (
        `ifdef USE_POWER_PINS
            .vccd1             (vccd1),
            .vssd1             (vssd1),
        `endif
        .CS_N,
        .SCK,
        .COPI,
        .CIPO,
        
        .addr_reg,
        .we_reg,
        .we_out,       //TODO: remove, set as test wire for debug
        .wdata_reg,
        .wmask_reg,
        .rdata_reg,

        // --- NEW: SPI Debug Outputs ---
        .opcode_0_reg(opcode_0_reg),
        .addr_0_reg(addr_0_reg),
        .spi_last_read_data_reg(spi_last_read_data_reg),

        .rdata_spi_0(rdata_spi_0),
        .rdata_spi_1(rdata_spi_1),
        .shift_en_fifo(shift_en_fifo),
        .data_ready_spi(1'b0) // Tied off for testing, or route to a top-level port
    );


    //---------------------------------------------------
    // Register File
    //---------------------------------------------------
    regfile i_regfile(

        `ifdef USE_POWER_PINS
            .vccd1             (vccd1),
            .vssd1             (vssd1),
        `endif

        .clk,
        .rst_n,

        // Memory Interface (SPI <-> Mem)
        .addr_reg,
        .we_reg,
        .wdata_reg,
        .wmask_reg,
        .rdata_reg,

        // --- SPI Debug ---
        .opcode_0_reg(opcode_0_reg),
        .addr_0_reg(addr_0_reg),
        .spi_last_read_data_reg(spi_last_read_data_reg),

        // FIFO & FSM Resets
        .fifo_rst_n_reg,
        .fsm_rst_n_reg,
        .fifo_numel_reg,
        .fifo_debug_top('0),       // Tied off (input not at top level)
        .fifo_debug_bot('0),       // Tied off (input not at top level)

        // Analog BGR Pads
        .pad_bias_enable,
        .pad_bias_disable,

        // DAC
        .dac_config_0,
        .dac_config_1,
        .dac_config_2,
        .dac_config_3,
        .dac_config_4, 
        .dac_config_5,
        .dac_config_6,
        .dac_config_7,
        .dac_config_8,             
        .dac_config_9,             

        // FSM
        .fsm_ctrl_byte_top('0),    // Tied off (input not at top level)
        .fsm_ctrl_byte_bot('0),    // Tied off (input not at top level)

        // Programmable Imager Speed
        .event_rate_reg,

        // Programmable Timing Inputs (14-BIT TUNING)
        .p_pre_charge,           // Left open (output not routed to top)
        .p_buffer,
        .p_detect,
        .p_on_detect,
        .p_off_detect,
        .p_rst,

        // Rui Analog Registers
        // .fine_code,
        // .nfine_code,
        // .coarse_onehot,
        // .bias_combined,

        .fine_code_0,
        .fine_code_1,
        .fine_code_2,
        .fine_code_3,
        .fine_code_4,
        .fine_code_5,
        .fine_code_6,
        .fine_code_7,
        .fine_code_8,
        .fine_code_9,

        .nfine_code_0,
        .nfine_code_1,
        .nfine_code_2,
        .nfine_code_3,
        .nfine_code_4,
        .nfine_code_5,
        .nfine_code_6,
        .nfine_code_7,
        .nfine_code_8,
        .nfine_code_9,

        .coarse_code_0,
        .coarse_code_1,
        .coarse_code_2,
        .coarse_code_3,
        .coarse_code_4,
        .coarse_code_5,
        .coarse_code_6,
        .coarse_code_7,
        .coarse_code_8,
        .coarse_code_9,

        .LowBiasInterfaceEn,
        .nLowBiasInterfaceEn,
        .CoarseOneHotLowBiasEn,
        .LowBiasBuffEn,
        .nLowBiasBuffEn,
        .nBiasEn,
        .pBiasEn,
        .BiasEnable,
        .BiasDisable
    );
endmodule : digital_top_re