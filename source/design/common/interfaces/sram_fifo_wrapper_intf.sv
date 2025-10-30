//---------------------------------------------------------------------------
// Author: Kwesi Buabeng Debrah
// Date  : Apr 4, 2025
//
// Interface: sram_fifo_wrapper_intf
//
// Description: 
//  Defines the signals and modports for the FIFO-to-MEM interface.
//---------------------------------------------------------------------------


import aer_pkg::*;


interface sram_fifo_wrapper_intf #(
    parameter WIDTH=16, DEPTH=16, SIZE=SIZE_BT,
    localparam AWIDTH = $clog2(DEPTH * WIDTH / 8), // Byte address width
    localparam FIFO_DWIDTH = 2**(3+SIZE),
    localparam FIFO_DEPTH  = DEPTH * WIDTH / 2**(3+SIZE)
) (input clk, rst_n);
    // FIFO
    logic                        fifo_rst_n;
    logic                        fifo_empty;
    logic                        fifo_full ;
    logic [$clog2(FIFO_DEPTH):0] fifo_numel;
    logic [          AWIDTH-1:0] fifo_wr_ptr; // Byte address
    logic [          AWIDTH-1:0] fifo_rd_ptr; // Byte address
    logic [     FIFO_DWIDTH-1:0] fifo_rdata;
    logic [     FIFO_DWIDTH-1:0] fifo_wdata;
    logic                        fifo_rd_en;
    logic                        fifo_wr_en;
    // SRAM
    logic                        ce_a   ;
    logic                        ce_b   ;
    logic [   $clog2(DEPTH)-1:0] addr_a ;
    logic [   $clog2(DEPTH)-1:0] addr_b ;
    logic                        we_a   ;
    logic                        we_b   ;
    logic [       (WIDTH/8)-1:0] wmask_a;
    logic [       (WIDTH/8)-1:0] wmask_b;
    logic [           WIDTH-1:0] wdata_a;
    logic [           WIDTH-1:0] wdata_b;
    logic [           WIDTH-1:0] rdata_a;
    logic [           WIDTH-1:0] rdata_b;


    // FSM <--> Mem2FIFO
    modport fifo (
        input  clk,
        input  rst_n,
        input  fifo_rst_n,
        input  fifo_rd_en,
        input  fifo_wr_en,
        input  fifo_wdata,
        output fifo_empty,
        output fifo_full ,
        output fifo_numel,
        output fifo_wr_ptr,
        output fifo_rd_ptr,
        output fifo_rdata
    );


    // Mem2FIFO <--> SRAM
    modport sram (
        input  clk,
        input  rst_n,
        input  rdata_a,
        input  rdata_b,
        output ce_a   ,
        output ce_b   ,
        output addr_a ,
        output addr_b ,
        output we_a   ,
        output we_b   ,
        output wmask_a,
        output wmask_b,
        output wdata_a,
        output wdata_b
    );

endinterface : sram_fifo_wrapper_intf