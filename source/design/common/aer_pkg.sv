//---------------------------------------------------------------------------
// Author: Kwesi Buabeng Debrah
// Date  : Mar 4, 2025
//
// Module: aer_pkg
//
// Description: 
//  Package that defines AER Receiver parameters.
//---------------------------------------------------------------------------


package aer_pkg;

    //---------------------------------------------------------------------------
    // AER Parameters
    //---------------------------------------------------------------------------
    parameter IMG_SIZE        = 32; // Image size (width and height)
    parameter AER_DWIDTH      = $clog2(IMG_SIZE) + 1; // Width of AER data (+ tailbit)
    parameter AER_OH_WIDTH    = ((AER_DWIDTH/2)*4); // Width of one-hot encoded AER data

    parameter AER_TAILWORD    = (2**AER_DWIDTH) - 1; // Tail word value (all bits set to 1)

    parameter AER_TIMER_WIDTH =  8; // Handshake Timers width

    parameter RST_TMR_WIDTH   = 16; // Reset Timer width

    parameter EVT_CTR_WIDTH   = 32; // Event Counter width
    parameter EVT_TMR_WIDTH   = 32; // Event Timer width


    //---------------------------------------------------------------------------
    // FSM Parameters
    //---------------------------------------------------------------------------
    parameter SIZE_BT          = 2'b00; // Byte Transfer
    parameter SIZE_HW          = 2'b01; // Half Word Transfer
    parameter SIZE_WD          = 2'b10; // Word Transfer
    parameter SIZE_DW          = 2'b11; // Double Word Transfer

    parameter TX_DATA_SIZE     = SIZE_BT;
    
    parameter RX_DATA_SIZE_RAW = SIZE_DW; // Raw
    parameter RX_DATA_SIZE_DEC = SIZE_WD; // Decoded
    parameter RX_DATA_SIZE_CNT = SIZE_DW; // Spike Count
    parameter RX_DATA_SIZE_ISI = SIZE_DW; // Inter-Spike Interval

    parameter RAW_DWIDTH       = (2**(3+RX_DATA_SIZE_RAW)); // Raw Data Width
    parameter DEC_DWIDTH       = (2**(3+RX_DATA_SIZE_DEC)); // Decoded Data Width (10 bits) + Timestamp (20 bits)
    parameter OH_DEC_WIDTH     = 8; // Width used to store decoded AER data in FIFO. Did this cause we are using full width of memory.

    parameter TIMESTAMP_WIDTH  = DEC_DWIDTH - (2*OH_DEC_WIDTH); // Timestamp counter width
    parameter TIME_RES_WIDTH   = 16; // Timestamp resolution width


    //---------------------------------------------------------------------------
    // FIFO Parameters
    //---------------------------------------------------------------------------
    parameter RX_FIFO_DWIDTH    = 64;
    parameter RX_MEM_DEPTH      = 4096; //NOTE: Should match memory primitive depth
    parameter RX_FIFO_DEPTH_RAW = RX_MEM_DEPTH * RX_FIFO_DWIDTH / (2**(3+RX_DATA_SIZE_RAW));
    parameter RX_FIFO_DEPTH_DEC = RX_MEM_DEPTH * RX_FIFO_DWIDTH / (2**(3+RX_DATA_SIZE_DEC));

    parameter TX_MEM_DWIDTH     = 16; // Memory Data Width
    parameter TX_MEM_DEPTH      = 1024; //NOTE: Should match memory primitive depth
    parameter TX_FIFO_DEPTH     = TX_MEM_DEPTH * TX_MEM_DWIDTH / (2**(3+TX_DATA_SIZE));

    parameter UART_FIFO_DEPTH   = 64;

    parameter UART_OVERSAMPLE_RATE = 16-1; // UART Oversampling rate


    //---------------------------------------------------------------------------
    // Register File Parameters
    //---------------------------------------------------------------------------
    parameter AER_RCV_ID  = 'h55;
    parameter AER_XMT_ID  = 'hAA;
    
    parameter UART_RF_DEPTH = 1+2;
    parameter RCV_RF_DEPTH  = 1+22+1; // Extras used for "printf" in C code
    parameter XMT_RF_DEPTH  = 1+9;

    
    //---------------------------------------------------------------------------
    // State Machine Types
    //---------------------------------------------------------------------------
    typedef enum {
        RX_IDLE, SAMPLE_DATA, 
        SEND_ACK, SEND_NACK, RX_REFRACTORY,
        READ_MEM, WRITE_MEM
    } aer_rcv_state_t;

    // AER Transmitter FSM States
    typedef enum {
        TX_IDLE, SAMPLE_FIFO, SEND_DATA, 
        WAIT_ACK, WAIT_NACK, TX_REFRACTORY
    } aer_xmt_state_t;

    // ROI Type
    typedef struct packed {
        logic [7:0] h;
        logic [7:0] w;
        logic [7:0] y;
        logic [7:0] x;
    } roi_t;

    // UART State Type
    typedef enum { IDLE, START_BIT, DATA_BITS, STOP_BIT } state_t;
    
endpackage : aer_pkg
