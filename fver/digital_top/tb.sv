`timescale 1ns/1ps

import pkg_spi_fver::*;

module tb ();

    localparam CLK_P = 5ns;
    localparam DEPTH = 8;

    localparam DEASSERT_THRESH = 11;
    localparam ASSERT_THRESH   = 789;

    logic clk  = 0;
    logic rst_n = 0;

    // SPI Interface
    logic CS_N;
    logic SCK;
    logic COPI;
    logic CIPO;

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

        // SPI Interface
        .CS_N,
        .SCK,
        .COPI,
        .CIPO
    );


    initial begin
        spi_ctrl.init();
        
        #(10*CLK_P);
        rst_n = 1;

        #(5*CLK_P);

        #100ns;

        // Read Chip ID
        spi_ctrl.trans(READ_BT, 0, 0, 'h55);
        #100ns;

        // Pulse fifo_rst_n
        spi_ctrl.trans(WRITE_BT, 1, 1);
        #100ns;

        // Set irq_deassert_thresh
        spi_ctrl.trans(WRITE_HW, 12, DEASSERT_THRESH);
        #100ns;

        // Set irq_assert_thresh
        spi_ctrl.trans(WRITE_HW, 14, ASSERT_THRESH);
        #100ns;

        // Set DAC configs
        for (int i = 0; i < `NUM_DACS; i++) begin
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
