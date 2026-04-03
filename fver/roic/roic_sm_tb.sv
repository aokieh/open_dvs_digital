// `timescale 1ns/1ps

// module roic_sm_tb();

//     parameter DIV_CLK_PERIOD_NS = 1000; 

//     // DUT Signals
//     logic       div_clk = 0;
//     logic       rst_n = 0;
//     logic       sm_enable = 0;

//     logic       pre_charge_global;
//     logic       on_detect;
//     logic       off_detect;
//     logic       pixel_rst;
//     logic       sm_next_row;
//     logic [5:0] row_addr;

//     // DUT Instantiation
//     roic_sm i_roic_sm (
//         .div_clk           (div_clk),
//         .rst_n             (rst_n),
//         .sm_enable         (sm_enable),
//         .pre_charge_global (pre_charge_global),
//         .on_detect         (on_detect),
//         .off_detect        (off_detect),
//         .pixel_rst         (pixel_rst),
//         .sm_next_row       (sm_next_row),
//         .row_addr          (row_addr)
//     );

//     // Clock Generation
//     always begin
//         #(DIV_CLK_PERIOD_NS / 2) div_clk = ~div_clk;
//     end

//     // Main Test Sequence
//     initial begin
//         $display("==================================================");
//         $display("Starting Phase-Gated 3-State ROIC TB...");
//         $display("==================================================");

//         // 1. Reset Sequence
//         rst_n = 0;
//         sm_enable = 0;
//         #100;
//         rst_n = 1;
//         $display("[INIT] Reset de-asserted. Hardware alive.");

//         // -------------------------------------------------------------
//         $display("\n--- TEST 1: Disabled State ---");
//         @(posedge div_clk);
//         check_outputs(0, 0, 0, 0, 0, 6'd0, "Disabled State (High Phase)");
//         @(negedge div_clk);
//         check_outputs(1, 0, 0, 0, 0, 6'd0, "Disabled State (Low Phase)");
//         $display("  -> [PASS] FSM safely clamps array when disabled.");

//         // -------------------------------------------------------------
//         $display("\n--- TEST 2: Single Row Sequence (Row 0) ---");
//         @(negedge div_clk); // Wait for the safe pre-charge phase
//         #1;                 // Step past the clock edge to avoid race conditions
//         sm_enable = 1;      // Enable FSM cleanly
        
//         // The very next posedge begins Cycle 1
//         verify_phase_gated_sequence(6'd0, 1'b0);
//         $display("  -> [PASS] Phase-gated ON -> OFF -> RST sequence executed.");

//         // -------------------------------------------------------------
//         $display("\n--- TEST 3: Full Frame Sweep & Wrap-Around ---");
//         for (int i = 1; i < 64; i++) begin
//             verify_phase_gated_sequence(i[5:0], 1'b1);
//         end
//         $display("  -> [PASS] Successfully swept all 64 rows with negedge safety.");
        
//         verify_phase_gated_sequence(6'd0, 1'b1);
//         $display("  -> [PASS] Row counter wrapped perfectly back to Row 0.");

//         // // -------------------------------------------------------------
//         // $display("\n--- TEST 4: Mid-Cycle Disable Recovery ---");
//         // @(posedge div_clk); 
//         // check_outputs(0, 1, 0, 0, 1, 6'd1, "Row 1 ON_DETECT (High Phase)");
        
//         // #(DIV_CLK_PERIOD_NS / 4);
//         // sm_enable = 0;
        
//         // @(negedge div_clk);
//         // check_outputs(1, 0, 0, 0, 0, 6'd1, "Mid-Cycle Abort (Low Phase Safety)");
        
//         // @(posedge div_clk);
//         // check_outputs(0, 0, 0, 0, 0, 6'd1, "Mid-Cycle Abort (High Phase Recovery)");
//         // $display("  -> [PASS] FSM instantly zeroes outputs when disabled.");

//         // $display("\n==================================================");
//         // $display("All Phase-Gated Timing Checks PASSED perfectly!");
//         // $display("Simulation Complete.");
//         // $display("==================================================");

//         // -------------------------------------------------------------
// // -------------------------------------------------------------
//         $display("\n--- TEST 4: True Freeze (Pause & Resume) ---");
        
