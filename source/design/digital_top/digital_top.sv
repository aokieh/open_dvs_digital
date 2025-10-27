
module digital_top (
    input  logic clk,
    input  logic rst_n,
    //Added for ASIC tools
    input  logic vccd1,  // OpenLane Power  - comment out if needed
    input  logic vssd1,  // OpenLane Ground - comment out if needed
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
    output logic [`FIFO_AWIDTH-1:0]     irq_assert_thresh,
    output logic [`FIFO_AWIDTH-1:0]     irq_deassert_thresh,
    input  logic [`FIFO_AWIDTH-1:0]     fifo_numel,
    output logic                        fifo_rd_en,
    output logic                        fifo_rst_n
);


    // Memory Interface
    logic                  we;
    logic [`RF_AWIDTH-1:0] addr;
    logic [ `RF_WIDTH-1:0] wdata;
    logic [  `RF_MASK-1:0] wmask;
    logic [ `RF_WIDTH-1:0] rdata;

    // FIFO registers
    // logic                    fifo_rst_n;
    // logic                    fifo_rd_en;
    // logic [`FIFO_AWIDTH-1:0] fifo_numel = 10'h3FF;//TODO remove assignment

    // IRQ registers
    // logic [`FIFO_AWIDTH-1:0] irq_deassert_thresh;
    // logic [`FIFO_AWIDTH-1:0] irq_assert_thresh;

    // DAC registers
    // logic [`DAC_WIDTH-1:0] dac_config [`NUM_DACS];
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
    logic [9:0] event_rate = 10'h3FF; //TODO (remove) gets written to mem[27]

    // hard wiring the added memory addresses
    // assign bias[0] = 24'hAAA;
    // assign bias[1] = 24'hBBB;
    // assign bias[2] = 24'hCCC;
    // assign bias[3] = 24'hDDD;
    // assign bias_3 = bias[3]; // removed for yosys
    // assign bias_2 = bias[2];
    // assign bias_1 = bias[1];
    // assign bias_0 = bias[0];
    //---------------------------------------------------
    // SPI Peripheral
    //---------------------------------------------------
    spi_peripheral i_spi_peripheral (
        .CS_N,
        .SCK,
        .COPI,
        .CIPO,
        
        .addr,
        .we,
        .we_out,       //TODO: remove, set as test wire for debug
        .wdata,
        .wmask,
        .rdata
    );


    //---------------------------------------------------
    // Register File
    //---------------------------------------------------
    regfile i_regfile (
        .clk,
        .rst_n,

        // Memory Interface
        .we,
        .addr,
        .wdata,
        .wmask,
        .rdata,
        
        // FIFO
        .fifo_rst_n,
        .fifo_rd_en,
        .fifo_numel,
        
        // IRQ
        .irq_deassert_thresh,
        .irq_assert_thresh,
        
        // DAC
        .dac_config_0,
        .dac_config_1,
        .dac_config_2,
        .dac_config_3,

        .dac_config_4,
        .dac_config_5,
        .dac_config_6,
        .dac_config_7,

        //ADDED PORTS -- testing top level IO. remove later
        .bias_0,              //added code - testing yosys flow    
        .bias_1,
        .bias_2,
        .bias_3,
        .event_rate         //added code
    );

endmodule : digital_top