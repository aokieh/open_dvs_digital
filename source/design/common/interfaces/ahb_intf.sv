//---------------------------------------------------------------------------
// Author: Kwesi Buabeng Debrah
// Date  : Mar 7, 2025
//
// Interface: ahb_intf
//
// Description: 
//  Defines the interface for the AHB bus and modports for various 
//  controllers and peripherals.
//
//  The controllers of the bus are S7, DMA, etc.
//  The peripherals include UART/SPI cfg, AER RCV/XMT, etc.
//
//  Refer to the ARM AMBA AHB/AHB-Lite Documentation for protocol details.
//---------------------------------------------------------------------------


interface ahb_intf #(parameter AWIDTH=32, DWIDTH=64);
	logic              ready    ;
	logic              resp     ;
	logic [DWIDTH-1:0] rdata    ;
	logic [AWIDTH-1:0] addr     ;
	logic              write    ;
	logic [       2:0] size     ;
	logic [       1:0] trans    ;
	logic [DWIDTH-1:0] wdata    ;
	logic              sel      ;
	logic              ready_out;
	logic [       2:0] burst    ;

	// Used by S7, DMA, etc.
	modport controller_out (
		input  ready,
		input  resp,
		input  rdata,
		output addr,
		output write,
		output sel,
		output size,
		output trans,
		output wdata,
		output burst
	);

	// 
	modport controller_in (
		input  addr,
		input  write,
		input  size,
		input  trans,
		input  wdata,
		output rdata,
		output resp,
		output ready
	);

	// Used by the peripheral
    modport peripheral_in (
		input  sel,
		input  addr,
		input  write,
		input  size,
		input  trans,
		input  ready,
		input  wdata,
		output ready_out,
		output resp,
		output rdata
	);

	// Used by deco/mux to select the peripheral
	modport peripheral_out (
		output sel,
		output addr,
		output write,
		output size,
		output trans,
		output ready,
		output wdata,
		input  ready_out,
		input  resp,
		input  rdata
	);
    
endinterface : ahb_intf
