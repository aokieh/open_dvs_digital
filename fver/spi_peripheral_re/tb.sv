`timescale 1ns/1ps

import pkg_spi_fver::*;

module tb ();

    localparam CLK_P = 5ns;
    localparam DEPTH = 8;

    logic clk  = 0;
    logic rst_n = 0;

    // SPI Interface
    logic CS_N;
    logic SCK;
    logic [3:0] COPI;
    logic [3:0] CIPO;

    spi_intf i_spi_intf(
        .CS_N(CS_N),
        .SCK (SCK ),
        .COPI(COPI),
        .CIPO(CIPO)
    );

    class_spi_ctrl spi_ctrl = new (i_spi_intf);

    // Memory Interface
    logic                  we_reg;
    logic [`RF_AWIDTH-1:0] addr_reg;
    logic [ `RF_WIDTH-1:0] wdata_reg;
    logic [  `RF_MASK-1:0] wmask_reg;
    logic [ `RF_WIDTH-1:0] rdata_reg;

    // FIFO / Streaming Interfaces
    logic [15:0]        rdata_spi_0, rdata_spi_1;
    logic [1:0]         shift_en_fifo;
    logic               data_ready_spi;

    always #(CLK_P/2) clk = ~clk;

    spi_peripheral i_spi_peripheral (
        .CS_N,
        .SCK,
        
        //SPI interface
        .COPI,
        .CIPO,
        
        //Memory interface
        .addr_reg,
        .we_reg,
        .wdata_reg,
        .wmask_reg,
        .rdata_reg,

        //FIFO interface
        .shift_en_fifo,
        .rdata_spi_0,
        .rdata_spi_1,
        
        // Continuous Read
        .data_ready_spi
    );

    // =========================================================================
    // Backend Dummy Memory & FIFO Model
    // =========================================================================
    logic [31:0] dummy_mem [0:255]; // Generic backend memory

    // Synchronous Write with byte-masking
    always_ff @(posedge clk) begin
        if (we_reg) begin
            if (wmask_reg[0]) dummy_mem[addr_reg][7:0]   <= wdata_reg[7:0];
            if (wmask_reg[1]) dummy_mem[addr_reg][15:8]  <= wdata_reg[15:8];
            if (wmask_reg[2]) dummy_mem[addr_reg][23:16] <= wdata_reg[23:16];
            if (wmask_reg[3]) dummy_mem[addr_reg][31:24] <= wdata_reg[31:24];
        end
    end

    // Combinational Read
    assign rdata_reg = dummy_mem[addr_reg];

    // Mock FIFO Data
    assign data_ready_spi = 1'b1;   // Always ready for testing
    assign rdata_spi_0    = 16'h1234;
    assign rdata_spi_1    = 16'h5678;

    // =========================================================================
    // Test Sequence
    // =========================================================================
    initial begin
        // 1. Initialization
        $display("-----------------------------------------");
        $display("[TB] Starting Q-SPI Transaction Tests...");
        $display("-----------------------------------------");
        spi_ctrl.init();
        #100ns;

        // 2. Full Word (32-bit) Read/Write Test
        $display("[TB] Testing WRITE_WD / READ_WD at 0x04");
        // trans(operation, address, write_data, expected_read_data)
        spi_ctrl.trans(WRITE_WD, 8'h04, 32'hDEADBEEF);
        #50ns;
        spi_ctrl.trans(READ_WD,  8'h04, 32'h0, 32'hDEADBEEF); 
        #50ns;

        // 3. Half Word (16-bit) Read/Write Test
        $display("[TB] Testing WRITE_HW / READ_HW at 0x08");
        spi_ctrl.trans(WRITE_HW, 8'h08, 32'h0000CAFE);
        #50ns;
        spi_ctrl.trans(READ_HW,  8'h08, 32'h0, 32'h0000CAFE);
        #50ns;

        // 4. Byte (8-bit) Read/Write Test
        $display("[TB] Testing WRITE_BT / READ_BT at 0x0C");
        spi_ctrl.trans(WRITE_BT, 8'h0C, 32'h00000042);
        #50ns;
        spi_ctrl.trans(READ_BT,  8'h0C, 32'h0, 32'h00000042);
        #50ns;

        // 5. FIFO Streaming Read Test
        $display("[TB] Testing READ_FIFO");
        // The peripheral combines {rdata_spi_1, rdata_spi_0} into a 32-bit word
        // Since we mocked them as 16'h5678 and 16'h1234, we expect 32'h56781234
        spi_ctrl.trans(READ_FIFO, 8'h00, 32'h0, 32'h56781234);
        #50ns;

        $display("-----------------------------------------");
        $display("[TB] All Transactions Completed!");
        $display("-----------------------------------------");
        $finish;
    end

endmodule : tb