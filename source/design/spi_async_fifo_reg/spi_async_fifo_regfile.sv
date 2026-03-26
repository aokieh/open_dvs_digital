`timescale 1ns/1ps

module spi_async_fifo_regfile (
    `ifdef USE_POWER_PINS
        inout vccd1, 
        inout vssd1, 
    `endif
    
    // Global Clocks & Resets
    input  logic clk,
    input  logic rst_n,

    // SPI Interface
    input  logic CS_N,
    input  logic SCK,
    input  logic [3:0] COPI,
    output logic [3:0] CIPO,

    // Asynchronous Write Interface (from cross-domain sensors/logic)
    input  logic [3:0] data_req, // Array for 4 independent requests
    input  logic [`FIFO_WIDTH_ASYNC-1:0] wdata_0, wdata_1, wdata_2, wdata_3,
    output logic [3:0] data_ack, // Array for 4 acks back to async domain

    // Debug / Misc
    output logic we_out,

    // Regfile External Outputs
    output logic [9:0] irq_deassert_thresh_reg,
    output logic [9:0] irq_assert_thresh_reg,
    output logic [`DAC_WIDTH-1:0] dac_config_0, dac_config_1, dac_config_2, dac_config_3,
    output logic [`DAC_WIDTH-1:0] dac_config_4, dac_config_5, dac_config_6, dac_config_7,
    output logic [`BIAS_WIDTH-1:0] bias_0, bias_1, bias_2, bias_3,
    
    // Regfile External Inputs
    input  logic [9:0] event_rate_reg
);

    //---------------------------------------------------
    // Internal Interconnect Wires
    //---------------------------------------------------
    
    // SPI <---> Regfile Wires
    logic [`RF_AWIDTH-1:0] addr_reg;
    logic                  we_reg;
    logic [ `RF_WIDTH-1:0] wdata_reg;
    logic [  `RF_MASK-1:0] wmask_reg;
    logic [ `RF_WIDTH-1:0] rdata_reg;

    // SPI <---> FIFO Wires
    logic [`FIFO_WIDTH_ASYNC-1:0] fifo_rdata_0, fifo_rdata_1, fifo_rdata_2, fifo_rdata_3;
    logic fifo_empty_0, fifo_empty_1, fifo_empty_2, fifo_empty_3;
    logic fifo_rd_en_0, fifo_rd_en_1, fifo_rd_en_2, fifo_rd_en_3;

    // Regfile <---> FIFO Status Wires
    logic fifo_rst_n_reg;
    logic combined_fifo_rst_n;
    logic [`FIFO_AWIDTH_ASYNC-1:0] numel_fifo_0, numel_fifo_1, numel_fifo_2, numel_fifo_3;

    // Combine system reset with Regfile's software reset override
    assign combined_fifo_rst_n = rst_n & !fifo_rst_n_reg; //TODO

    //---------------------------------------------------
    // Block Instantiations
    //---------------------------------------------------

    // 1. SPI Peripheral State Machine
    spi_peripheral2 i_spi_peripheral (
        `ifdef USE_POWER_PINS .vccd1(vccd1), .vssd1(vssd1), `endif
        .CS_N(CS_N), .SCK(SCK), .COPI(COPI), .CIPO(CIPO),
        
        // Memory Map
        .addr_reg(addr_reg), .we_reg(we_reg), .we_out(we_out),
        .wdata_reg(wdata_reg), .wmask_reg(wmask_reg), .rdata_reg(rdata_reg),
        
        // Obsolete legacy ports tied off
        // .rdata_spi_0(16'b0), .rdata_spi_1(16'b0), .shift_en_fifo(),

        // 4x FIFO Stream Interface
        .fifo_rdata_0(fifo_rdata_0), .fifo_rdata_1(fifo_rdata_1), 
        .fifo_rdata_2(fifo_rdata_2), .fifo_rdata_3(fifo_rdata_3),
        .fifo_empty_0(fifo_empty_0), .fifo_empty_1(fifo_empty_1), 
        .fifo_empty_2(fifo_empty_2), .fifo_empty_3(fifo_empty_3),
        .fifo_rd_en_0(fifo_rd_en_0), .fifo_rd_en_1(fifo_rd_en_1), 
        .fifo_rd_en_2(fifo_rd_en_2), .fifo_rd_en_3(fifo_rd_en_3)
    );

    // 2. Control/Status Register File
    regfile i_regfile (
        `ifdef USE_POWER_PINS .vccd1(vccd1), .vssd1(vssd1), `endif
        .clk(clk), .rst_n(rst_n),

        .addr_reg(addr_reg), .we_reg(we_reg), .wdata_reg(wdata_reg), 
        .wmask_reg(wmask_reg), .rdata_reg(rdata_reg),

        // Software Reset for FIFOs
        .fifo_rst_n_reg(fifo_rst_n_reg),
        .fifo_rd_en_reg(), // Not used, handled automatically by continuous SPI pipeline
        
        // Passing CH0 fill status for software monitoring
        .fifo_numel_reg(numel_fifo_0), 

        .irq_deassert_thresh_reg(irq_deassert_thresh_reg),
        .irq_assert_thresh_reg(irq_assert_thresh_reg),

        .dac_config_0(dac_config_0), .dac_config_1(dac_config_1), 
        .dac_config_2(dac_config_2), .dac_config_3(dac_config_3),
        .dac_config_4(dac_config_4), .dac_config_5(dac_config_5), 
        .dac_config_6(dac_config_6), .dac_config_7(dac_config_7),

        .bias_0(bias_0), .bias_1(bias_1), .bias_2(bias_2), .bias_3(bias_3),
        .event_rate_reg(event_rate_reg)
    );

    // 3. Four Async FIFO Wrappers (Contains internal async_write_intf synchronizers)
    async_fifo_top i_fifo_0 (
        `ifdef USE_POWER_PINS .vccd1(vccd1), .vssd1(vssd1), `endif
        .clk(clk), .rst_n(combined_fifo_rst_n),
        .empty_fifo(fifo_empty_0), .full_fifo(), .numel_fifo(numel_fifo_0),
        .wdata_async(wdata_0), .data_req(data_req[0]), .data_ack(data_ack[0]),
        .fifo_rd_en(fifo_rd_en_0), .async_rdata_spi(fifo_rdata_0)
    );

    async_fifo_top i_fifo_1 (
        `ifdef USE_POWER_PINS .vccd1(vccd1), .vssd1(vssd1), `endif
        .clk(clk), .rst_n(combined_fifo_rst_n),
        .empty_fifo(fifo_empty_1), .full_fifo(), .numel_fifo(numel_fifo_1),
        .wdata_async(wdata_1), .data_req(data_req[1]), .data_ack(data_ack[1]),
        .fifo_rd_en(fifo_rd_en_1), .async_rdata_spi(fifo_rdata_1)
    );

    async_fifo_top i_fifo_2 (
        `ifdef USE_POWER_PINS .vccd1(vccd1), .vssd1(vssd1), `endif
        .clk(clk), .rst_n(combined_fifo_rst_n),
        .empty_fifo(fifo_empty_2), .full_fifo(), .numel_fifo(numel_fifo_2),
        .wdata_async(wdata_2), .data_req(data_req[2]), .data_ack(data_ack[2]),
        .fifo_rd_en(fifo_rd_en_2), .async_rdata_spi(fifo_rdata_2)
    );

    async_fifo_top i_fifo_3 (
        `ifdef USE_POWER_PINS .vccd1(vccd1), .vssd1(vssd1), `endif
        .clk(clk), .rst_n(combined_fifo_rst_n),
        .empty_fifo(fifo_empty_3), .full_fifo(), .numel_fifo(numel_fifo_3),
        .wdata_async(wdata_3), .data_req(data_req[3]), .data_ack(data_ack[3]),
        .fifo_rd_en(fifo_rd_en_3), .async_rdata_spi(fifo_rdata_3)
    );

endmodule