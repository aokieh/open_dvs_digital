//---------------------------------------------------------------------------
// Author: Kwesi Buabeng Debrah
// Date  : Mar 27, 2025
//
// Module: timer
//
// Description: 
//  Timer module to generate a flag after a specified number of clock cycles.
//  Reset the timer value by setting intf.load=1 and load_value=0.
//---------------------------------------------------------------------------


import aer_pkg::*;


module timer #(parameter DWIDTH=8) (
	timer_intf.timer 		 intf,
	input logic [DWIDTH-1:0] load_value,
	input logic [DWIDTH-1:0] threshold
);

	logic [DWIDTH-1:0] time_counter;


	//---------------------------------------------------------------------------
	// Flag generation
	//---------------------------------------------------------------------------
	always_comb begin
		intf.flag <= 0;
		
		if (intf.load) begin
			intf.flag <= 0;
		end
		else if (threshold == 0) begin
			intf.flag <= 1;
		end
		else if (time_counter >= threshold-1) begin
			intf.flag <= 1;
		end
	end


	//---------------------------------------------------------------------------
	// Counter
	//---------------------------------------------------------------------------
	always @(posedge intf.clk, negedge intf.rst_n) begin
		if (!intf.rst_n)
			time_counter <= '0;
		else
			if (intf.load)
				time_counter <= load_value;
			else if (intf.enable && !intf.flag && threshold != 0)
				time_counter <= time_counter + 1;
	end


endmodule : timer
