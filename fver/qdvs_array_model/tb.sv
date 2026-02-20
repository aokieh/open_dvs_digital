`timescale 1ns/1ps

module tb_qdvs_array_model;

    parameter int WIDTH = 128;
    parameter int DEPTH = 129;

    logic clk;
    logic [DEPTH-1:0] row_sel;
    logic [WIDTH-1:0] bv_out;

    // Instantiate DUT
    qdvs_array_model #(
        .WIDTH(WIDTH),
        .DEPTH(DEPTH)
    ) dut (
        .clk(clk),
        .row_sel(row_sel),
        .bv_out(bv_out)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        row_sel = '0;

        // Wait for memory load
        #20;

        // $display("Loading memory...");
        // if ($readmemb("qdvs_sample_data.txt", dut.mem)) begin
        //     $display("Memory loaded successfully.");
        // end else begin
        //     $display("Memory load failed!");
        // end

        $display("\n\nLoading memory...");
        $readmemb("../../../source/qdvs_array_model/qdvs_sample_data.txt", dut.mem);
        $display("Memory load complete.");

        // Sweep through all rows
        for (int i = 0; i < DEPTH; i++) begin
            row_sel = 1 << i;
            #10;
            $display("Row %03d -> %b", i, bv_out);
        end

        $display("Test complete.");
        $finish;
    end

endmodule