
module digital_top (
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
    output logic [23:0] bias_0,
    output logic [23:0] bias_1,
    output logic [23:0] bias_2,
    output logic [23:0] bias_3,
    // Added DAC outputs
    output logic [`DAC_WIDTH-1:0] dac_config_0,
    output logic [`DAC_WIDTH-1:0] dac_config_1,
    output logic [`DAC_WIDTH-1:0] dac_config_2,
    output logic [`DAC_WIDTH-1:0] dac_config_3,

    output logic [`DAC_WIDTH-1:0] dac_config_4,
    output logic [`DAC_WIDTH-1:0] dac_config_5,
    output logic [`DAC_WIDTH-1:0] dac_config_6,
    output logic [`DAC_WIDTH-1:0] dac_config_7,

    // TODO: removable signals that we aren't using (at the moment)
    output logic                        we_out,
    // output logic                        we_reg,
    output logic [`FIFO_AWIDTH-1:0]     irq_assert_thresh_reg,
    output logic [`FIFO_AWIDTH-1:0]     irq_deassert_thresh_reg,
    input  logic [`FIFO_AWIDTH-1:0]     fifo_numel_reg,
    output logic                        fifo_rd_en_reg,
    output logic                        fifo_rst_n_reg,

    //FIFO Interface (SPI <---> FIFO)
    input  logic [15:0] rdata_spi_0,
    input  logic [15:0] rdata_spi_1,
    output logic [1:0] shift_en_fifo
);


    // Memory Interface
    logic                  we_reg;
    logic [`RF_AWIDTH-1:0] addr_reg;
    logic [ `RF_WIDTH-1:0] wdata_reg;
    logic [  `RF_MASK-1:0] wmask_reg;
    logic [ `RF_WIDTH-1:0] rdata_reg;

    // FIFO registers
    // logic                    fifo_rst_n;
    // logic                    fifo_rd_en;
    // logic [`FIFO_AWIDTH-1:0] fifo_numel = 10'h3FF;//TODO remove assignment

    // IRQ registers
    logic [`FIFO_AWIDTH-1:0] irq_deassert_thresh;
    // logic [`FIFO_AWIDTH-1:0] irq_assert_thresh;

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
    // logic [`DAC_WIDTH-1:0] dac_config_0; 
    // logic [`DAC_WIDTH-1:0] dac_config_1;
    // logic [`DAC_WIDTH-1:0] dac_config_2;
    // logic [`DAC_WIDTH-1:0] dac_config_3;

    // logic [`DAC_WIDTH-1:0] dac_config_4; 
    // logic [`DAC_WIDTH-1:0] dac_config_5;
    // logic [`DAC_WIDTH-1:0] dac_config_6;
    // logic [`DAC_WIDTH-1:0] dac_config_7;

    //ADDITIONAL SIGNALS - test registers to test ports
    logic [23:0] bias [`NUM_BIASES];
    logic [9:0] event_rate = 10'h3FF; //TODO (remove) gets written to mem[27]

    // hard wiring the added memory addresses
    // assign bias[0] = 24'hAAA;
    // assign bias[1] = 24'hBBB;
    // assign bias[2] = 24'hCCC;
    // assign bias[3] = 24'hDDD;
    assign bias[3] = bias_3; // removed for yosys
    assign bias[2] = bias_2;
    assign bias[1] = bias_1;
    assign bias[0] = bias_0;
    //---------------------------------------------------
    // SPI Peripheral
    //---------------------------------------------------
    spi_peripheral i_spi_peripheral (
        .CS_N,
        .SCK,
        .COPI,
        .CIPO,
        
        .addr_reg,
        .we_reg,
        .we_out,       //TODO: remove, set as test wire for debug
        .wdata_reg,
        .wmask_reg,
        .rdata_reg
    );


    //---------------------------------------------------
    // Register File
    //---------------------------------------------------
    regfile i_regfile(
        .clk,
        .rst_n,

        // Memory Interface (SPI <-> Mem)
        .addr_reg,
        .we_reg,
        .wdata_reg,
        .wmask_reg,
        .rdata_reg,

        // FIFO
        .fifo_rst_n_reg,
        // input  logic                    fifo_empty,
        // input  logic                    fifo_full,
        .fifo_rd_en_reg,
        .fifo_numel_reg,
        // input  logic [ `FIFO_WIDTH-1:0] fifo_rdata,

        // IRQ
        .irq_deassert_thresh_reg,
        .irq_assert_thresh_reg,

        // DAC
        // output logic [`DAC_WIDTH-1:0] dac_config [`NUM_DACS],
        .dac_config_0,
        .dac_config_1,
        .dac_config_2,
        .dac_config_3,
        .dac_config_4, 
        .dac_config_5,
        .dac_config_6,
        .dac_config_7,

        //TEST ADDITIONAL PORTS
        .bias_0,
        .bias_1,
        .bias_2,
        .bias_3,

        .event_rate_reg(event_rate)
);

endmodule : digital_top