//---------------------------------------------------------------------------
// Author: Kwesi Buabeng Debrah
// Date  : Apr 7, 2025
//
// Module: sram_byte_ctrl
//
// Description: 
//  SRAM controller for byte-addressable capabaility.
//---------------------------------------------------------------------------


import aer_pkg::*;


module sram_byte_ctrl #(
    parameter WIDTH=16, DEPTH=16, SIZE_A=SIZE_BT, SIZE_B=SIZE_BT,
    localparam AWIDTH  = $clog2(DEPTH * WIDTH / 8), // Byte address width
    localparam BIT_END = $clog2(WIDTH / 8)
) (
    input  logic [       AWIDTH-1:0] addr_a_i, // Byte address
	input  logic [       AWIDTH-1:0] addr_b_i, // Byte address
    output logic [$clog2(DEPTH)-1:0] addr_a_o,
	output logic [$clog2(DEPTH)-1:0] addr_b_o,
    output logic [    (WIDTH/8)-1:0] wmask_a,
	output logic [    (WIDTH/8)-1:0] wmask_b
);

    // Byte lane signals
    logic                  tx_bt_a, tx_bt_b;
    logic                  tx_hw_a, tx_hw_b;
    logic                  tx_wd_a, tx_wd_b;
    logic                  tx_dw_a, tx_dw_b;
    logic [(WIDTH/ 8)-1:0] bt_en_a, bt_en_b;
    logic [(WIDTH/16)-1:0] hw_en_a, hw_en_b;
    logic [(WIDTH/32)-1:0] wd_en_a, wd_en_b;
    logic                  dw_en_a, dw_en_b;
    logic [(WIDTH/ 8)-1:0] wr_en_a, wr_en_b; // Byte write enables


    //---------------------------------------------------------------------------
    // Outputs
    //---------------------------------------------------------------------------
    assign addr_a_o = addr_a_i[$size(addr_a_i)-1 : BIT_END];
    assign addr_b_o = addr_b_i[$size(addr_b_i)-1 : BIT_END];

    assign wmask_a  = wr_en_a;
    assign wmask_b  = wr_en_b;


    //---------------------------------------------------------------------------
    // Decode byte lanes from SIZE and ADDR
    //---------------------------------------------------------------------------
    always_comb begin
        tx_bt_a = (SIZE_A == 'd0);
        tx_hw_a = (SIZE_A == 'd1);
        tx_wd_a = (SIZE_A == 'd2);
        tx_dw_a = (SIZE_A == 'd3);

        tx_bt_b = (SIZE_B == 'd0);
        tx_hw_b = (SIZE_B == 'd1);
        tx_wd_b = (SIZE_B == 'd2);
        tx_dw_b = (SIZE_B == 'd3);


        foreach (bt_en_a[i]) begin
            bt_en_a[i] = tx_bt_a & (addr_a_i[BIT_END-1:0] == i);
            bt_en_b[i] = tx_bt_b & (addr_b_i[BIT_END-1:0] == i);
        end
    
        foreach (hw_en_a[i]) begin
            hw_en_a[i] = tx_hw_a & (addr_a_i[BIT_END-1:0] == {i, 1'b0});
            hw_en_b[i] = tx_hw_b & (addr_b_i[BIT_END-1:0] == {i, 1'b0});
        end

        foreach (wd_en_a[i]) begin
            wd_en_a[i] = tx_wd_a & (addr_a_i[BIT_END-1:0] == {i, 2'b0});
            wd_en_b[i] = tx_wd_b & (addr_b_i[BIT_END-1:0] == {i, 2'b0});
        end
    
        dw_en_a = tx_dw_a & (addr_a_i[BIT_END-1:0] == 3'b0);
        dw_en_b = tx_dw_b & (addr_b_i[BIT_END-1:0] == 3'b0);
    
        foreach (wr_en_a[i]) begin
            wr_en_a[i] = dw_en_a | wd_en_a[i >> 2] | hw_en_a[i >> 1] | bt_en_a[i]; 
            wr_en_b[i] = dw_en_b | wd_en_b[i >> 2] | hw_en_b[i >> 1] | bt_en_b[i]; 
        end
    end

endmodule : sram_byte_ctrl
