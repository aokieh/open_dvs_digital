//------------------------------
// Regfile Parameters
//------------------------------

`define CHIP_ID 8'h55

`define RF_WIDTH  32

`define RF_DEPTH  32

`define RF_AWIDTH $clog2(`RF_DEPTH)

`define RF_MASK (`RF_WIDTH / 8)

`define LSB_DIV (`RF_WIDTH / 8)

`define DAC_WIDTH 12

`define NUM_DACS  10

`define BIAS_WIDTH 24

`define NUM_BIASES  0


//------------------------------
// Array size parameters
//------------------------------
`define IMAGER_COL_WIDTH 128

//------------------------------
// Sync FIFO Parameters
//------------------------------

`define FIFO_WIDTH 136

`define FIFO_DEPTH 16

`define FIFO_AWIDTH $clog2(`FIFO_DEPTH)

//------------------------------
// Async FIFO Parameters
//------------------------------

`define FIFO_WIDTH_ASYNC 10

// `define FIFO_DEPTH_ASYNC 64 // a bit large
// `define FIFO_DEPTH_ASYNC 32
`define FIFO_DEPTH_ASYNC 16 // works fine
// `define FIFO_DEPTH_ASYNC 10 // undersized, power of 2 plz

`define FIFO_AWIDTH_ASYNC $clog2(`FIFO_DEPTH_ASYNC)