//---------------------------------------------------------------------------
// Author: Ababakar Okieh
// Date  : Feb 11, 2026
//
// Module: qdvs_array_model
//
// Description: 
//  A simple model of the qDVS pixel for array level digital simulations.
//---------------------------------------------------------------------------

module qdvs_array_model #(
    parameter int WIDTH = 128,  // bits per row
    parameter int DEPTH = 129   // number of rows
)(
    input  logic                   clk,
    input  logic [DEPTH-1:0]       row_sel,   // one-hot row select
    output logic [WIDTH-1:0]       bv_out     // selected row data
);

    // 129 rows, each 128 bits wide
    logic [WIDTH-1:0] mem [DEPTH];
	//pre-load data to be written in the memory and activate row_sel from tb

    initial begin
        $readmemb("../scripts/qdvs_sample_data.txt", mem);   // loading on/off evt data to memory array
    end

    always_comb begin
        bv_out = '0;

        if ($onehot(row_sel)) begin
            for (int i = 0; i < DEPTH; i++) begin
                if (row_sel[i])
                    bv_out = mem[i];
            end
        end
    end

endmodule : qdvs_array_model