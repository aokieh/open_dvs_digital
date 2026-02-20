
`define CHIP_ID 8'h55

`define RF_WIDTH  32

`define RF_DEPTH  32

`define RF_AWIDTH $clog2(`RF_DEPTH)

`define RF_MASK (`RF_WIDTH / 8)

`define LSB_DIV (`RF_WIDTH / 8)

`define FIFO_WIDTH 136

`define FIFO_DEPTH 16

`define FIFO_AWIDTH $clog2(`FIFO_DEPTH)

`define DAC_WIDTH 12

`define NUM_DACS  8

`define BIAS_WIDTH 24

`define NUM_BIASES  4