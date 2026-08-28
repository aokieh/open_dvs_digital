`timescale 1ns/1ps
`default_nettype none

// V3 imports the exact sealed v2 fixture only after the runner validates the
// v1 archive and complete v2 test seal.
`include "fver/hardware_codec/integration/sync_product_preframing_v2/fixture_sync_product_preframing_v2.sv"

`default_nettype wire
