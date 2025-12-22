`timescale 1ns/1ps

import pkg_spi_fver::*;

module tb ();

    localparam CLK_P = 5ns;
    localparam DEPTH = 8;

    logic clk  = 0;
    logic rst_n = 0;

    // SPI Interface
    logic CS_N;
    logic SCK;
    logic [3:0] COPI;
    logic [3:0] CIPO;

    spi_intf i_spi_intf(
        .CS_N(CS_N),
        .SCK (SCK ),
        .COPI(COPI),
        .CIPO(CIPO)
    );

    class_spi_ctrl spi_ctrl = new (i_spi_intf);

    // Memory Interface
    logic                  we;
    logic [`RF_AWIDTH-1:0] addr;
    logic [ `RF_WIDTH-1:0] wdata;
    logic [  `RF_MASK-1:0] wmask;
    logic [ `RF_WIDTH-1:0] rdata;

    // FIFO
    logic [15:0]        rdata_spi_0, rdata_spi_1;
    logic [1:0]         shift_en;

    always #(CLK_P/2) clk = ~clk;

    spi_peripheral i_spi_peripheral (
        .CS_N,
        .SCK,
        
        //SPI interface
        .COPI,
        .CIPO,
        
        //Memory interface
        .addr,
        .we,
        .wdata,
        .wmask,
        .rdata

        //FIFO interface
        .shift_en,
        .rdata_spi_0,
        .rdata_spi_1
    );


    initial begin
        spi_ctrl.init();

        #100ns;

        spi_ctrl.trans(WRITE_BT, 3, 'h55); //
        #100ns;
        spi_ctrl.trans(WRITE_HW, 6, 'hAABB);
        #100ns;
        spi_ctrl.trans(WRITE_WD, 8, 'hCCCCDDDD);

        #500ns;

        rdata = 'h55_00_00_00;
        spi_ctrl.trans(READ_BT, 3, 0, 'h55);
        #100ns;

        rdata = 'hAA_BB_00_00;
        spi_ctrl.trans(READ_HW, 6, 0, 'hAABB);
        #100ns;

        rdata = 'hCC_CC_DD_DD;
        spi_ctrl.trans(READ_WD, 8, 0, 'hCCCCDDDD);
        #300ns;

        $stop;
    end

endmodule : tb