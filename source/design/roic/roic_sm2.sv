//---------------------------------------------------------------------------
// Module: roic_sm2
// Description: 
//  Continuous Pacing Micro-Sequencer. Guarantees analog reads hit exactly 
//  on the prg_bits intervals by pre-subtracting phase overheads.
//---------------------------------------------------------------------------

module roic_sm2 (
    `ifdef USE_POWER_PINS
        inout vccd1, 
        inout vssd1, 
    `endif
    
    input  logic        sys_clk,      
    input  logic        rst_n,
    input  logic        sm_enable,    
    input  logic [7:0]  program_bits, 

    // Phase-Gated Analog Pulses
    output logic        pre_charge_global,
    output logic        on_detect,
    output logic        off_detect,
    output logic        pixel_rst,
    
    // Digital Backend Control
    output logic        sm_next_row, 
    output logic [5:0]  row_addr,
    output logic        fifo_wr_en,
    output logic [1:0]  event_flag    
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
    // TARGET & OVERHEAD CALCULATION (Exact Subtraction)
    // -----------------------------------------------------------------
    logic [13:0] target_ticks;
    assign target_ticks = (program_bits == 8'd0) ? 14'd12800 : program_bits * 14'd50;

    logic [13:0] wait_on_ticks;
    logic [13:0] wait_off_ticks;
    logic [13:0] wait_rst_ticks;
    logic [13:0] wait_next_ticks;

    assign wait_on_ticks   = target_ticks - (P_PRE_CHARGE + P_BUFFER);
    assign wait_off_ticks  = target_ticks - (P_ON_DETECT + P_PRE_CHARGE + P_BUFFER);
    assign wait_rst_ticks  = target_ticks - (P_OFF_DETECT + P_BUFFER);
    assign wait_next_ticks = target_ticks - (P_RST + 1 + P_PRE_CHARGE + P_BUFFER);

    // -----------------------------------------------------------------
    // INTERNAL REGISTERS & STATE
    // -----------------------------------------------------------------
    typedef enum logic [3:0] {
        ST_IDLE, ST_WAIT_ON, ST_PRE_1, ST_BUF_1, ST_ON_DET, 
        ST_WAIT_OFF, ST_PRE_2, ST_BUF_2, ST_OFF_DET, 
        ST_WAIT_RST, ST_BUF_3, ST_PIX_RST, ST_NEXT_ROW, ST_WAIT_NEXT
    } state_t;
    
    state_t      state;
    logic [5:0]  row_ctr;
    logic [4:0]  phase_ctr; 
    logic [13:0] wait_ctr;  

    assign row_addr = row_ctr; 

    // -----------------------------------------------------------------
    // SEQUENTIAL ENGINE 
    // -----------------------------------------------------------------
    always_ff @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            state             <= ST_IDLE;
            row_ctr           <= 6'd0;
            phase_ctr         <= '0;
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
                // Default drops for single-cycle digital flags
                sm_next_row <= 1'b0;
                fifo_wr_en  <= 1'b0;

                // Safe defaults for analog pins
                pre_charge_global <= 1'b0;
                on_detect         <= 1'b0;
                off_detect        <= 1'b0;
                pixel_rst         <= 1'b0;

                case (state)
                    // [FIXED] Combine IDLE and WAIT_ON to eliminate the 1-cycle startup delay
                    ST_IDLE, ST_WAIT_ON: begin
                        if (wait_ctr >= wait_on_ticks - 1) begin
                            wait_ctr <= '0;
                            state    <= ST_PRE_1;
                        end else begin
                            wait_ctr <= wait_ctr + 14'd1;
                            state    <= ST_WAIT_ON; // Securely lock into the WAIT state
                        end
                    end

                    ST_PRE_1: begin
                        pre_charge_global <= 1'b1;
                        if (phase_ctr >= P_PRE_CHARGE - 1) begin
                            phase_ctr <= '0;
                            state     <= ST_BUF_1;
                        end else phase_ctr <= phase_ctr + 5'd1;
                    end

                    ST_BUF_1: begin
                        if (phase_ctr >= P_BUFFER - 1) begin
                            phase_ctr <= '0;
                            state     <= ST_ON_DET;
                        end else phase_ctr <= phase_ctr + 5'd1;
                    end

                    ST_ON_DET: begin
                        on_detect <= 1'b1;
                        if (phase_ctr >= P_ON_DETECT - 1) begin
                            phase_ctr  <= '0;
                            state      <= ST_WAIT_OFF;
                            fifo_wr_en <= 1'b1; 
                            event_flag <= 2'b10;
                        end else phase_ctr <= phase_ctr + 5'd1;
                    end

                    ST_WAIT_OFF: begin
                        if (wait_ctr >= wait_off_ticks - 1) begin
                            wait_ctr <= '0;
                            state    <= ST_PRE_2;
                        end else wait_ctr <= wait_ctr + 14'd1;
                    end

                    ST_PRE_2: begin
                        pre_charge_global <= 1'b1;
                        if (phase_ctr >= P_PRE_CHARGE - 1) begin
                            phase_ctr <= '0;
                            state     <= ST_BUF_2;
                        end else phase_ctr <= phase_ctr + 5'd1;
                    end

                    ST_BUF_2: begin
                        if (phase_ctr >= P_BUFFER - 1) begin
                            phase_ctr <= '0;
                            state     <= ST_OFF_DET;
                        end else phase_ctr <= phase_ctr + 5'd1;
                    end

                    ST_OFF_DET: begin
                        off_detect <= 1'b1;
                        if (phase_ctr >= P_OFF_DETECT - 1) begin
                            phase_ctr  <= '0;
                            state      <= ST_WAIT_RST;
                            fifo_wr_en <= 1'b1; 
                            event_flag <= 2'b01;
                        end else phase_ctr <= phase_ctr + 5'd1;
                    end

                    ST_WAIT_RST: begin 
                        if (wait_ctr >= wait_rst_ticks - 1) begin
                            wait_ctr <= '0;
                            state    <= ST_BUF_3;
                        end else wait_ctr <= wait_ctr + 14'd1;
                    end

                    ST_BUF_3: begin
                        if (phase_ctr >= P_BUFFER - 1) begin
                            phase_ctr <= '0;
                            state     <= ST_PIX_RST;
                        end else phase_ctr <= phase_ctr + 5'd1;
                    end

                    ST_PIX_RST: begin
                        pixel_rst <= 1'b1;
                        if (phase_ctr >= P_RST - 1) begin
                            phase_ctr   <= '0;
                            state       <= ST_NEXT_ROW;
                            sm_next_row <= 1'b1; 
                        end else phase_ctr <= phase_ctr + 5'd1;
                    end

                    ST_NEXT_ROW: begin
                        row_ctr <= row_ctr + 6'd1;
                        state   <= ST_WAIT_NEXT;
                    end

                    ST_WAIT_NEXT: begin
                        if (wait_ctr >= wait_next_ticks - 1) begin
                            wait_ctr <= '0;
                            state    <= ST_PRE_1; 
                        end else wait_ctr <= wait_ctr + 14'd1;
                    end
                endcase
            end else begin
                // Safely pause the system without losing state or data
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