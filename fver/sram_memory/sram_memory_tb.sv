//---------------------------------------------------------------------------
// Author: Kwesi Buabeng Debrah
// Date  : Apr 2, 2025
//
// Module: sram_memory_tb
//
// Description: 
//  Testbench for the dual-port SRAM memory.
//---------------------------------------------------------------------------


module sram_memory_tb ();

    localparam WIDTH = 16;
    localparam DEPTH = 16;

    // Inputs
    logic                     clk     = 0;
    logic                     ce_a    = 0;
    logic                     ce_b    = 0;
    logic [$clog2(DEPTH)-1:0] addr_a  = 0;
    logic [$clog2(DEPTH)-1:0] addr_b  = 0;
    logic                     we_a    = 0;
    logic                     we_b    = 0;
    logic [    (WIDTH/8)-1:0] wmask_a = 0;
    logic [    (WIDTH/8)-1:0] wmask_b = 0;
    logic [        WIDTH-1:0] wdata_a = 0;
    // Outputs
    logic [        WIDTH-1:0] rdata_b;

    logic [WIDTH-1:0] mem [DEPTH];


    // Instantiate the SRAM memory module
    sram_memory #(WIDTH, DEPTH) i_sram (
        .clk    (clk    ),
        .ce_a   (ce_a   ),
        .ce_b   (ce_b   ),
        .addr_a (addr_a ),
        .addr_b (addr_b ),
        .we_a   (we_a   ),
        .we_b   (we_b   ),
        .wmask_a(wmask_a),
        .wmask_b(wmask_b),
        .wdata_a(wdata_a),
        .wdata_b('0     ),
        .rdata_a(       ),
        .rdata_b(rdata_b)
    );


    // Clock generation
    always begin
        #5 clk = !clk;
    end


    // Testbench
    initial begin
        #10;

        // Write data to the memory
        write_data(.mask('b11));

        #30;

        // Read data from the memory
        read_data();
        
        #20;
        $stop;
    end


    task automatic write_data(logic [(WIDTH/8)-1:0] mask);
        logic [WIDTH-1:0] data = '0;
        ce_a = 0;
        we_a = 0;

        for (int i = 0; i < DEPTH; i++) begin
            foreach(mask[j]) begin
                if (mask[j]) begin
                    data[j*8+:8] = $urandom_range(0, 2**8 - 1);
                    mem[i][j*8+:8] = data[j*8+:8];
                end
            end

            @(posedge clk);
            #0.1ns;
            ce_a    = 1;
            we_a    = 1;
            addr_a  = i;
            wmask_a = mask;
            wdata_a = data;
            
            $display("\nWriting to address %0d: %0h", addr_a, wdata_a);

            @(posedge clk);
            #0.1ns;
            ce_a = 0;
            we_a = 0;
        end

        @(posedge clk);
        ce_a = 0;
        we_a = 0;
    endtask : write_data


    task automatic read_data();
        int errors = 0;

        ce_b = 0;
        we_b = 1;

        for (int i = 0; i < DEPTH; i++) begin
            @(posedge clk);
            #0.1ns;
            ce_b   = 1;
            we_b   = 0;
            addr_b = i;

            // Wait for the read data to be valid
            @(posedge clk);
            #0.1ns;
            ce_b = 0;
            we_b = 1;
            $display("\nReading from address %0d: %0h", addr_b, rdata_b);

            if (rdata_b !== mem[i]) begin
                $display("\t[ERROR] Expected %0h, got %0h", mem[i], rdata_b);
                errors++;
            end
        end

        @(posedge clk);
        ce_b = 0;
        we_b = 0;
    endtask : read_data

endmodule : sram_memory_tb