//         // Enter Row 1 ON_DETECT High Phase
//         @(posedge div_clk); 
//         check_outputs(0, 1, 0, 0, 1, 6'd1, "Row 1 ON_DETECT (High Phase)");
        
//         // Pause the system mid-cycle
//         #(DIV_CLK_PERIOD_NS / 4);
//         sm_enable = 0; 
        
//         // Negedge 1: FSM safely pre-charges, state & next_row trigger are FROZEN
//         @(negedge div_clk);
//         check_outputs(1, 0, 0, 0, 1, 6'd1, "Mid-Cycle Freeze (Low Phase Safety)"); // NXT stays 1
        
//         // Posedge 2: Because it is paused, the High Phase outputs NOTHING (array is quiet)
//         @(posedge div_clk);
//         check_outputs(0, 0, 0, 0, 1, 6'd1, "Frozen State (High Phase Quiet)"); // NXT stays 1
        
//         // Negedge 2: Still frozen, safe pre-charge
//         @(negedge div_clk);
//         check_outputs(1, 0, 0, 0, 1, 6'd1, "Frozen State (Low Phase Safety)"); // NXT stays 1

//         // Unpause the system before the next posedge!
//         sm_enable = 1;

//         // Posedge 3: FSM resumes EXACTLY where it left off (completing ON_DETECT)
//         @(posedge div_clk);
//         check_outputs(0, 1, 0, 0, 1, 6'd1, "Row 1 ON_DETECT (Resumed High Phase)");

//         // Negedge 3: FSM successfully transitions to OFF_DETECT safely (NXT finally clears)
//         @(negedge div_clk);
//         check_outputs(1, 0, 0, 0, 0, 6'd1, "Row 1 ON_DETECT (Resumed Low Phase)");

//         // Posedge 4: Proof that the FSM properly shifted to the next state
//         @(posedge div_clk);
//         check_outputs(0, 0, 1, 0, 0, 6'd1, "Row 1 OFF_DETECT (Sequence Continued)");

//         $display("  -> [PASS] FSM successfully froze, held state, and resumed cleanly.");
//         $finish;
//     end

//     // -----------------------------------------------------------------
//     // HELPER TASKS 
//     // -----------------------------------------------------------------
// // Task 1: Verifies the 3-cycle pulse train on BOTH phases of the clock
//     logic [5:0] next_r;
//     task automatic verify_phase_gated_sequence(input logic [5:0] expected_row, input logic expected_nxt);
        
//         // --- CYCLE 1: ON_DETECT ---
//         @(posedge div_clk);
//         check_outputs(0, 1, 0, 0, expected_nxt, expected_row, $sformatf("Row %0d ON_DETECT (Eval)", expected_row));
//         @(negedge div_clk);
//         // Negedge: state transitions to OFF, NXT clears to 0 immediately
//         check_outputs(1, 0, 0, 0, 0, expected_row, $sformatf("Row %0d ON_DETECT (PreCharge)", expected_row));

//         // --- CYCLE 2: OFF_DETECT ---
//         @(posedge div_clk);
//         check_outputs(0, 0, 1, 0, 0, expected_row, $sformatf("Row %0d OFF_DETECT (Eval)", expected_row));
//         @(negedge div_clk);
//         check_outputs(1, 0, 0, 0, 0, expected_row, $sformatf("Row %0d OFF_DETECT (PreCharge)", expected_row));

//         // --- CYCLE 3: PIXEL_RST ---
//         @(posedge div_clk);
//         check_outputs(0, 0, 0, 1, 0, expected_row, $sformatf("Row %0d PIXEL_RST (Eval)", expected_row));
//         @(negedge div_clk);
        
//         // Negedge: The FSM eager-loads the next row address and arms the shift trigger (NXT=1)
//         // to give the scanner maximum setup time before the next posedge.
//         // logic [5:0] next_r;
//         next_r = (expected_row == 6'd63) ? 6'd0 : expected_row + 6'd1;
//         check_outputs(1, 0, 0, 0, 1, next_r, $sformatf("Row %0d PIXEL_RST (PreCharge)", expected_row));

//     endtask

