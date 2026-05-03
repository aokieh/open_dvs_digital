(* keep_hierarchy = "yes" *)
module col_sync_shield (
    input  logic        clk,
    input  logic [63:0] async_in,
    output logic [63:0] sync_out
);

`ifdef SYNTHESIS
    // -----------------------------------------------------------
    // PHYSICAL IMPLEMENTATION (Seen only by OpenLane/Yosys)
    // -----------------------------------------------------------
    (* keep = "true" *) (* dont_touch = "true" *) logic [63:0] stage1;

    genvar i;
    generate
        for (i = 0; i < 64; i++) begin : gen_sync
            sky130_fd_sc_hd__dfxtp_1 sync_flop_1 (
                .D(async_in[i]),
                .CLK(clk),
                .Q(stage1[i])
            );

            sky130_fd_sc_hd__dfxtp_1 sync_flop_2 (
                .D(stage1[i]),
                .CLK(clk),
                .Q(sync_out[i])
            );
        end
    endgenerate

`else
    // -----------------------------------------------------------
    // SIMULATION IMPLEMENTATION (Seen only by Verilator/VCS/etc.)
    // -----------------------------------------------------------
    logic [63:0] stage1;

    always_ff @(posedge clk) begin
        stage1   <= async_in;
        sync_out <= stage1;
    end

`endif

endmodule