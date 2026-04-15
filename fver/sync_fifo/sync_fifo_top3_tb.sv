module tb();

    // Parameters
    parameter FIFO_DWIDTH = 136;
    parameter FIFO_DEPTH  =  16;

    // Inputs
    logic clk = 0, rst_n = 0;
    logic wr_en_fifo = 0, shift_en_fifo = 0;

    logic [FIFO_DWIDTH-1:0] wdata_fifo = 0;
    logic [$clog2(FIFO_DEPTH)-1:0] numel_fifo;
    logic empty_fifo, full_fifo;
    logic [15:0] rdata_spi;

    logic [4:0] clk_cycle_cnt;  
    logic [4:0] shift_cnt;      

    // --- Self-Checking Mechanisms ---
    logic [FIFO_DWIDTH-1:0] expected_data_queue [$]; // Scoreboard Queue
    int fd; // File descriptor for the log file

    // Instantiate the sync_fifo module
    sync_fifo_top3 i_sync_fifo_top (
        .clk            (clk),
        .rst_n          (rst_n),
        .wr_en_fifo     (wr_en_fifo),
        .wdata_fifo     (wdata_fifo),
        .empty_fifo     (empty_fifo),
        .full_fifo      (full_fifo),
        .numel_fifo     (numel_fifo),
        .shift_en_fifo  (shift_en_fifo),
        .rdata_spi      (rdata_spi)
    );

    // Clock generation: 50MHz operation = 20ns period
    always #10 clk = ~clk;

    // --------------------- Test Sequence ------------------------------
    initial begin
        // Open the log file
        fd = $fopen("fifo_verification.txt", "w");
        if (fd) $display("Successfully opened fifo_verification.txt for logging.");
        else    $display("ERROR: Could not open file!");

        $fdisplay(fd, "==================================================");
        $fdisplay(fd, " FWFT FIFO & Q-SPI RECONSTRUCTION VERIFICATION LOG");
        $fdisplay(fd, "==================================================\n");

        $display("Starting FIFO testbench...");

        // Reset FIFO
        rst_n = 0;
        wr_en_fifo = 0;
        shift_en_fifo = 0;
        clk_cycle_cnt = 0;
        shift_cnt = 0;

        #30;
        rst_n = 1;
        #20;

        // 1. Fill the FIFO completely with random data
        $display("\n--- FILLING FIFO ---");
        write_data(FIFO_DEPTH);
        
        // 2. Read back a few rows and verify
        $display("\n--- READING AND VERIFYING DATA ---");
        // @(posedge clk); // Give FSM 1 cycle to exit IDLE
        read_row_data();
        read_row_data();

        // 3. Write a few more to test wrap-around/pointer safety
        $display("\n--- PARTIAL FILL ---");
        write_data(3);

        // 4. Drain the rest of the FIFO
        $display("\n--- DRAINING REMAINING FIFO ---");
        while (!empty_fifo) begin
            read_row_data();
        end

        $display("\n==================================================");
        $display("TEST COMPLETE. Check fifo_verification.txt for results.");
        $display("==================================================");
        $fdisplay(fd, "\n==================================================");
        $fdisplay(fd, "END OF LOG.");
        $fclose(fd);
        $finish;
    end

    // -----------------------------------------------------------------
    // Task: Write randomized data and store in queue
    // -----------------------------------------------------------------
    task automatic write_data(int num = 15); 
        for (int i = 0; i < num; i++) begin
            @(posedge clk);
            #1; // Ensure we are past the clock edge
            
            wr_en_fifo = 1;
            // Generate 136 bits of random data (concatenating 32-bit randoms)
            // wdata_fifo = {2'b00,6'(i), 32'hAAAA_AAAA, 32'hAAAA_AAAA, 32'hAAAA_AAAA, 32'hAAAA_AAAA};
            wdata_fifo = {2'b00, 6'(i), {4{32'hAAAA_AAAA}}};
            
            // Push to our checking queue
            expected_data_queue.push_back(wdata_fifo);
            
            // Log to terminal and file
            $display("WRITE [%0d] : %h", i, wdata_fifo);
            $fdisplay(fd, "WRITE : %h", wdata_fifo);

            @(posedge clk);
            #1;
            wr_en_fifo = 0;
        end
    endtask

    // -----------------------------------------------------------------
    // Task: The physical SPI shift sequence (Captures the 16-bit word)
    // -----------------------------------------------------------------
    task automatic shifting_sequence(output logic [15:0] captured_spi);
        // 6 cycles low
        for (int j = 0; j < 6; j++) begin
            @(posedge clk);
            #1;
            clk_cycle_cnt = j[4:0];
            shift_en_fifo = 0;
            
            // Capture the data right before the shift_en goes high 
            // (Simulating SPI Setup/Hold timing)
            if (j == 5) captured_spi = rdata_spi;
        end
        
        // 1 cycle high (shift)
        @(posedge clk);
        #1;
        clk_cycle_cnt = clk_cycle_cnt + 1;
        shift_en_fifo = 1;
        shift_cnt = shift_cnt + 1;
        
        // 1 cycle low (interleaved, next row data setup)
        @(posedge clk);
        #1;
        clk_cycle_cnt = clk_cycle_cnt + 1;
        shift_en_fifo = 0; 
    endtask


    task automatic read_row_data();
        logic [135:0] expected_word;
        logic [135:0] reconstructed_word;
        logic [15:0]  spi_chunk;

        // Independent 64-bit Data Buffers
        logic [63:0] data_top; // Channel A Data
        logic [63:0] data_bot; // Channel B Data
        logic [7:0]  ctrl_byte; // The singular shared control byte

        data_top  = '0;
        data_bot  = '0;
        ctrl_byte = '0;

        // 1. Transmissions 1-8: Stream LSB to MSB into the 64-bit macros
        for (int s = 0; s < 8; s++) begin
            shifting_sequence(spi_chunk);
            
            data_top[(s*8) +: 8] = spi_chunk[15:8]; // Channel A
            data_bot[(s*8) +: 8] = spi_chunk[7:0];  // Channel B
        end

        // 2. Transmission 9: Capture the singular Control Byte
        // Since both channels broadcast the same byte, we only need to sample one.
        shifting_sequence(spi_chunk);
        ctrl_byte = spi_chunk[15:8]; 

        // 3. Reconstruct the 136-bit word exactly how it sits in the FIFO
        // Format: {Control[135:128], TopData[127:64], BotData[63:0]}
        reconstructed_word = {ctrl_byte, data_top, data_bot};

        // --- The Verification ---
        if (expected_data_queue.size() > 0) begin
            expected_word = expected_data_queue.pop_front();
            
            if (reconstructed_word === expected_word) begin
                $display("READ  [PASS] : %h", reconstructed_word);
                $fdisplay(fd, "READ  [PASS] : %h", reconstructed_word);
            end else begin
                $display("READ  [FAIL] : EXP: %h | ACT: %h", expected_word, reconstructed_word);
                $fdisplay(fd, "READ  [FAIL] : EXPECTED : %h", expected_word);
                $fdisplay(fd, "               ACTUAL   : %h", reconstructed_word);
                $stop; 
            end
        end else begin
            $display("[WARNING] Read executed but expected queue is empty!");
            $fdisplay(fd, "[WARNING] Read executed but expected queue is empty!");
        end
    endtask

endmodule : tb