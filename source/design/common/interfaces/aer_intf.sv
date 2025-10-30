//---------------------------------------------------------------------------
// Author: Kwesi Buabeng Debrah
// Date  : Mar 25, 2025
//
// Interface: ahb_interface
//
// Description: 
//  Defines the AER interface and modports for the AER receiver and 
//  transmitter modules. 
//---------------------------------------------------------------------------


import aer_pkg::*;


interface aer_intf;
    logic [AER_OH_WIDTH-1:0] one_hot_code;
    logic                    ack;
    logic                    aer_rst_n;
    
    // AER Receiver
    modport receiver (
        input  one_hot_code,
        output ack,
        output aer_rst_n
    );

    // AER Transmitter
    modport transmitter (
        output one_hot_code,
        input  ack,
        output aer_rst_n
    );

endinterface : aer_intf
