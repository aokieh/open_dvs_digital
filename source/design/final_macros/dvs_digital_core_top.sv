//---------------------------------------------------------------------------
// Module: dvs_digital_core_top
// Description: 
//  Top-level integration of the DVS digital backend before OpenLane macro hardening.
//---------------------------------------------------------------------------

module dvs_digital_core_top (
    `ifdef USE_POWER_PINS
        inout vccd1,
        inout vssd1,
    `endif

    input  logic         sys_clk,
    input  logic         rst_n,

    // -----------------------------------------------------------
    // External Quad-SPI Interface (To Master/FPGA)
    // -----------------------------------------------------------
    input  logic         spi_sck,
    input  logic         spi_cs_n,
    input  logic [3:0]   spi_copi,          // Controller-Out, Peripheral In
    input  logic [3:0]   spi_cipo,          // Controller-In, Peripheral Out
    // -----------------------------------------------------------
    // Analog Array Interface (Split-Bitline 128x128)
    // -----------------------------------------------------------
    // Column Data In
    input  logic [`IMAGER_COL_WIDTH-1:0]  array_col_top,
    input  logic [`IMAGER_COL_WIDTH-1:0]  array_col_bot,
    
    // Row Control Out - top and bottom FSM instances
    output logic [63:0] row_on_detect_top,
    output logic [63:0] row_off_detect_top,
    output logic [63:0] row_pixel_rst_top,

    output logic [63:0] row_on_detect_bot,
    output logic [63:0] row_off_detect_bot,
    output logic [63:0] row_pixel_rst_bot,

    output logic [1:0]     global_pre_charge
);

    // -----------------------------------------------------------
    // Internal Routing Bus
    // -----------------------------------------------------------
    
    // RegFile to ROIC FSM (Control Plane)
    logic        int_sm_enable;
    logic [7:0]  int_program_bits;
    // (Add any other register-driven controls here)

    // ROIC FSM to FIFO (Data Plane Write)
    logic        int_fifo_wr_en;
    logic [135:0] int_fifo_wdata;
    logic        int_fifo_full;
    logic        int_fifo_empty;

    // FIFO to SPI Peripheral (Data Plane Read)
    logic        int_shift_en;
    logic [15:0] int_rdata_spi;

    // -----------------------------------------------------------
    // 1. SPI Peripheral
    // -----------------------------------------------------------
    // Handles physical SPI protocol, demuxes reads/writes, 
    // and controls bidirectional IO buffers.
    spi_peripheral i_spi_peripheral (
        .clk         (sys_clk),
        .rst_n       (rst_n),
        .spi_sck     (spi_sck),
        .spi_cs_n    (spi_cs_n),
        .spi_io      (spi_io),
        
        // To RegFile (Write Interface)
        .reg_addr    (/* route to regfile */),
        .reg_wdata   (/* route to regfile */),
        .reg_wr_en   (/* route to regfile */),
        
        // From FIFO (Read Interface)
        .fifo_rdata  (int_rdata_spi),
        .shift_en    (int_shift_en)
    );

    // -----------------------------------------------------------
    // 2. Register File
    // -----------------------------------------------------------
    regfile i_regfile (
        .clk         (sys_clk),
        .rst_n       (rst_n),
        
        // From SPI
        .wr_addr     (/* from spi */),
        .wr_data     (/* from spi */),
        .wr_en       (/* from spi */),
        
        // To ROIC FSM
        .sm_enable   (int_sm_enable),
        .program_bits(int_program_bits)
    );

    // -----------------------------------------------------------
    // 3. ROIC Micro-Sequencer Top (128x128 Array Controller)
    // -----------------------------------------------------------
    roic_fsm_top i_roic_fsm_top (
        .sys_clk           (sys_clk),
        .rst_n             (rst_n),
        
        // Control from RegFile
        .sm_enable         (int_sm_enable),
        .program_bits      (int_program_bits),
        
        // Analog Array Connections
        .array_col_top     (array_col_top),
        .array_col_bot     (array_col_bot),
        .pre_charge_global (global_pre_charge),
        .row_on_detect     (row_on_detect),
        .row_off_detect    (row_off_detect),
        .row_pixel_rst     (row_pixel_rst),
        
        // Data to FIFO
        .fifo_wr_en        (int_fifo_wr_en),
        .fifo_wdata        (int_fifo_wdata)
    );

    // -----------------------------------------------------------
    // 4. Synchronous FWFT FIFO & QSPI Bridge
    // -----------------------------------------------------------
    // Stores two full rows (Depth=16) and handles 136-to-16b muxing
    sync_fifo_top3 i_sync_fifo_top (
        `ifdef USE_POWER_PINS
            .vccd1(vccd1), .vssd1(vssd1),
        `endif
        .clk           (sys_clk),
        .rst_n         (rst_n),
        
        // Write side (From ROIC)
        .wr_en_fifo    (int_fifo_wr_en),
        .wdata_fifo    (int_fifo_wdata),
        .full_fifo     (int_fifo_full),
        
        // Read side (To SPI)
        .empty_fifo    (int_fifo_empty),
        .shift_en_fifo (int_shift_en),
        .rdata_spi     (int_rdata_spi),
        .numel_fifo    () // Unconnected at top level unless mapped to a status register
    );

endmodule : dvs_digital_core_top