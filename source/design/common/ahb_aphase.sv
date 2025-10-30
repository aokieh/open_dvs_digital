//---------------------------------------------------------------------------
// Author: Kwesi Buabeng Debrah
// Date  : Apr 11, 2025
//
// Module: ahb_aphase
//
// Description: 
//  Module that registers address phase signals and decode byte-lanes.
//---------------------------------------------------------------------------


module ahb_aphase (
    ahb_intf.peripheral_in ahb_intf,
    input  logic           clk,
    input  logic           rst_n,
    output logic           hsel,
    output logic           hwrite,
    output logic [ 1:0]    htrans,
    output logic [ 2:0]    hsize,
    output logic [31:0]    haddr,
    output logic [ 7:0]    wr_en
);

    // Byte lane signals
    logic       tx_bt;
    logic       tx_hw;
    logic       tx_wd;
    logic       tx_dw;
    logic [7:0] bt_en;
    logic [3:0] hw_en;
    logic [1:0] wd_en;
    logic       dw_en;


    //---------------------------------------------------------------------------
    // Sample address phase signals
    //---------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hsel   <= '0;
            hwrite <= '0;
            htrans <= '0;
            hsize  <= '0;
            haddr  <= '0;
        end
        else if (ahb_intf.ready) begin
            hsel   <= ahb_intf.sel;
            hwrite <= ahb_intf.write;
            htrans <= ahb_intf.trans;
            hsize  <= ahb_intf.size;
            haddr  <= ahb_intf.addr;
        end
    end


    //---------------------------------------------------------------------------
    // Decode byte lanes from HSIZE and HADDR
    //---------------------------------------------------------------------------
    assign tx_bt = (hsize == 'd0);
    assign tx_hw = (hsize == 'd1);
    assign tx_wd = (hsize == 'd2);
    assign tx_dw = (hsize == 'd3);

    always_comb begin
        foreach (bt_en[i])
            bt_en[i] = tx_bt & (haddr[2:0] == i);
    
        foreach (hw_en[i])
            hw_en[i] = tx_hw & (haddr[2:0] == {i, 1'b0});

        foreach (wd_en[i])
            wd_en[i] = tx_wd & (haddr[2:0] == {i, 2'b0});
    
        dw_en = tx_dw & (haddr[2:0] == 3'b0);
    
        foreach (wr_en[i]) begin
            wr_en[i] = dw_en | wd_en[i >> 2] | hw_en[i >> 1] | bt_en[i]; 
        end
    end

endmodule : ahb_aphase
