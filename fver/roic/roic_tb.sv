//---------------------------------------------------------------------------
// Module: sync_fifo_tb
// Description: 
//  Testbench for the 134-bit FWFT Synchronous FIFO & Zero-Mux SPI pipeline.
//---------------------------------------------------------------------------

module tb();

    // Parameters
    parameter FIFO_DEPTH  = 16;
    parameter FIFO_AWIDTH = $clog2(FIFO_DEPTH);

    // Inputs (System Clock & Reset)
    logic clk = 0;
    logic rst_n = 0;

    // Write Side (Imager Arrays & ROIC)
    logic        wr_en_fifo = 0;
    logic [63:0] wdata_0 = 0;
    logic [63:0] wdata_1 = 0;
    logic [5:0]  wrow_addr = 0;

    // Read Side (SPI)
    logic        shift_en_fifo = 0;
    logic [15:0] rdata_spi;

    // Status Flags
    logic [FIFO_AWIDTH:0] numel_fifo; // Note: Usually AWIDTH+1 to represent fully full
    logic empty_fifo;
    logic full_fifo;

    // Counters for the shifting sequence
    logic [4:0] clk_cycle_cnt = 0;  
    logic [4:0] shift_cnt = 0;      

    // Instantiate the NEW sync_fifo_top
    sync_fifo_top2 i_sync_fifo_top (
        .clk            (clk),
        .rst_n          (rst_n),
        .wr_en_fifo     (wr_en_fifo),
        .wdata_0        (wdata_0),
        .wdata_1        (wdata_1),
        .wrow_addr      (wrow_addr),
        .empty_fifo     (empty_fifo),
        .full_fifo      (full_fifo),
        .numel_fifo     (numel_fifo),
        .shift_en_fifo  (shift_en_fifo),
        .rdata_spi      (rdata_spi)
    );

    // Clock generation: 50MHz operation = 20ns period
    always begin
        #10 clk = ~clk;
    end

    // --------------------- Test Sequence ------------------------------
    initial begin
        $display("========================================");
        $display("Starting Synchronous FIFO Testbench...");
        $display("========================================");

        // Reset Sequence
        rst_n = 0;
        wr_en_fifo = 0;
        shift_en_fifo = 0;
        clk_cycle_cnt = 0;
        shift_cnt = 0;

        #25; // Hold reset 
        rst_n = 1;
        #15;

        // Verify initial flags
        $display("[INIT] Empty flag = %b", empty_fifo);
        $display("[INIT] Full flag  = %b", full_fifo);

        // -------------------------------------------------------------
        // TEST 1: Fill the FIFO entirely, then read 2 rows
        // -------------------------------------------------------------
        write_data(FIFO_DEPTH);
        $display("[TEST 1] Full flag after write = %b", full_fifo);
        
        $display("\n--- Reading Row 1 ---");
        read_row_data();
        
        #20;
        
        $display("\n--- Reading Row 2 ---");
        read_row_data();

        #40;
        $display("[TEST 1 END] Full flag = %b", full_fifo);
        
        // -------------------------------------------------------------
        // TEST 2: Drain the rest of the FIFO
        // -------------------------------------------------------------
        read_full_depth();

        $display("[TEST 2 END] Empty flag = %b", empty_fifo);
        $display("[TEST 2 END] Full flag  = %b", full_fifo);

        #40;

        // -------------------------------------------------------------
        // TEST 3: Short Burst Write & Read
        // -------------------------------------------------------------
        $display("\n========================================");
        $display("TEST 3: Writing 5 rows, then draining...");
        write_data(5);

        $display("[TEST 3] Full flag = %b", full_fifo);
        read_full_depth();
        $display("[TEST 3 END] Empty flag = %b", empty_fifo);

        #40;

        // -------------------------------------------------------------
        // TEST 4: Single Row Write/Read Verification
        // -------------------------------------------------------------
        $display("\n========================================");
        $display("TEST 4: Single Row Write & Read");
        write_data(1);

        $display("[TEST 4] Full flag = %b", full_fifo);
        
        #20;
        read_full_depth();
        
        #40;
        $display("========================================");
        $display("Simulation Complete.");
        $display("========================================");
        $finish;
    end

    // -----------------------------------------------------------------
    // TASKS
    // -----------------------------------------------------------------

    task automatic write_data(int num = 1);
        $display("\nWriting %0d rows to the FIFO...", num);

        wr_en_fifo = 0;

        for (int i = 0; i < num; i++) begin
            @(posedge clk);
            // #2ns; // Shifted input assignment slightly after clock edge
            
            wr_en_fifo = 1;
            
            // Assign explicitly broken-out data buses
            // Using clear hex patterns to make the waveforms readable
            wdata_1   = {32'hBBBB_0000 + i, 32'hAAAA_0000 + i}; // Tile 1
            wdata_0   = {32'hDDDD_0000 + i, 32'hCCCC_0000 + i}; // Tile 2
            wrow_addr = i[5:0];                                 // Row Address
            
            $display("  [WRITE] Row %0d | Addr: %0h | T1: %h | T2: %h", i, wrow_addr, wdata_1[31:0], wdata_0[31:0]);

            @(posedge clk);
            // #2ns;
            wr_en_fifo = 0;
        end
    endtask : write_data

    task automatic read_full_depth();
        $display("\nDraining the FIFO...");
        shift_en_fifo = 0;

        // Using the empty_fifo flag from the top-level to auto-drain
        while (!empty_fifo) begin
            read_row_data();
            #20ns; // Tiny gap between row reads
        end
        $display("FIFO completely drained.");
    endtask : read_full_depth

    task automatic shifting_sequence(); 
        // 6 cycles low (simulating MCU processing/SPI divider)
        for (int j = 0; j < 6; j++) begin
            @(posedge clk);
            // #2ns;
            clk_cycle_cnt = j[4:0];
            shift_en_fifo = 0;
        end
        
        // 1 cycle high (shift trigger)
        @(posedge clk);
        // #2ns;
        clk_cycle_cnt = clk_cycle_cnt + 1;
        shift_en_fifo = 1;
        shift_cnt = shift_cnt + 1;
        
        // Let the shift process on the posedge, capture output on negedge
        @(negedge clk);
        $display("    [SHIFT %0d] SPI Output = %h", shift_cnt, rdata_spi);

        // Deassert
        @(posedge clk);
        // #2ns;
        clk_cycle_cnt = clk_cycle_cnt + 1;
        shift_en_fifo = 0;  
    endtask : shifting_sequence

    task automatic read_row_data();
        shift_cnt = 0;
        // For 9 shifts (8 data words + 1 padded address word)
        for (int s = 0; s < 9; s++) begin
            shifting_sequence();
        end
        $display("  -> Row Read Complete.");
    endtask : read_row_data

endmodule : tb