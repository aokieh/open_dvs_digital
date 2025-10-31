//---------------------------------------------------------------------------
// Author: Kwesi Buabeng Debrah
// Date  : Apr 2, 2025
//
// Module: sram_memory
//
// Description: 
//  A simple model of a dual-port SRAM memory.
//---------------------------------------------------------------------------


module sram_memory #(WIDTH=16, DEPTH=16) (
	input  logic                     clk  ,
	input  logic                     ce_a ,
	input  logic                     ce_b ,
	input  logic [$clog2(DEPTH)-1:0] addr_a,
	input  logic [$clog2(DEPTH)-1:0] addr_b,
	input  logic                     we_a ,
	input  logic                     we_b ,
	input  logic [    (WIDTH/8)-1:0] wmask_a,
	input  logic [    (WIDTH/8)-1:0] wmask_b,
	input  logic [        WIDTH-1:0] wdata_a,
	input  logic [        WIDTH-1:0] wdata_b,
	output logic [        WIDTH-1:0] rdata_a,
	output logic [        WIDTH-1:0] rdata_b
);

	logic [WIDTH-1:0] mem [DEPTH];


	//---------------------------------------------------------------------------
	// Read and Write Operations
	//---------------------------------------------------------------------------
	always_ff @(posedge clk) begin
		// Port A
		if (ce_a) begin

			if (we_a) begin
				foreach(wmask_a[i]) begin
					if (wmask_a[i]) begin
						mem[addr_a][i*8+:8] <= wdata_a[i*8+:8];
					end
				end
			end else begin
				rdata_a <= mem[addr_a];
			end

		end


		// Port B
		if (ce_b) begin

			if (we_b) begin
				foreach(wmask_b[i]) begin
					if (wmask_b[i]) begin
						mem[addr_b][i*8+:8] <= wdata_b[i*8+:8];
					end
				end
			end else begin
				rdata_b <= mem[addr_b];
			end
			
		end
	end


endmodule : sram_memory
