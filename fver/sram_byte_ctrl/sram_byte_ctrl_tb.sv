//---------------------------------------------------------------------------
// Author: Kwesi Buabeng Debrah
// Date  : Apr 8, 2025
//
// Module: sram_byte_ctrl_tb
//
// Description: 
//  Testbench for the SRAM Controller.
//---------------------------------------------------------------------------


module sram_byte_ctrl_tb ();

    localparam WIDTH = 64;
    localparam DEPTH = 4;
    localparam AWIDTH = $clog2(DEPTH * (WIDTH/8));

    // Inputs
    logic [              1:0] size_a   = 0;
    logic [              1:0] size_b   = 0;
    logic [       AWIDTH-1:0] addr_a_i = 0;
    logic [       AWIDTH-1:0] addr_b_i = 0;
    // Outputs
    logic [$clog2(DEPTH)-1:0] addr_a_o;
    logic [$clog2(DEPTH)-1:0] addr_b_o;
    logic [    (WIDTH/8)-1:0] wmask_a ;
    logic [    (WIDTH/8)-1:0] wmask_b ;


    // Instantiate the SRAM memory module
    sram_byte_ctrl #(WIDTH, DEPTH) i_ctrl (
        .addr_a_i,
        .addr_b_i,
        .addr_a_o,
        .addr_b_o,
        .wmask_a,
        .wmask_b
    );


    // Testbench
    initial begin

        // Test 0: Byte access
        test_random_address(0);

        // Test 1: Halfword access
        test_random_address(1);

        // Test 2: Word access
        test_random_address(2);

        // Test 3: Doubleword access
        test_random_address(3);

        #5 $stop;
    end


    task automatic test_random_address(logic [1:0] size = '0);
        $display("");
        
        for (int i = 0; i < 10; i++) begin
            // Set the size and address inputs
            addr_a_i = $urandom_range(0, 2**AWIDTH - 1);;
            addr_b_i = $urandom_range(0, 2**AWIDTH - 1);;
    
            #5;
    
            // Check the outputs
            assert(addr_a_o == addr_a_i[$size(addr_a_i)-1:3]) else $error("Random address test failed: addr_a_o mismatch");
            assert(addr_b_o == addr_b_i[$size(addr_b_i)-1:3]) else $error("Random address test failed: addr_b_o mismatch");

            // Check for 0 mask for invalid addresses
            if (
                size == 1 && addr_a_i[0] !== 0 ||
                size == 2 && addr_a_i[1:0] !== 0 ||
                size == 3 && addr_a_i[2:0] !== 0
            ) begin
                
                $display("[INVALID ADDRESS] addr_a_i: %3d, size: %2d, mask: %8b", addr_a_i, size, wmask_a);
                assert (wmask_a == 0) else begin
                    $display("\n[ERROR] size: %2d, addr_a_i: %3d, wmask_a: %8b", size, addr_a_i, wmask_a);
                    $error("Invalid address: wmask_a mismatch");
                end
            
            end 
            else begin
                assert(wmask_a == (size == 'b00 ? 8'b00000001 << (addr_a_i[2:0]) :
                                    size == 'b01 ? 8'b00000011 << (addr_a_i[2:0]) :
                                    size == 'b10 ? 8'b00001111 << (addr_a_i[2:0]) :
                                    8'b11111111)) else begin
                                        $display("\n[ERROR] size: %2d, addr_a_i: %3d, wmask_a: %8b", size, addr_a_i, wmask_a);
                                        $error("Random address test failed: wmask_a mismatch");
                                    end
            end

            // Check for 0 mask for invalid addresses
            if (
                size == 1 && addr_b_i[0] !== 0 ||
                size == 2 && addr_b_i[1:0] !== 0 ||
                size == 3 && addr_b_i[2:0] !== 0
            ) begin
                
                $display("[INVALID ADDRESS] addr_b_i: %3d, size: %2d, mask: %8b", addr_b_i, size, wmask_b);
                assert (wmask_b == 0) else begin
                    $display("\n[ERROR] size: %2d, addr_b_i: %3d, wmask_b: %8b", size, addr_b_i, wmask_b);
                    $error("Invalid address: wmask_b mismatch");
                end

            end 
            else begin
                assert(wmask_b == (size == 'b00 ? 8'b00000001 << (addr_b_i[2:0]) :
                                size == 'b01 ? 8'b00000011 << (addr_b_i[2:0]) :
                                size == 'b10 ? 8'b00001111 << (addr_b_i[2:0]) :
                                8'b11111111)) else begin
                                    $display("\n[ERROR] size: %2d, addr_b_i: %3d, wmask_b: %8b", size, addr_b_i, wmask_b);
                                    $error("Random address test failed: wmask_b mismatch");
                                end 
            end
            
        end

    endtask : test_random_address


endmodule : sram_byte_ctrl_tb
