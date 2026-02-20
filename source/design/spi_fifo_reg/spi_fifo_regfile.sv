// `timescale 1ns/1ps

//---------------------------------------------------------------------------
// Author: Ababakar Okieh
// Date  : Dec 19th, 2025
//
// Module: spi_fifo_regfile
//
// Description: 
//  Behavioral top-level for OpenDVS.
//---------------------------------------------------------------------------

module spi_fifo_regfile (
    //Global Signals
    `ifdef USE_POWER_PINS
        inout vccd1, 
        inout vssd1, 
    `endif

    input  logic                    SCK,
    input  logic                    clk,
    input  logic                    rst_n,
    
    // SPI Interface
    input  logic                    CS_N,
    input  logic [3:0]              COPI, 
    output logic [3:0]              CIPO,
    output logic                    we_out,

    // FIFO Signals
    input logic                     wr_en_fifo,
    input logic [   `FIFO_WIDTH-1 : 0]   wdata_fifo_0,
    input logic [   `FIFO_WIDTH-1 : 0]   wdata_fifo_1,
    output logic [1:0]              empty_fifo,
    output logic [1:0]              full_fifo,
    output logic [`FIFO_AWIDTH-1:0] numel_fifo_0,
    output logic [`FIFO_AWIDTH-1:0] numel_fifo_1,

    // DAC outputs (explicit)
    output logic [`DAC_WIDTH-1:0] dac_config_0,
    output logic [`DAC_WIDTH-1:0] dac_config_1,
    output logic [`DAC_WIDTH-1:0] dac_config_2,
    output logic [`DAC_WIDTH-1:0] dac_config_3,
    output logic [`DAC_WIDTH-1:0] dac_config_4,
    output logic [`DAC_WIDTH-1:0] dac_config_5,
    output logic [`DAC_WIDTH-1:0] dac_config_6,
    output logic [`DAC_WIDTH-1:0] dac_config_7,

    // Bias outputs (explicit)
    output logic [`BIAS_WIDTH-1:0] bias_0,
    output logic [`BIAS_WIDTH-1:0] bias_1,
    output logic [`BIAS_WIDTH-1:0] bias_2,
    output logic [`BIAS_WIDTH-1:0] bias_3,

    // NEW: Debug/Status Ports from Regfile
    output logic                    fifo_rd_en,
    output logic [9:0]              irq_deassert_thresh,
    output logic [9:0]              irq_assert_thresh
);

    // Memory Interface (SPI <---> Mem)
    logic [`RF_AWIDTH-1:0]  addr_reg;
    logic                     we_reg;
    logic [ `RF_WIDTH-1:0] wdata_reg;
    logic [  `RF_MASK-1:0] wmask_reg;
    logic [ `RF_WIDTH-1:0] rdata_reg;
    logic [9:0] event_rate = 10'h3FF;

    // Memory <---> FIFO
    logic             fifo_rst_n_reg;

    //FIFO Interface (SPI <---> FIFO)
    logic [15:0] rdata_spi_0;
    logic [15:0] rdata_spi_1;
    logic [1:0] shift_en_fifo;

    // internal global reset
    logic rst_n_sync_stage1;
    logic sync_rst_n;

    //---------------------------------------------------
    // Synchronizer Reset
    //---------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rst_n_sync_stage1 <= 1'b0;
            sync_rst_n        <= 1'b0;
        end else begin
            rst_n_sync_stage1 <= 1'b1;
            sync_rst_n        <= rst_n_sync_stage1;
        end
    end

    //---------------------------------------------------
    // Sync FIFO
    //---------------------------------------------------
    sync_fifo_top i_sync_fifo_top_0(
        // Power rails handled by PDN config
        // `ifdef USE_POWER_PINS ...

        .clk(clk),
        .rst_n(sync_rst_n),

        // FIFO signals to top level
        .wr_en_fifo(wr_en_fifo),
        .wdata_fifo(wdata_fifo_0),
        .empty_fifo(empty_fifo[0]),
        .full_fifo(full_fifo[0]),
        .numel_fifo(numel_fifo_0),

        // SPI Interface signals
        .shift_en_fifo(shift_en_fifo[0]),
        .rdata_spi(rdata_spi_0)
    );

    sync_fifo_top i_sync_fifo_top_1(
        // Power rails handled by PDN config
        // `ifdef USE_POWER_PINS ...

        .clk(clk),
        .rst_n(sync_rst_n),

        // FIFO signals to top level
        .wr_en_fifo(wr_en_fifo),
        .wdata_fifo(wdata_fifo_1),
        .empty_fifo(empty_fifo[1]),
        .full_fifo(full_fifo[1]),
        .numel_fifo(numel_fifo_1),

        // SPI Interface signals
        .shift_en_fifo(shift_en_fifo[1]),
        .rdata_spi(rdata_spi_1)
    );

    //---------------------------------------------------
    // SPI Peripheral
    //---------------------------------------------------
    spi_peripheral i_spi_peripheral (
        // Power rails handled by PDN config
        // `ifdef USE_POWER_PINS ...

        // SPI Interface
        .CS_N(CS_N),
        .SCK(clk),
        .COPI(COPI),
        .CIPO(CIPO),
        
        // Memory Interface (SPI <---> Mem)
        .addr_reg(addr_reg),
        .we_reg(we_reg),
        .we_out(we_out),
        .wdata_reg(wdata_reg),
        .wmask_reg(wmask_reg),
        .rdata_reg(rdata_reg),

        //FIFO Interface (SPI <---> FIFO)
        .rdata_spi_0(rdata_spi_0),
        .rdata_spi_1(rdata_spi_1),
        .shift_en_fifo(shift_en_fifo)
    );

    //---------------------------------------------------
    // Register File
    //---------------------------------------------------
    regfile i_regfile (
        // Power rails handled by PDN config
        // `ifdef USE_POWER_PINS ...

        .clk(clk),
        .rst_n(sync_rst_n),

        // Memory Interface
        .we_reg(we_reg),
        .addr_reg(addr_reg),
        .wdata_reg(wdata_reg),
        .wmask_reg(wmask_reg),
        .rdata_reg(rdata_reg),
        
        // FIFO
        .fifo_rst_n_reg(fifo_rst_n_reg),
        .fifo_rd_en_reg(fifo_rd_en),          // MAPPED to top-level
        .fifo_numel_reg(numel_fifo_0),        // MAPPED to FIFO 0 fill level
        
        // IRQ
        .irq_deassert_thresh_reg(irq_deassert_thresh), // MAPPED to top-level
        .irq_assert_thresh_reg(irq_assert_thresh),     // MAPPED to top-level
        
        // DAC
        .dac_config_0(dac_config_0),
        .dac_config_1(dac_config_1),
        .dac_config_2(dac_config_2),
        .dac_config_3(dac_config_3),
        .dac_config_4(dac_config_4),
        .dac_config_5(dac_config_5),
        .dac_config_6(dac_config_6),
        .dac_config_7(dac_config_7),

        // Bias
        .bias_0(bias_0),
        .bias_1(bias_1),
        .bias_2(bias_2),
        .bias_3(bias_3),
        .event_rate_reg(event_rate)
    );        

endmodule : spi_fifo_regfile