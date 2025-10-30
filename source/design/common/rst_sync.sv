//---------------------------------------------------------------------------
// Author: Kwesi Buabeng Debrah
// Date  : Apr 24, 2025
//
// Module: rst_sync
//
// Description: 
//  System reset synchronizer.
//  Synchronizes the reset deassertion to the clock domain.
//---------------------------------------------------------------------------


module rst_sync (
    input  logic clk,
    input  logic rst_n,
    output logic rst_sync_n
);

    // Synchronizer shift registers
    logic [1:0] sync_sr;


    assign rst_sync_n = sync_sr[1];


    // Synchronize the reset signal to the clock domain
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            sync_sr <= '0;
        end else begin
            sync_sr <= {sync_sr[0], 1'b1};
        end
    end

endmodule : rst_sync
