//---------------------------------------------------------------------------
// Author: Kwesi Buabeng Debrah
// Date  : Mar 28, 2025
//
// Module: reset_timer
//
// Description: 
//  Controls AER reset based on reset_mode and rst_thresh.
//  It self-resets one-cycle after reaching the threshold.
//  
//  The reset mode is controlled by the reset_mode signal:
//      reset_mode: 0 = Regfile Reset; 1 = Reset Timer Flag
//---------------------------------------------------------------------------


import aer_pkg::*;


module reset_timer (
    input  logic                     clk,
    input  logic                     rst_n,
    input  logic                     enable,
    input  logic                     reset_mode,
    input  logic                     rf_aer_rst_n,
    input  logic [RST_TMR_WIDTH-1:0] threshold,
    output logic                     rst_out
);

    // Timer Interface
    timer_intf #(RST_TMR_WIDTH) timer_intf (clk, rst_n);
    
    logic load, load_reg;
    logic flag_reg; // Used for edge detection


    //-----------------------------------------------------------------------
    // Reset Timer
    //-----------------------------------------------------------------------
    assign timer_intf.enable     = enable;
    assign timer_intf.load       = load_reg;

    timer #(RST_TMR_WIDTH) i_timer (
        .intf     (timer_intf),
        .load_value('0       ),
        .threshold(threshold )
    );


    //---------------------------------------------------------------------------
    // Output Multiplexer
    //---------------------------------------------------------------------------
    assign rst_out = reset_mode ? !timer_intf.flag : rf_aer_rst_n;


    //---------------------------------------------------------------------------
    // Load Flag (Used to reset the counter value to 0)
    //---------------------------------------------------------------------------
    assign load = timer_intf.flag && !flag_reg; // Edge detection

    // Delay registers
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            load_reg <= 0;
            flag_reg <= 0;
        end
        else begin
            load_reg <= load;
            flag_reg <= timer_intf.flag;
        end
    end


endmodule : reset_timer
