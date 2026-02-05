`timescale 1ns/1ps

//---------------------------------------------------------------------------
// Author: Ababakar Okieh
// Date  : Dec 19th, 2025
//
// Module: spi_fifo_regfile
//
// Description: 
//  Behavioral top-level for OpenDVS.
//---------------------------------------------------------------------------

module spi_fifo_regfile #(parameter DWIDTH=136, DEPTH=16)(
    //Global Signals
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
    input logic [   DWIDTH-1 : 0]   wdata_fifo_0,
    input logic [   DWIDTH-1 : 0]   wdata_fifo_1,
    output logic [1:0]                empty_fifo,
    output logic [1:0]                 full_fifo,
    output logic [$clog2(DEPTH)-1:0] numel_fifo_0,
    output logic [$clog2(DEPTH)-1:0] numel_fifo_1
);



    // Memory Interface (SPI <---> Mem)
    logic [`RF_AWIDTH-1:0] addr_reg;
    logic                  we_reg;
    // logic                  we_out;
    logic [ `RF_WIDTH-1:0] wdata_reg;
    logic [  `RF_MASK-1:0] wmask_reg;
    logic [ `RF_WIDTH-1:0] rdata_reg;
    logic [9:0] event_rate = 10'h3FF; //TODO (remove) gets written to mem[27]


    //FIFO Interface (SPI <---> FIFO)
    logic [15:0] rdata_spi_0;
    logic [15:0] rdata_spi_1;
    logic [1:0] shift_en_fifo;


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

    //  Biases assignments (Registers <--> Ports)
    logic [23:0] bias [`NUM_BIASES];
    assign bias_0 = bias[0];
    assign bias_1 = bias[1];
    assign bias_2 = bias[2];
    assign bias_3 = bias[3];

    //---------------------------------------------------
    // Sync FIFO
    //---------------------------------------------------
    sync_fifo_top #(DWIDTH, DEPTH) i_sync_fifo_top_0(
        .clk(clk),
        .rst_n(rst_n),

        // FIFO signals to top level
        .wr_en_fifo,
        .wdata_fifo(wdata_fifo_0),
        .empty_fifo(empty_fifo[0]),
        .full_fifo(full_fifo[0]),
        .numel_fifo(numel_fifo_0),

        // SPI Interface signals
        .shift_en_fifo(shift_en_fifo[0]),
        .rdata_spi(rdata_spi_0)
    );

        sync_fifo_top #(DWIDTH, DEPTH) i_sync_fifo_top_1(
        .clk(clk),
        .rst_n(rst_n),

        // FIFO signals to top level
        .wr_en_fifo,
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
            // SPI Interface
            .CS_N,
            .SCK,
            .COPI,
            .CIPO,
            
            // Memory Interface (SPI <---> Mem)
            .addr_reg,
            .we_reg,
            .we_out,
            // .we_out_reg,       //TODO: remove, set as test wire for debug
            .wdata_reg,
            .wmask_reg,
            .rdata_reg,

            //FIFO Interface (SPI <---> FIFO)
            .rdata_spi_0,
            .rdata_spi_1,
            .shift_en_fifo
        );


        //---------------------------------------------------
        // Register File
        //---------------------------------------------------
        regfile i_regfile (
            .clk(clk),
            .rst_n(rst_n),

            // Memory Interface
            .we_reg,
            .addr_reg,
            .wdata_reg,
            .wmask_reg,
            .rdata_reg,
            
            // FIFO
            .fifo_rst_n_reg(),
            .fifo_rd_en_reg(),
            .fifo_numel_reg(),
            
            // IRQ
            .irq_deassert_thresh_reg(),
            .irq_assert_thresh_reg(),
            
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
            .event_rate_reg(event_rate)         //added code
        );

endmodule : spi_fifo_regfile