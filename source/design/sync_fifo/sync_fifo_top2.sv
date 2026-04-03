//---------------------------------------------------------------------------
// Module: sync_fifo_top
// Description: 
//  Top-level wrapper for the Synchronous Event-Based Readout Pipeline.
//  Integrates the FWFT Synchronous FIFO with the Zero-Mux Pre-Fetch SPI Interface.
//---------------------------------------------------------------------------

module sync_fifo_top2 (
    `ifdef USE_POWER_PINS
        inout vccd1, // OpenLane Power  
        inout vssd1, // OpenLane Ground 
    `endif

    input  logic                   clk,
    input  logic                   rst_n,

    // ==========================================
    // WRITE SIDE (From Imager Arrays & ROIC SM)
    // ==========================================
    input  logic                   wr_en_fifo,
    input  logic [63:0]            wdata_0,      // 64 bits (Tile 1 Data)
    input  logic [63:0]            wdata_1,      // 64 bits (Tile 2 Data)
    input  logic [5:0]             wrow_addr,    // 6 bits  (Row Address from roic_sm)

    // FIFO Status Flags (To ROIC or MCU)
    output logic                   empty_fifo,
    output logic                   full_fifo,
    output logic [`FIFO_AWIDTH-1:0] numel_fifo,

    // ==========================================
    // READ SIDE (From SPI Master / MCU)
    // ==========================================
    input  logic                   shift_en_fifo, // Pulled high by SPI SCK edge
    output logic [15:0]            rdata_spi      // Zero-Depth output to CIPO
);

    // Internal inter-module wiring
    logic                   fifo_rd_en_next;
    logic [`FIFO_WIDTH-1:0] rdata_fifo_bus;
    
    // Explicitly named wires for the unpacked read data
    logic [63:0]            rdata_0_out;
    logic [63:0]            rdata_1_out;
    logic [5:0]             row_addr_out;

// -----------------------------------------------------------------
    // DATA PACKING / UNPACKING
    // FIFO_WIDTH is explicitly 136 bits.
    // wdata_1 (64) + wdata_0 (64) + pad (2) + wrow_addr (6) = 136 bits
    // -----------------------------------------------------------------
    logic [`FIFO_WIDTH-1:0] wdata_packed;
    
    // 1. PACKING (Inputs -> FIFO)
    assign wdata_packed = {wdata_1, wdata_0, 2'b00, wrow_addr};
    
    // 2. UNPACKING (FIFO -> Outputs)
    // We create a 2-bit dummy wire to "catch" the padding during extraction.
    // The concatenation goes on the LEFT side to extract wires from the bus.
    logic [1:0] dummy_pad;
    assign {rdata_1_out, rdata_0_out, dummy_pad, row_addr_out} = rdata_fifo_bus;
    
    // -----------------------------------------------------------------
    // MODULE: SYNCHRONOUS FIFO (FWFT)
    // -----------------------------------------------------------------
    sync_fifo i_sync_fifo (
        `ifdef USE_POWER_PINS
            .vccd1(vccd1),  
            .vssd1(vssd1),  
        `endif
        .clk        (clk),
        .rst_n      (rst_n),
        .wr_en      (wr_en_fifo),       // Triggered by roic_sm
        .rd_en      (fifo_rd_en_next),  // Triggered by fifo_intf2 on the 8th shift
        .wdata      (wdata_packed),     // 134-bit packed input
        .empty      (empty_fifo),       
        .full       (full_fifo),        
        .numel      (numel_fifo),       
        .rdata      (rdata_fifo_bus)    // FWFT 134-bit continuous output
    );

    // -----------------------------------------------------------------
    // MODULE: TIMING-OPTIMIZED SPI INTERFACE
    // -----------------------------------------------------------------
    fifo_intf2 i_fifo_intf2 (
        `ifdef USE_POWER_PINS
            .vccd1(vccd1),  
            .vssd1(vssd1),  
        `endif
        .clk             (clk),
        .rst_n           (rst_n),
        
        // Unpacked FWFT Data from the FIFO
        .rdata_0         (rdata_0_out),
        .rdata_1         (rdata_1_out),
        .row_addr        (row_addr_out),
        .empty_fifo      (empty_fifo),    // Gating signal for safe pre-fetching
        
        // SPI Control & Output
        .shift_en        (shift_en_fifo), 
        .rdata_spi       (rdata_spi),     // Routed directly to ASIC pad
        .fifo_rd_en_next (fifo_rd_en_next)
    );

endmodule : sync_fifo_top2