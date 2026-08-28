`timescale 1ns/1ps
`default_nettype none

// Verified import of the frozen v1 fixture. The v2 runner validates the v1
// archive seal before this source can reach Xcelium.
`include "fver/hardware_codec/integration/sync_product_preframing/fixture_sync_product_preframing.sv"

`default_nettype wire
