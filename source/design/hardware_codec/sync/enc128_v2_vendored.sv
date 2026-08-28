`timescale 1ns/1ps

// Frozen source provenance:
//   repository: /home/rpgraca/git/opendvs-encoder-asic-sync
//   commit: 2426bf27b15f9f43d841c5afce71682073fb170a
//   source file SHA-256:
//     652c6c92e7b970575ef12d6fc2503cc18360c1c7c8e7e03cedb4537ddd121e01
//   module region through endmodule, excluding the trailing newline:
//     626876003ab1fa6efeb441b80bd835fc32389d5a86ec0e1f5e681e3b7734b757
// Do not edit the module region below. Wrapper fixes belong outside this leaf.
module enc128 #(parameter int NCOL=128, ROWW=7, THRESH=15)(
    input  logic clk, rst_n,
    input  logic in_val, output logic in_rdy,
    input  logic [ROWW-1:0] in_row, input logic in_pol, input logic [NCOL-1:0] in_mask,
    input  logic [31:0] in_dt,          // tick delta for this record
    output logic out_val, input logic out_rdy, output logic [7:0] out_data
);
    localparam int NB = NCOL/8;
    typedef enum logic [2:0] {IDLE, HDR, EXT, ROWB, POS, RAWB} st_t;
    st_t st;
    logic [ROWW-1:0] row_r; logic pol_r, mode_r;
    logic [NCOL-1:0] work; logic [7:0] rem; logic [4:0] rawi;
    logic [31:0] dtx;                    // remaining escaped dt (LEB128)
    logic [5:0]  dt6_r; logic dt_esc_r;  // dt latched at record accept

    logic [7:0] pc; integer i;
    always_comb begin pc='0; for(i=0;i<NCOL;i++) pc=pc+in_mask[i]; end
    logic [ROWW-1:0] fpos; integer j;
    always_comb begin fpos='0; for(j=0;j<NCOL;j++) if(work[j]) fpos=j[ROWW-1:0]; end
    wire sparse = (pc<=THRESH);

    assign in_rdy = (st==IDLE);

    always_comb begin
        case(st)
            HDR:  out_data = {mode_r, pol_r, dt6_r};
            EXT:  out_data = {(dtx >= 128) ? 1'b1 : 1'b0, dtx[6:0]};
            ROWB: out_data = {1'b0, row_r};
            POS:  out_data = {(rem==8'd1) ? 1'b1 : 1'b0, fpos};
            RAWB: out_data = work[rawi*8 +: 8];
            default: out_data = 8'd0;
        endcase
        out_val = (st==HDR)||(st==EXT)||(st==ROWB)||(st==POS)||(st==RAWB);
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin st<=IDLE; rawi<='0; rem<='0; work<='0; row_r<='0; pol_r<=0; mode_r<=0; dtx<='0; dt6_r<='0; dt_esc_r<=0; end
        else case(st)
            IDLE: if(in_val) begin
                      row_r<=in_row; pol_r<=in_pol; work<=in_mask;
                      mode_r<=sparse; rem<=pc; rawi<='0;
                      dt6_r <= (in_dt >= 63) ? 6'd63 : in_dt[5:0];
                      dt_esc_r <= (in_dt >= 63);
                      dtx <= (in_dt >= 63) ? (in_dt - 63) : 32'd0;
                      st <= (pc==0) ? IDLE : HDR;
                  end
            HDR:  if(out_rdy) st <= dt_esc_r ? EXT : ROWB;
            EXT:  if(out_rdy) begin
                      if(dtx >= 128) dtx <= dtx >> 7;
                      else st <= ROWB;
                  end
            ROWB: if(out_rdy) st <= mode_r ? POS : RAWB;
            POS:  if(out_rdy) begin work[fpos]<=1'b0; rem<=rem-1'b1; if(rem==8'd1) st<=IDLE; end
            RAWB: if(out_rdy) begin rawi<=rawi+1'b1; if(rawi==NB-1) st<=IDLE; end
            default: st<=IDLE;
        endcase
    end
endmodule
