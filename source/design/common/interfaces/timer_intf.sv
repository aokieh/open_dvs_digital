//---------------------------------------------------------------------------
// Author: Kwesi Buabeng Debrah
// Date  : Apr 9, 2025
//
// Interface: timer_intf
//
// Description: 
//  Defines an interface for the handshaking timer control signals. 
//---------------------------------------------------------------------------


interface timer_intf #(parameter DWIDTH=8) (input clk, rst_n);
    logic enable;
    logic load;
    logic flag;


    modport ctrl (
        output enable,
        output load,
        input  flag
    );


    modport timer (
        input  clk,
        input  rst_n,    
        input  enable,
        input  load,
        output flag
    );

endinterface : timer_intf