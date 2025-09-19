module sram_memory #(WIDTH=16, DEPTH=16) (
	input  logic                     clk  ,
	input  logic                     ce   ,
	input  logic [$clog2(DEPTH)-1:0] addr ,
	input  logic                     we   ,
	input  logic [    (WIDTH/8)-1:0] wmask, // byte wise mask for writes
	input  logic [        WIDTH-1:0] wdata,
	output logic [        WIDTH-1:0] rdata
);

logic [WIDTH-1:0] mem [DEPTH];

always_ff @(posedge clk) begin
	if (ce) begin
		if (we) begin
			for (int i = 0; i < WIDTH; i++) begin
				if (wmask[i/8]) begin
					mem[addr][i] <= wdata[i];
				end
			end
		end else begin
			rdata <= mem[addr];
		end
	end
end

endmodule : sram_memory