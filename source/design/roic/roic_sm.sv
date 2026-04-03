//---------------------------------------------------------------------------
// Author: Ababakar Okieh
// Date  : March 30th, 2026
//
// Module: roic_sm
//
// Description: 
//  Behavioral roic state machine model for OpenDVS.
//---------------------------------------------------------------------------

// module roic_sm (
//     `ifdef USE_POWER_PINS
//         inout vccd1, // OpenLane Power  
//         inout vssd1, // OpenLane Ground 
//     `endif
    
//     input  logic                  div_clk,
//     input  logic                  rst_n,

//     // Control signal to determine FSM activity
//     input  logic                  sm_enable,

//     output logic                  on_detect,
//     output logic                  off_detect,
//     output logic                  pixel_rst,
//     output logic [5:0]            row_addr
// );

//     logic [5:0] row_ctr; // Removed inline initialization to prevent multiple-driver errors
//     assign row_addr = row_ctr; 

//     // 2-bit register to track our 3 states
//     logic [1:0] state;

//     always_ff @(posedge div_clk or negedge rst_n) begin
//         if (!rst_n) begin
//             pixel_rst   <= 1'b0;
//             off_detect  <= 1'b0;
//             on_detect   <= 1'b0;
//             state       <= 2'd0;
//             row_ctr     <= 6'd0;
//         end
//         else begin
//             if (sm_enable) begin
                
//                 // NEW LOGIC: Increment the row counter ONLY when exiting the reset phase
//                 if (pixel_rst) begin
//                     row_ctr <= row_ctr + 6'd1;
//                 end

//                 case (state)
//                     2'd0: begin // 1.) First rising edge
//                         on_detect   <= 1'b1;
//                         off_detect  <= 1'b0;
//                         pixel_rst   <= 1'b0;
//                         state       <= 2'd1;
//                     end
                    
//                     2'd1: begin // 2.) Second rising edge
//                         on_detect   <= 1'b0;
//                         off_detect  <= 1'b1;
//                         pixel_rst   <= 1'b0;
//                         state       <= 2'd2;
//                     end
                    
//                     2'd2: begin // 3.) Third rising edge
//                         on_detect   <= 1'b0;
//                         off_detect  <= 1'b0;
//                         pixel_rst   <= 1'b1;
//                         state       <= 2'd0; 
//                         // Removed row_ctr increment from here
//                     end
                    
//                     default: begin // Failsafe
//                         on_detect   <= 1'b0;
//                         off_detect  <= 1'b0;
//                         pixel_rst   <= 1'b0;
//                         state       <= 2'd0;
//                         row_ctr     <= 6'd0;
//                     end
//                 endcase
//             end else begin
//                 // When disabled, clear outputs and reset the sequence to the start
//                 on_detect   <= 1'b0;
//                 off_detect  <= 1'b0;
//                 pixel_rst   <= 1'b0;
//                 state       <= 2'd0;
//                 row_ctr     <= 6'd0;
//             end
//         end
//     end

// endmodule : roic_sm

//---------------------------------------------------------------------------
// Module: roic_sm
// Description: 
//  5-State ROIC State Machine for Analog Pixel Array Readout.
//  Sequence: PreCharge1 -> OnDetect -> PreCharge2 -> OffDetect -> PixelRst
//---------------------------------------------------------------------------

// module roic_sm (
//     `ifdef USE_POWER_PINS
//         inout vccd1, // OpenLane Power  
//         inout vssd1, // OpenLane Ground 
//     `endif
    
//     input  logic                  div_clk,
//     input  logic                  rst_n,

//     // Control signal to determine FSM activity
//     input  logic                  sm_enable,
//     input  logic                  pre_charge_valid,

//     // Analog Array Control Pulses
//     output logic                  pre_charge,
//     output logic                  on_detect,
//     output logic                  off_detect,
//     output logic                  pixel_rst,
//     output logic                  pre_charge_global
    
//     // Digital Backend Control
//     output logic                  sm_next_row, // Triggers the row_scanner
//     output logic [5:0]            row_addr     // Tags data in the sync_fifo
// );

//     logic [5:0] row_ctr; 
//     assign row_addr = row_ctr; 

//     // Expanded to 3 bits to hold 5 states (0 to 4)
//     logic [2:0] state;

//     always_ff @(posedge div_clk or negedge rst_n) begin
//         if (!rst_n) begin
//             pre_charge  <= 1'b0;
//             on_detect   <= 1'b0;
//             off_detect  <= 1'b0;
//             pixel_rst   <= 1'b0;
//             sm_next_row <= 1'b0;
//             state       <= 3'd0;
//             row_ctr     <= 6'd0;
//         end
//         else begin
//             if (sm_enable) begin
                
//                 // Increment the row counter ONLY when exiting the reset phase
//                 if (pixel_rst) begin
//                     row_ctr <= row_ctr + 6'd1;
//                 end

//                 if (pre_charge_valid == 1'b1 && state == (2'd0 || 2'd1)) begin
//                     pre_charge_global <= 1'd1;
//                 end else begin
//                     pre_charge_global <= 1'd0;
//                 end

