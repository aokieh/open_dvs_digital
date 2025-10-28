`timescale 1ns/1ps

import pkg_spi_fver::*;

module tb ();

    localparam CLK_P = 100ns;
    localparam DEPTH = 8;

    localparam DEASSERT_THRESH = 11;
    localparam ASSERT_THRESH   = 789;

    logic clk  = 0;
    logic rst_n = 0;

    // SPI Interface
    logic CS_N;
    logic SCK;
    logic [3:0] COPI;
    logic [3:0] CIPO;

    // Regfile interface
    logic [23:0] bias_0;
    logic [23:0] bias_1;
    logic [23:0] bias_2;
    logic [23:0] bias_3;
    
    // logic we_out;

    // Added DAC outputs
    logic [`DAC_WIDTH-1:0] dac_config_0;
    logic [`DAC_WIDTH-1:0] dac_config_1;
    logic [`DAC_WIDTH-1:0] dac_config_2;
    logic [`DAC_WIDTH-1:0] dac_config_3;
    logic [`DAC_WIDTH-1:0] dac_config_4;
    logic [`DAC_WIDTH-1:0] dac_config_5;
    logic [`DAC_WIDTH-1:0] dac_config_6;
    logic [`DAC_WIDTH-1:0] dac_config_7;

    // TODO: removable signals that we aren't using (at the moment)
    logic                        we_out;
    logic [`FIFO_AWIDTH-1:0]     irq_assert_thresh;
    logic [`FIFO_AWIDTH-1:0]     irq_deassert_thresh;
    logic [`FIFO_AWIDTH-1:0]     fifo_numel;
    logic                        fifo_rd_en;
    logic                        fifo_rst_n;

    supply1 VDD; // Ideal 1 (Power Source)
    supply0 VSS; // Ideal 0 (Ground Source)

    wire vccd1; // Core Power Net (VCC)
    wire vssd1; // Core Ground Net (VSS)
    // wire VPB;   // P-Well bias (normally tied to VDD) - Required by Sky130
    // wire VNB;   // N-Well bias (normally tied to VSS) - Required by Sky130    

    assign vccd1 = VDD; // Drive core VCC from ideal VDD supply
    assign vssd1 = VSS; // Drive core VSS from ideal VSS supply
    // assign VPB   = VDD; // Tie P-Well bias (VPB) to VDD
    // assign VNB   = VSS; // Tie N-Well bias (VNB) to VSS

    spi_intf i_spi_intf(
        .CS_N,
        .SCK ,
        .COPI,
        .CIPO
    );

    class_spi_ctrl spi_ctrl = new (i_spi_intf);

    always #(CLK_P/2) clk = ~clk;

    digital_top i_digital_top (
        .clk,
        .rst_n,

        //Power Ports
        .vccd1,
        .vssd1,

        // SPI Interface
        .CS_N,
        .SCK,
        .COPI,
        .CIPO,

        //Regfile interface
        .bias_0,
        .bias_1,
        .bias_2,
        .bias_3,

        .we_out,

        .dac_config_0,
        .dac_config_1,
        .dac_config_2,
        .dac_config_3,

        .dac_config_4,
        .dac_config_5,
        .dac_config_6,
        .dac_config_7,

        .irq_assert_thresh,
        .irq_deassert_thresh,
        .fifo_numel,
        .fifo_rd_en,
        .fifo_rst_n
    );


    initial begin
        spi_ctrl.init();
        
        #(10*CLK_P);
        rst_n = 1;

        #(5*CLK_P);

        #100ns;
        // The memory command is byte addressable
        // mem_in & mem_out is 32-bit word array of 32 cells
        // Look for valid data on wdata for write, and rdata for read
        
        // Read Chip ID
        spi_ctrl.trans(READ_BT, 0, 0, 'h55);
        #100ns;

        // // Pulse fifo_rst_n
        spi_ctrl.trans(WRITE_BT, 1, 1);
        #100ns;

        // // Set irq_deassert_thresh
        spi_ctrl.trans(WRITE_HW, 12, DEASSERT_THRESH);
        #100ns;

        // // Set irq_assert_thresh
        spi_ctrl.trans(WRITE_HW, 14, ASSERT_THRESH);
        #100ns;
        //wait for posedge(we_out) assert (wdata == ASSERT_THRESH)
        
        // Set DAC configs
        for (int i = 0; i < 10; i++) begin
            spi_ctrl.trans(WRITE_HW, i*2 + 20, 'h5aa + i);
            #100ns;
        end

        // Set bias data
        spi_ctrl.trans(WRITE_WD, 112, 'hAAAAAA);
        #100ns;
        
        spi_ctrl.trans(WRITE_WD, 116, 'hBBBBBB);
        #100ns;

        spi_ctrl.trans(WRITE_WD, 120, 'hCCCCCC);
        #100ns;

        spi_ctrl.trans(WRITE_WD, 124, 'hDDDDDD, );
        #100ns;

        #500ns;


        // Read irq_deassert_thresh
        spi_ctrl.trans(READ_HW, 12, 0, DEASSERT_THRESH);
        #100ns;

        // Read irq_assert_thresh
        spi_ctrl.trans(READ_HW, 14, 0, ASSERT_THRESH);
        #100ns;

        // Read DAC configs
        for (int i = 0; i < `NUM_DACS; i++) begin
            spi_ctrl.trans(READ_HW, i*2 + 20, 0, 'h5aa + i);
            #100ns;
        end

        // Read bias config
        spi_ctrl.trans(READ_WD, 112, 'hAAAAAA, 'hAAAAAA);
        #100ns;
        
        spi_ctrl.trans(READ_WD, 116, 'hBBBBBB, 'hBBBBBB);
        #100ns;

        spi_ctrl.trans(READ_WD, 120, 'hCCCCCC, 'hCCCCCC);
        #100ns;

        spi_ctrl.trans(READ_WD, 124, 'hDDDDDD, 'hDDDDDD);

        #300ns;

        $stop;
    end

endmodule : tb
