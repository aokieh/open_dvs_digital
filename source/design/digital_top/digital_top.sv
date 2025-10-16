
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
    output logic [23:0] bias_3
);


    // Memory Interface
    logic                  we;
    logic [`RF_AWIDTH-1:0] addr;
    logic [ `RF_WIDTH-1:0] wdata;
    logic [  `RF_MASK-1:0] wmask;
    logic [ `RF_WIDTH-1:0] rdata;

    // FIFO registers
    logic                    fifo_rst_n;
    logic                    fifo_rd_en;
    logic [`FIFO_AWIDTH-1:0] fifo_numel = 10'h3FF;//TODO remove assignment

    // IRQ registers
    logic [`FIFO_AWIDTH-1:0] irq_deassert_thresh;
    logic [`FIFO_AWIDTH-1:0] irq_assert_thresh;

    // DAC registers
    logic [`DAC_WIDTH-1:0] dac_config [`NUM_DACS];

    //ADDITIONAL SIGNALS - test registers to test ports
    logic [23:0] bias [`NUM_BIASES];
    logic [9:0] event_rate = 10'h3FF; //TODO (remove) gets written to mem[27]

    // hard wiring the added memory addresses
    // assign bias[0] = 24'hAAA;
    // assign bias[1] = 24'hBBB;
    // assign bias[2] = 24'hCCC;
    // assign bias[3] = 24'hDDD;
    assign bias_3 = bias[3];
    assign bias_2 = bias[2];
    assign bias_1 = bias[1];
    assign bias_0 = bias[0];
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
        .dac_config,

        //ADDED PORTS -- testing top level IO. remove later
        .bias,              //added code    
        .event_rate         //added code
    );

endmodule : digital_top