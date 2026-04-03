//---------------------------------------------------------------------------
// Module: roic_sm
// Description: 
//  Unified 50MHz Micro-Sequencer for the Neuromorphic Imager.
//  Handles both the Integration Timer and the physical Burst Readout phases.
//---------------------------------------------------------------------------

module roic_sm2 (
    `ifdef USE_POWER_PINS
        inout vccd1, // OpenLane Power  
        inout vssd1, // OpenLane Ground 
    `endif
    
    input  logic        sys_clk,      // 50MHz Master Clock (20ns tick)
    input  logic        rst_n,
    input  logic        sm_enable,    // From Backpressure logic
    input  logic [7:0]  program_bits, // Integration time (1us to 256us)

    // Phase-Gated Analog Pulses
    output logic        pre_charge_global,
    output logic        on_detect,
    output logic        off_detect,
    output logic        pixel_rst,
    
    // Digital Backend Control
    output logic        sm_next_row, 
    output logic [5:0]  row_addr,
    output logic        fifo_wr_en,
    output logic [1:0]  event_flag    // 2'b10 = ON, 2'b01 = OFF
);

    // -----------------------------------------------------------------
    // TIMING PARAMETERS (50MHz = 20ns per tick)
    // -----------------------------------------------------------------
    parameter P_PRE_CHARGE = 10; // 200ns
    parameter P_BUFFER     = 2;  // 40ns
    parameter P_ON_DETECT  = 14; // 280ns
    parameter P_OFF_DETECT = 14; // 280ns
    parameter P_RST        = 25; // 500ns

    // -----------------------------------------------------------------
    // INTERNAL REGISTERS & STATE
    // -----------------------------------------------------------------
    typedef enum logic [3:0] {
        ST_IDLE, ST_PRE_1, ST_BUF_1, ST_ON_DET, ST_BUF_2,
        ST_PRE_2, ST_BUF_3, ST_OFF_DET, ST_BUF_4, ST_PIX_RST, ST_NEXT_ROW
    } state_t;
    
    state_t      state;
    logic [5:0]  row_ctr;
    logic [4:0]  tick_ctr; // Counts up to 31 (Enough for P_RST)
    logic [13:0] wait_ctr; // Integration timer

    assign row_addr = row_ctr; 

    // Target integration in 20ns ticks (e.g., 1us = 50 ticks)
    logic [13:0] target_ticks;
    assign target_ticks = (program_bits == 8'd0) ? 14'd12800 : program_bits * 14'd50;

    // -----------------------------------------------------------------
    // SEQUENTIAL ENGINE (Registered Outputs for clean STA)
    // -----------------------------------------------------------------
    always_ff @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            state             <= ST_IDLE;
            row_ctr           <= 6'd0;
            tick_ctr          <= '0;
            wait_ctr          <= '0;
            pre_charge_global <= 1'b0;
            on_detect         <= 1'b0;
            off_detect        <= 1'b0;
            pixel_rst         <= 1'b0;
            sm_next_row       <= 1'b0;
            fifo_wr_en        <= 1'b0;
            event_flag        <= 2'b00;
        end
        else begin
            if (sm_enable) begin
                // Default drop for single-cycle digital pulses
                sm_next_row <= 1'b0;
                fifo_wr_en  <= 1'b0;

                // Continuously drive analog pins based on state to ensure 
                // safe recovery if paused mid-burst.
                pre_charge_global <= 1'b0;
                on_detect         <= 1'b0;
                off_detect        <= 1'b0;
                pixel_rst         <= 1'b0;

                case (state)
                    ST_IDLE: begin
                        if (wait_ctr >= target_ticks - 1) begin
                            wait_ctr <= '0;
                            state    <= ST_PRE_1;
                        end else begin
                            wait_ctr <= wait_ctr + 14'd1;
                        end
                    end

                    ST_PRE_1: begin
                        pre_charge_global <= 1'b1;
                        if (tick_ctr >= P_PRE_CHARGE - 1) begin
                            tick_ctr <= '0;
                            state    <= ST_BUF_1;
                        end else tick_ctr <= tick_ctr + 5'd1;
                    end

                    ST_BUF_1: begin
                        if (tick_ctr >= P_BUFFER - 1) begin
                            tick_ctr <= '0;
                            state    <= ST_ON_DET;
                        end else tick_ctr <= tick_ctr + 5'd1;
                    end

                    ST_ON_DET: begin
                        on_detect <= 1'b1;
                        if (tick_ctr >= P_ON_DETECT - 1) begin
                            tick_ctr   <= '0;
                            state      <= ST_BUF_2;
                            // Trigger FIFO exactly as the analog pulse ends
                            fifo_wr_en <= 1'b1; 
                            event_flag <= 2'b10;
                        end else tick_ctr <= tick_ctr + 5'd1;
                    end

                    ST_BUF_2: begin
                        if (tick_ctr >= P_BUFFER - 1) begin
                            tick_ctr <= '0;
                            state    <= ST_PRE_2;
                        end else tick_ctr <= tick_ctr + 5'd1;
                    end

                    ST_PRE_2: begin
                        pre_charge_global <= 1'b1;
                        if (tick_ctr >= P_PRE_CHARGE - 1) begin
                            tick_ctr <= '0;
                            state    <= ST_BUF_3;
                        end else tick_ctr <= tick_ctr + 5'd1;
                    end

                    ST_BUF_3: begin
                        if (tick_ctr >= P_BUFFER - 1) begin
                            tick_ctr <= '0;
                            state    <= ST_OFF_DET;
                        end else tick_ctr <= tick_ctr + 5'd1;
                    end

                    ST_OFF_DET: begin
                        off_detect <= 1'b1;
                        if (tick_ctr >= P_OFF_DETECT - 1) begin
                            tick_ctr   <= '0;
                            state      <= ST_BUF_4;
                            // Trigger FIFO exactly as the analog pulse ends
                            fifo_wr_en <= 1'b1; 
                            event_flag <= 2'b01;
                        end else tick_ctr <= tick_ctr + 5'd1;
                    end

                    ST_BUF_4: begin // Directly into RST (No pre-charge)
                        if (tick_ctr >= P_BUFFER - 1) begin
                            tick_ctr <= '0;
                            state    <= ST_PIX_RST;
                        end else tick_ctr <= tick_ctr + 5'd1;
                    end

                    ST_PIX_RST: begin
                        pixel_rst <= 1'b1;
                        if (tick_ctr >= P_RST - 1) begin
                            tick_ctr    <= '0;
                            state       <= ST_NEXT_ROW;
                            sm_next_row <= 1'b1; // Trigger Scanner Token
                        end else tick_ctr <= tick_ctr + 5'd1;
                    end

                    ST_NEXT_ROW: begin
                        row_ctr <= row_ctr + 6'd1;
                        state   <= ST_IDLE; // Sleep until next integration completes
                    end
                endcase
            end else begin
                // Paused: Force analog pins low for safety. Counters and state freeze.
                pre_charge_global <= 1'b0;
                on_detect         <= 1'b0;
                off_detect        <= 1'b0;
                pixel_rst         <= 1'b0;
                fifo_wr_en        <= 1'b0;
                sm_next_row       <= 1'b0;
            end
        end
    end

endmodule : roic_sm2