//     task automatic check_outputs(
//         input logic exp_pre,
//         input logic exp_on, 
//         input logic exp_off, 
//         input logic exp_rst, 
//         input logic exp_next,
//         input logic [5:0] exp_row, 
//         input string phase
//     );
//         #1; 
//         if (pre_charge_global !== exp_pre || on_detect !== exp_on || off_detect !== exp_off || 
//             pixel_rst !== exp_rst || sm_next_row !== exp_next || row_addr !== exp_row) begin
//             $display("\n[FATAL ERROR] Logic failure during %s!", phase);
//             $display("  Expected: PRE=%b, ON=%b, OFF=%b, RST=%b, NXT=%b, ROW=%0d", exp_pre, exp_on, exp_off, exp_rst, exp_next, exp_row);
//             $display("  Actual  : PRE=%b, ON=%b, OFF=%b, RST=%b, NXT=%b, ROW=%0d", pre_charge_global, on_detect, off_detect, pixel_rst, sm_next_row, row_addr);
//             $stop;
//         end
//     endtask

// endmodule : roic_sm_tb

`timescale 1ns/1ps

module roic_sm_tb();

    parameter DIV_CLK_PERIOD_NS = 1000; 

    // DUT Signals
    logic       div_clk = 0;
    logic       rst_n = 0;
    logic       sm_enable = 0;
    
    // Mocks for Break-Before-Make Phases
    logic       eval_phase;
    logic       pre_charge_phase;

    logic       pre_charge_global;
    logic       on_detect;
    logic       off_detect;
    logic       pixel_rst;
    logic       sm_next_row;
    logic [5:0] row_addr;

    // Phase Generation Mock (Since we are testing outside of the top-wrapper)
    assign eval_phase       = div_clk;
    assign pre_charge_phase = ~div_clk;

    // DUT Instantiation
    roic_sm i_roic_sm (
        .div_clk           (div_clk),
        .rst_n             (rst_n),
        .sm_enable         (sm_enable),
        .eval_phase        (eval_phase),       
        .pre_charge_phase  (pre_charge_phase), 
        .pre_charge_global (pre_charge_global),
        .on_detect         (on_detect),
        .off_detect        (off_detect),
        .pixel_rst         (pixel_rst),
        // is_on_state & is_off_state are left unconnected in this isolated TB
        .sm_next_row       (sm_next_row),
        .row_addr          (row_addr)
    );

    // Clock Generation
    always begin
        #(DIV_CLK_PERIOD_NS / 2) div_clk = ~div_clk;
    end

    // Main Test Sequence
    initial begin
        $display("==================================================");
        $display("Starting Posedge Phase-Gated ROIC TB...");
        $display("==================================================");

        // 1. Reset Sequence
        rst_n = 0;
        sm_enable = 0;
        #100;
        rst_n = 1;
        $display("[INIT] Reset de-asserted. Hardware in IDLE state.");

        // -------------------------------------------------------------
        $display("\n--- TEST 1: Disabled State (IDLE) ---");
        @(posedge div_clk);
        check_outputs(0, 0, 0, 0, 0, 6'd0, "IDLE State (High Phase)");
        @(negedge div_clk);
        check_outputs(1, 0, 0, 0, 0, 6'd0, "IDLE State (Low Phase)");
        $display("  -> [PASS] FSM safely clamps array when disabled.");

        // -------------------------------------------------------------
        $display("\n--- TEST 2: Single Row Sequence (Row 0) ---");
        @(negedge div_clk); // Align before next posedge
        #1;                 
        sm_enable = 1;      // Enable FSM cleanly
        
        // Next posedge transitions IDLE -> ON_DETECT
        verify_phase_gated_sequence(6'd0);
        $display("  -> [PASS] Posedge ON -> OFF -> RST sequence executed.");

        // -------------------------------------------------------------
        $display("\n--- TEST 3: Full Frame Sweep & Wrap-Around ---");
        for (int i = 1; i < 64; i++) begin
            verify_phase_gated_sequence(i[5:0]);
        end
        $display("  -> [PASS] Successfully swept all 64 rows with posedge alignment.");
        
        verify_phase_gated_sequence(6'd0);
        $display("  -> [PASS] Row counter wrapped perfectly back to Row 0.");

        // -------------------------------------------------------------
        $display("\n--- TEST 4: True Freeze (Pause & Resume) ---");
        
        // Enter Row 1 ON_DETECT High Phase
        @(posedge div_clk); 
        check_outputs(0, 1, 0, 0, 0, 6'd1, "Row 1 ON_DETECT (High Phase)");
        
        // Pause the system mid-cycle
        #(DIV_CLK_PERIOD_NS / 4);
        sm_enable = 0; 
        
        // Negedge 1: FSM safely pre-charges, state is FROZEN at ON_DETECT
        @(negedge div_clk);
        check_outputs(1, 0, 0, 0, 0, 6'd1, "Mid-Cycle Freeze (Low Phase Safety)"); 
        
        // Posedge 2: Paused, state doesn't change, Eval is muted by sm_enable=0
        @(posedge div_clk);
        check_outputs(0, 0, 0, 0, 0, 6'd1, "Frozen State (High Phase Quiet)"); 
        
        // Negedge 2: Still frozen, safe pre-charge
        @(negedge div_clk);
        check_outputs(1, 0, 0, 0, 0, 6'd1, "Frozen State (Low Phase Safety)"); 

        // Unpause the system before the next posedge
        sm_enable = 1;

        // Posedge 3: FSM resumes and safely advances to the NEXT state (OFF_DETECT)
        @(posedge div_clk);
        check_outputs(0, 0, 1, 0, 0, 6'd1, "Row 1 OFF_DETECT (Resumed Sequence)");

        @(negedge div_clk);
        check_outputs(1, 0, 0, 0, 0, 6'd1, "Row 1 OFF_DETECT (Low Phase)");

        // Posedge 4: Proof that the FSM properly shifted to the next state
        @(posedge div_clk);
        check_outputs(0, 0, 0, 1, 1, 6'd1, "Row 1 PIXEL_RST (Sequence Continued)");

        $display("  -> [PASS] FSM successfully froze, held state, and advanced cleanly.");
        $finish;
    end

    // -----------------------------------------------------------------
    // HELPER TASKS 
    // -----------------------------------------------------------------
    task automatic verify_phase_gated_sequence(input logic [5:0] expected_row);
        
        // --- CYCLE 1: ON_DETECT ---
        @(posedge div_clk);
        check_outputs(0, 1, 0, 0, 0, expected_row, $sformatf("Row %0d ON_DETECT (Eval)", expected_row));
        @(negedge div_clk);
        check_outputs(1, 0, 0, 0, 0, expected_row, $sformatf("Row %0d ON_DETECT (PreCharge)", expected_row));

        // --- CYCLE 2: OFF_DETECT ---
        @(posedge div_clk);
        check_outputs(0, 0, 1, 0, 0, expected_row, $sformatf("Row %0d OFF_DETECT (Eval)", expected_row));
        @(negedge div_clk);
        check_outputs(1, 0, 0, 0, 0, expected_row, $sformatf("Row %0d OFF_DETECT (PreCharge)", expected_row));

        // --- CYCLE 3: PIXEL_RST ---
        @(posedge div_clk);
        check_outputs(0, 0, 0, 1, 1, expected_row, $sformatf("Row %0d PIXEL_RST (Eval)", expected_row));
        @(negedge div_clk);
        check_outputs(1, 0, 0, 0, 1, expected_row, $sformatf("Row %0d PIXEL_RST (PreCharge)", expected_row));

    endtask

    task automatic check_outputs(
        input logic exp_pre,
        input logic exp_on, 
        input logic exp_off, 
        input logic exp_rst, 
        input logic exp_next,
        input logic [5:0] exp_row, 
        input string phase
    );
        #1; 
        if (pre_charge_global !== exp_pre || on_detect !== exp_on || off_detect !== exp_off || 
            pixel_rst !== exp_rst || sm_next_row !== exp_next || row_addr !== exp_row) begin
            $display("\n[FATAL ERROR] Logic failure during %s!", phase);
            $display("  Expected: PRE=%b, ON=%b, OFF=%b, RST=%b, NXT=%b, ROW=%0d", exp_pre, exp_on, exp_off, exp_rst, exp_next, exp_row);
            $display("  Actual  : PRE=%b, ON=%b, OFF=%b, RST=%b, NXT=%b, ROW=%0d", pre_charge_global, on_detect, off_detect, pixel_rst, sm_next_row, row_addr);
            $stop;
        end
    endtask

endmodule : roic_sm_tb