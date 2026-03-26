`timescale 1ns/1ps
import pkg_spi_fver::*;

module spi_continuous_read_tb();

    localparam CLK_P = 10ns;

    // Global signals
    logic clk  = 0;
    logic rst_n = 0;

    // Dump variable for the data log file
    integer log_file;

    // SPI Controller Interface
    spi_intf i_spi_intf(
        .CS_N(), .SCK(), .COPI(), .CIPO()
    );
    class_spi_ctrl spi_ctrl = new (i_spi_intf);

    always #(CLK_P) clk = ~clk;

    // Monitor CIPO out to log file
    always @(negedge i_spi_intf.SCK) begin
        if (!i_spi_intf.CS_N)
            $fwrite(log_file, "%0t, %b\n", $time, i_spi_intf.CIPO);
    end

    //---------------------------------------------------
    // Internal Wires & Interconnects
    //---------------------------------------------------
    
    // SPI <---> Mem (Dummy wires to emulate RegFile)
    logic [`RF_AWIDTH-1:0] addr_reg;
    logic                  we_reg;
    logic                  we_out;
    logic [ `RF_WIDTH-1:0] wdata_reg;
    logic [  `RF_MASK-1:0] wmask_reg;
    logic [ `RF_WIDTH-1:0] rdata_reg = '0;

    // SPI <---> FIFO Interconnects
    logic [9:0] fifo_rdata_0, fifo_rdata_1, fifo_rdata_2, fifo_rdata_3;
    logic fifo_empty_0, fifo_empty_1, fifo_empty_2, fifo_empty_3;
    logic fifo_rd_en_0, fifo_rd_en_1, fifo_rd_en_2, fifo_rd_en_3;

    //---------------------------------------------------
    // DUT Instantiation: SPI Peripheral ONLY
    //---------------------------------------------------
    
    spi_peripheral2 i_spi_peripheral2 (
        .CS_N(i_spi_intf.CS_N), 
        .SCK(i_spi_intf.SCK), 
        .COPI(i_spi_intf.COPI), 
        .CIPO(i_spi_intf.CIPO),

        .addr_reg(addr_reg), .we_reg(we_reg), .we_out(we_out),
        .wdata_reg(wdata_reg), .wmask_reg(wmask_reg), .rdata_reg(rdata_reg),
        
        // Obsolete legacy ports tied off
        .rdata_spi_0(16'b0), .rdata_spi_1(16'b0), .shift_en_fifo(),

        // 4x FIFO Read Interface
        .fifo_rdata_0(fifo_rdata_0), .fifo_rdata_1(fifo_rdata_1), 
        .fifo_rdata_2(fifo_rdata_2), .fifo_rdata_3(fifo_rdata_3),
        .fifo_empty_0(fifo_empty_0), .fifo_empty_1(fifo_empty_1), 
        .fifo_empty_2(fifo_empty_2), .fifo_empty_3(fifo_empty_3),
        .fifo_rd_en_0(fifo_rd_en_0), .fifo_rd_en_1(fifo_rd_en_1), 
        .fifo_rd_en_2(fifo_rd_en_2), .fifo_rd_en_3(fifo_rd_en_3)
    );

    //---------------------------------------------------
    // MOCK FIFO LOGIC (Emulating Memory Behavior)
    //---------------------------------------------------
    logic [9:0] mock_fifo_0, mock_fifo_1, mock_fifo_2, mock_fifo_3;

    assign fifo_rdata_0 = mock_fifo_0;
    assign fifo_rdata_1 = mock_fifo_1;
    assign fifo_rdata_2 = mock_fifo_2;
    assign fifo_rdata_3 = mock_fifo_3;

    // Emulate the read pointer advancing on SCK when rd_en is pulsed
    always_ff @(posedge i_spi_intf.SCK or posedge i_spi_intf.CS_N) begin
        if (i_spi_intf.CS_N) begin
            // Distinct starting values so each channel is easily identifiable in the log
            mock_fifo_0 <= 10'h0A0; 
            mock_fifo_1 <= 10'h1B0;
            mock_fifo_2 <= 10'h2C0;
            mock_fifo_3 <= 10'h3D0;
        end else begin
            if (fifo_rd_en_0) mock_fifo_0 <= mock_fifo_0 + 1;
            if (fifo_rd_en_1) mock_fifo_1 <= mock_fifo_1 + 1;
            if (fifo_rd_en_2) mock_fifo_2 <= mock_fifo_2 + 1;
            if (fifo_rd_en_3) mock_fifo_3 <= mock_fifo_3 + 1;
        end
    end

    //---------------------------------------------------
    // Tasks and Verification Sequences
    //---------------------------------------------------

    // Custom Bit-Banged Task for 10-bit Continuous Streaming
    task automatic read_continuous_fifo_10bit(int num_words);
        $display("\nStarting Continuous SPI Read for %0d words...", num_words);
        
        i_spi_intf.CS_N = 0;
        i_spi_intf.COPI = 4'b0;
        #(CLK_P);

        // Phase 1: Shift in 8-bit Opcode (3'b111 at the end) on COPI[0]
        for (int i=0; i<8; i++) begin
            i_spi_intf.SCK = 0;
            i_spi_intf.COPI[0] = (i >= 5) ? 1'b1 : 1'b0; // Shifts in 00000111
            #(CLK_P);
            i_spi_intf.SCK = 1;
            #(CLK_P);
        end
        
        // Phase 2: Continuous Clocking for 10-bit Data Words
        // 1 Dummy Phase + `num_words` actual reads = (num_words + 1) * 10 cycles
        for (int w = 0; w < (num_words + 1); w++) begin 
            // Trigger the "Empty" flag forcefully on the 8th word to verify the 0-padding fallback
            if (w == 8) begin
                $display("   --> Forcing FIFOs to EMPTY state midway to test fallback padding...");
                fifo_empty_0 = 1; fifo_empty_1 = 1; fifo_empty_2 = 1; fifo_empty_3 = 1;
            end

            for (int b = 0; b < 10; b++) begin
                i_spi_intf.SCK = 0;
                #(CLK_P);
                i_spi_intf.SCK = 1;
                #(CLK_P);
            end
        end

        // Clean termination
        i_spi_intf.SCK = 0;
        #(CLK_P);
        i_spi_intf.CS_N = 1; 
        $display("...... Completed Continuous SPI Read ......");
    endtask

    //---------------------------------------------------
    // Main Test Sequence
    //---------------------------------------------------
    initial begin
        log_file = $fopen("spi_cipo_monitor.txt", "w");
        
        // Initialize SPI Controller Class
        spi_ctrl.init();

        // Standard Reset Sequence
        #(10*CLK_P); rst_n = 1;
        #(10*CLK_P); rst_n = 0;
        #(10*CLK_P); rst_n = 1;
        #(5*CLK_P);

        $display("Starting SPI Peripheral Unit Test...");

        // ==========================================
        // TEST 1: Standard SPI Class Memory Trans
        // ==========================================
        $display("\n--- Testing Standard SPI RegFile Trans ---");
        spi_ctrl.trans(WRITE_WD, 8, 'hAAAA_AAAA);
        #100ns;
        
        rdata_reg = 'hAAAA_AAAA; 
        spi_ctrl.trans(READ_WD, 8, 0, 'hAAAA_AAAA);
        #100ns;

        // ==========================================
        // TEST 2: Continuous 4x FIFO Read (Unit Level)
        // ==========================================
        $display("\n--- Testing Continuous FIFO Stream Pipeline ---");
        
        // Start with FIFOs full/ready
        fifo_empty_0 = 0; fifo_empty_1 = 0; fifo_empty_2 = 0; fifo_empty_3 = 0;

        // Execute a 10-word read. 
        // Note: The task is designed to force empty_flags high on the 8th word to verify logic.
        read_continuous_fifo_10bit(10);

        // spi_ctrl.trans(OPCODE, ADDR, NUM_WORDS_TO_READ);
        // spi_ctrl.trans(READ_FIFO, 0, 25); TODO: use this function

        #(20*CLK_P);
        
        $fclose(log_file);
        $stop;
    end

endmodule : spi_continuous_read_tb