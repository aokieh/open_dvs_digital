//---------------------------------------------------------------------------
// Author: Ababakar Okieh
// Date  : March 30th, 2026
//
// Module: clk_div
//
// Description: 
//  Behavioral clock divider model for OpenDVS.
//---------------------------------------------------------------------------

module clk_div (
    `ifdef USE_POWER_PINS
        inout vccd1, // OpenLane Power  
        inout vssd1, // OpenLane Ground 
    `endif
    
    input  logic        sys_clk,
    input  logic        rst_n,
    
    // 8-bit input: Sets the FULL PERIOD from 1us to 256us
    input  logic [7:0]  program_bits,
    
    output logic        div_clk,
    output logic        eval_phase,       // [NEW] Safe high phase
    output logic        pre_charge_phase  // [NEW] Safe low phase
);

    logic [4:0] tick_25;     
    logic [7:0] half_us_ctr;

    // Explicitly define the target count to keep linters happy
    logic [7:0] target_count;
    assign target_count = (program_bits == 8'd0) ? 8'd255 : (program_bits - 8'd1);

    always_ff @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            tick_25     <= '0;
            half_us_ctr <= '0;
            div_clk     <= 1'b0;
        end
        else begin
            if (tick_25 < 5'd24) begin
                tick_25 <= tick_25 + 5'd1;
            end 
            else begin
                tick_25 <= '0;

                if (half_us_ctr < target_count) begin
                    half_us_ctr <= half_us_ctr + 8'd1;
                end 
                else begin
                    half_us_ctr <= '0;
                    div_clk     <= ~div_clk; // Toggle 50% duty cycle                 
                end
            end
        end
    end

    // -----------------------------------------------------------------
    // THE BREAK-BEFORE-MAKE SAFETY DEAD-ZONES
    // -----------------------------------------------------------------
    // We isolate the exact 20ns cycle when the phase starts, 
    // and the exact 20ns cycle right before the phase ends.
    logic start_dead_zone;
    logic end_dead_zone;
    logic safe_window;

    assign start_dead_zone = (tick_25 == 5'd0)  && (half_us_ctr == 8'd0);
    assign end_dead_zone   = (tick_25 == 5'd24) && (half_us_ctr == target_count);
    
    assign safe_window = ~(start_dead_zone | end_dead_zone);

    // Only allow analog signals to go high when safely inside the window
    assign eval_phase       = div_clk  && safe_window;
    assign pre_charge_phase = !div_clk && safe_window;

endmodule : clk_div