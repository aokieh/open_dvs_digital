module sram_fifo_size_ctrl #(
    parameter WIDTH=16, DEPTH=16, SIZE=SIZE_BT,
    localparam AWIDTH     = $clog2(DEPTH * WIDTH / 8), // Byte address width
    localparam FIFO_DEPTH = DEPTH * WIDTH / 2**(3+SIZE),
    localparam BIT_END    = $clog2(WIDTH / 8)
) (
    sram_fifo_wrapper_intf.fifo fifo_intf,
    sram_fifo_wrapper_intf.sram sram_intf
);

endmodule : sram_fifo_size_ctrl