//                 case (state)
//                     2'd0: begin // 1.) RST state
//                         pixel_rst   <= 1'b1;
//                         on_detect   <= 1'b0;
//                         off_detect  <= 1'b0;
//                         sm_next_row <= 1'b1;
//                         state       <= 2'd1;
//                     end
                    
//                     2'd1: begin // 2.) ON detect state
//                         on_detect   <= 1'b1;
//                         pixel_rst   <= 1'b0;
//                         sm_next_row <= 1'b0;
//                         state       <= 2'd2;
//                     end
                    
//                     2'd2: begin // 3.) OFF detect state
//                         on_detect   <= 1'b0;
//                         off_detect  <= 1'b1;
//                         state       <= 2'd0;
//                     end
                    
//                     default: begin // Failsafe
//                         pre_charge  <= 1'b0;
//                         on_detect   <= 1'b0;
//                         off_detect  <= 1'b0;
//                         pixel_rst   <= 1'b0;
//                         sm_next_row <= 1'b0;
//                         state       <= 3'd0;
//                         row_ctr     <= 6'd0;
//                     end
//                 endcase
//             end else begin
//                 // When disabled, immediately kill all analog pulses and reset tracking
//                 pre_charge  <= 1'b0;
//                 on_detect   <= 1'b0;
//                 off_detect  <= 1'b0;
//                 pixel_rst   <= 1'b0;
//                 sm_next_row <= 1'b0;
//                 state       <= 3'd0;
//                 row_ctr     <= 6'd0;
//             end
//         end
//     end

// endmodule : roic_sm

module roic_sm (
    `ifdef USE_POWER_PINS
        inout vccd1, // OpenLane Power  
        inout vssd1, // OpenLane Ground 
    `endif
    
    input  logic                  div_clk,
    input  logic                  rst_n,
    input  logic                  sm_enable,

    input  logic                  eval_phase,
    input  logic                  pre_charge_phase,

    // Phase-Gated Analog Pulses
    output logic                  pre_charge_global,
    output logic                  on_detect,
    output logic                  off_detect,
    output logic                  pixel_rst,

    output logic                  is_on_state,
    output logic                  is_off_state,
    
    // Digital Backend Control
    output logic                  sm_next_row, 
    output logic [5:0]            row_addr     
);

    logic [5:0] row_ctr; 
    assign row_addr = row_ctr; 

    // Expanded to 4 states: 0=IDLE, 1=ON, 2=OFF, 3=RST
    logic [1:0] state;

    // -----------------------------------------------------------------
    // DIGITAL DATA PLANE (Ungated, continuous state for the FIFO)
    // -----------------------------------------------------------------
    assign is_on_state  = sm_enable && (state == 2'd1);
    assign is_off_state = sm_enable && (state == 2'd2);
    
    // -----------------------------------------------------------------
    // COMBINATIONAL PHASE GATING (Break-Before-Make Safe)
    // -----------------------------------------------------------------
    always_comb begin
        // Default everything to safe 0
        pre_charge_global = 1'b0;
        on_detect         = 1'b0;
        off_detect        = 1'b0;
        pixel_rst         = 1'b0;

        if (pre_charge_phase) begin
            // LOW PHASE: Safely inside the Pre-Charge window
            pre_charge_global = 1'b1;
        end 
        else if (eval_phase && sm_enable) begin
            // HIGH PHASE & ENABLED: Safely inside the Evaluate window
            case (state)
                2'd1: on_detect  = 1'b1;
                2'd2: off_detect = 1'b1;
                2'd3: pixel_rst  = 1'b1;
                default: ; // State 0 (IDLE) stays safely quiet
            endcase
        end
    end

    // -----------------------------------------------------------------
    // SEQUENTIAL STATE TRACKER (Transitions safely on POSEDGE)
    // -----------------------------------------------------------------
    always_ff @(posedge div_clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= 2'd0; // Reset to IDLE
            sm_next_row <= 1'b0;
            row_ctr     <= 6'd0;
        end
        else begin
            if (sm_enable) begin
                case (state)
                    2'd0: begin // IDLE -> ON (First active clock edge)
                        state       <= 2'd1;
                        sm_next_row <= 1'b0;
                    end
                    2'd1: begin // ON -> OFF
                        state       <= 2'd2;
                        sm_next_row <= 1'b0;
                    end
                    2'd2: begin // OFF -> RST
                        state       <= 2'd3;
                        sm_next_row <= 1'b1; // Trigger scanner shift for next posedge
                    end
                    2'd3: begin // RST -> ON (Next Row)
                        state       <= 2'd1;
                        sm_next_row <= 1'b0;
                        row_ctr     <= row_ctr + 6'd1;
                    end
                    default: begin 
                        state       <= 2'd0;
                        sm_next_row <= 1'b0;
                        row_ctr     <= 6'd0;
                    end
                endcase
            end else begin
                // Paused - maintain current operation ENTIRELY
                state       <= state;
                sm_next_row <= sm_next_row;
                row_ctr     <= row_ctr;
            end
        end
    end

endmodule : roic_sm