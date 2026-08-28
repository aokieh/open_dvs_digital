`timescale 1ns/1ps
`default_nettype none

// Verified import of the frozen v1 semantic testbench. The v2 runner validates
// the v1 archive seal before this source can reach Xcelium.
`include "fver/hardware_codec/integration/sync_product_preframing/tb_sync_product_preframing.sv"

module tb_sync_product_preframing_v2;
    tb_sync_product_preframing archived_v1_semantics();
endmodule

`default_nettype wire
