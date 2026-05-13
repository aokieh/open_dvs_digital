//---------------------------------------------------------------------------
// Author: Ababakar Okieh
// Date  : April 27, 2026
//
// Module: roic_sm
//
// Description: 
//  Behavioral roic state machine model for OpenDVS.
//  Updated for fully programmable phase timings to ensure post-tapeout tuning.
//---------------------------------------------------------------------------

module roic_sm2_2x2 (
    `ifdef USE_POWER_PINS
        inout vccd1, 
        inout vssd1, 
    `endif
    
    input  logic        sys_clk,      
    input  logic        rst_n,
    input  logic        sm_enable,    
    input  logic [7:0]  program_bits, 

    // Programmable Timing Inputs (Ticks)
    input  logic [13:0]  p_pre_charge,
    input  logic [13:0]  p_buffer,
    input  logic [13:0]  p_detect,
    input  logic [13:0]  p_on_detect,
    input  logic [13:0]  p_off_detect,
    input  logic [13:0]  p_rst,

    // Phase-Gated Analog Pulses
    output logic        pre_charge_global, // Active LOW
    output logic        on_detect,
    output logic        off_detect,
    output logic        detect_pulse,      // Mid-read column trigger
    output logic        pixel_rst,
    
    // Digital Backend Control
    output logic        sm_next_row, 
    // output logic [5:0]  row_addr,
    output logic        row_addr,
    output logic        fifo_wr_en,
    output logic [1:0]  event_flag    
);

    // -----------------------------------------------------------------
    // TARGET & OVERHEAD CALCULATION (clk cycles till signals are active)
    // -----------------------------------------------------------------
    logic [13:0] target_ticks;
    assign target_ticks = (program_bits == 8'd0) ? 14'd12800 : program_bits * 14'd50;

    logic [13:0] wait_on_ticks;
    logic [13:0] wait_off_ticks;
    logic [13:0] wait_rst_ticks;
    logic [13:0] wait_next_ticks;

    assign wait_on_ticks   = target_ticks - (p_pre_charge + p_buffer) + 14'd1;
    assign wait_off_ticks  = target_ticks - (p_on_detect + p_pre_charge + p_buffer);
    assign wait_rst_ticks  = target_ticks - (p_off_detect + p_buffer);
    assign wait_next_ticks = target_ticks - (p_rst + 1 + p_pre_charge + p_buffer);

    // -----------------------------------------------------------------
    // INTERNAL REGISTERS & STATES
    // -----------------------------------------------------------------
    localparam [3:0]
        ST_IDLE      = 4'd0,
        ST_WAIT_ON   = 4'd1,
        ST_PRE_1     = 4'd2,
        ST_BUF_1     = 4'd3,
        ST_ON_DET    = 4'd4,
        ST_WAIT_OFF  = 4'd5,
        ST_PRE_2     = 4'd6,
        ST_BUF_2     = 4'd7,
        ST_OFF_DET   = 4'd8,
        ST_WAIT_RST  = 4'd9,
        ST_BUF_3     = 4'd10,
        ST_PIX_RST   = 4'd11,
        ST_NEXT_ROW  = 4'd12,
        ST_WAIT_NEXT = 4'd13;
        
    logic [3:0]  state;
    logic [5:0]  row_ctr;
    logic [13:0] phase_ctr;  // EXTENDED to 14 bits to match new parameter width
    logic [13:0] wait_ctr;  

    assign row_addr = row_ctr; 

    // -----------------------------------------------------------------
    // COMBINATIONAL OUTPUTS
    // -----------------------------------------------------------------
    always_comb begin
        if (!sm_enable) begin
            pre_charge_global = 1'b1; // Inactive HIGH
            on_detect         = 1'b0;
            off_detect        = 1'b0;
            pixel_rst         = 1'b0;
            detect_pulse      = 1'b0;
        end else begin
            pre_charge_global = ~(state == ST_PRE_1 || state == ST_PRE_2);
            on_detect         = (state == ST_ON_DET || state == ST_PIX_RST); // change for RYAN ||ST_PIX_RST
            off_detect        = (state == ST_OFF_DET);
            pixel_rst         = (state == ST_PIX_RST);
            
            detect_pulse      = ((state == ST_ON_DET)  && (phase_ctr >= (p_on_detect - p_detect))) ||
                                ((state == ST_OFF_DET) && (phase_ctr >= (p_off_detect - p_detect)));
        end
    end

    // -----------------------------------------------------------------
    // SEQUENTIAL FSM
    // -----------------------------------------------------------------
    always_ff @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= ST_IDLE;
            row_ctr     <= 6'd0;
            phase_ctr   <= '0;
            wait_ctr    <= '0;
            sm_next_row <= 1'b0;
            fifo_wr_en  <= 1'b0;
            event_flag  <= 2'b00;
        end
        else begin
            if (sm_enable) begin
                sm_next_row <= 1'b0;
                fifo_wr_en  <= 1'b0;

                case (state)
                    ST_IDLE, ST_WAIT_ON: begin
                        if (wait_ctr >= wait_on_ticks - 1) begin
                            wait_ctr <= '0;
                            state    <= ST_PRE_1;
                        end else begin
                            wait_ctr <= wait_ctr + 14'd1;
                            state    <= ST_WAIT_ON; 
                        end
                    end

                    ST_PRE_1: begin
                        if (phase_ctr >= p_pre_charge - 1) begin
                            phase_ctr <= '0;
                            state     <= ST_BUF_1;
                        end else phase_ctr <= phase_ctr + 14'd1;
                    end

                    ST_BUF_1: begin
                        if (phase_ctr >= p_buffer - 1) begin
                            phase_ctr <= '0;
                            state     <= ST_ON_DET;
                        end else phase_ctr <= phase_ctr + 14'd1;
                    end

                    ST_ON_DET: begin
                        if (phase_ctr >= p_on_detect - 1) begin
                            phase_ctr  <= '0;
                            state      <= ST_WAIT_OFF;
                            fifo_wr_en <= 1'b1; 
                            event_flag <= 2'b10;
                        end else phase_ctr <= phase_ctr + 14'd1;
                    end

                    ST_WAIT_OFF: begin
                        if (wait_ctr >= wait_off_ticks - 1) begin
                            wait_ctr <= '0;
                            state    <= ST_PRE_2;
                        end else wait_ctr <= wait_ctr + 14'd1;
                    end

                    ST_PRE_2: begin
                        if (phase_ctr >= p_pre_charge - 1) begin
                            phase_ctr <= '0;
                            state     <= ST_BUF_2;
                        end else phase_ctr <= phase_ctr + 14'd1;
                    end

                    ST_BUF_2: begin
                        if (phase_ctr >= p_buffer - 1) begin
                            phase_ctr <= '0;
                            state     <= ST_OFF_DET;
                        end else phase_ctr <= phase_ctr + 14'd1;
                    end

                    ST_OFF_DET: begin
                        if (phase_ctr >= p_off_detect - 1) begin
                            phase_ctr  <= '0;
                            state      <= ST_WAIT_RST;
                            fifo_wr_en <= 1'b1; 
                            event_flag <= 2'b01;
                        end else phase_ctr <= phase_ctr + 14'd1;
                    end

                    ST_WAIT_RST: begin 
                        if (wait_ctr >= wait_rst_ticks - 1) begin
                            wait_ctr <= '0;
                            state    <= ST_BUF_3;
                        end else wait_ctr <= wait_ctr + 14'd1;
                    end

                    ST_BUF_3: begin
                        if (phase_ctr >= p_buffer - 1) begin
                            phase_ctr <= '0;
                            state     <= ST_PIX_RST;
                        end else phase_ctr <= phase_ctr + 14'd1;
                    end

                    ST_PIX_RST: begin
                        if (phase_ctr >= p_rst - 1) begin
                            phase_ctr   <= '0;
                            state       <= ST_NEXT_ROW;
                            sm_next_row <= 1'b1; 
                        end else phase_ctr <= phase_ctr + 14'd1;
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
                    default: begin  //linter warning, possible latch
                        state <= ST_IDLE;
                    end
                endcase
            end else begin
                fifo_wr_en  <= 1'b0;
                sm_next_row <= 1'b0;
            end
        end
    end

endmodule : roic_sm2_2x2