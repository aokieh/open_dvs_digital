//---------------------------------------------------------------------------
// Author: Kwesi Buabeng Debrah
// Date  : Apr 24, 2025
//
// Module: sram_resetter
//
// Description: 
//  FSM that resets SRAM contents to 0 when enabled and triggers an interrupt 
//  when done.
//  It uses both ports to achieve 2x speed.
//---------------------------------------------------------------------------


module sram_resetter #(parameter DEPTH=16) (
    sram_fifo_wrapper_intf.sram mem_intf,
    input  logic                enable,
    input  logic                irq_ack,
    output logic                rst_irq
);

    typedef enum {IDLE, BUSY, DONE} state_t;

    state_t state, next_state;

    logic [$clog2(DEPTH)-1:0] addr_a, addr_a_reg, addr_b, addr_b_reg;


    //-----------------------------------------------------------------------
    // Memory Interface Assignment
    //-----------------------------------------------------------------------
    assign mem_intf.we_a    = 1;
    assign mem_intf.we_b    = 1;

    assign mem_intf.addr_a  = addr_a_reg;
    assign mem_intf.addr_b  = addr_b_reg;

    assign mem_intf.wmask_a = '1;
    assign mem_intf.wmask_b = '1;

    assign mem_intf.wdata_a = '0;
    assign mem_intf.wdata_b = '0;


    //-----------------------------------------------------------------------
    // FSM State Register
    //-----------------------------------------------------------------------
    always_ff @(posedge mem_intf.clk, negedge mem_intf.rst_n) begin
        if (!mem_intf.rst_n) begin
            state <= IDLE;
            addr_a_reg <= 0;
            addr_b_reg <= DEPTH >> 1;  // Middle of the memory
        end
        else begin
            state <= next_state;
            addr_a_reg <= addr_a;
            addr_b_reg <= addr_b;
        end
    end


    //-----------------------------------------------------------------------
    // FSM Next State Logic
    //-----------------------------------------------------------------------
    always_comb begin
        // Default state
        next_state = state;

        // Default outputs
        addr_a = addr_a_reg;
        addr_b = addr_b_reg;

        mem_intf.ce_a = 0;
        mem_intf.ce_b = 0;

        rst_irq       = 0;


        case (state)
            IDLE: begin
                if (enable) begin
                    next_state    = BUSY;
                end
            end

            BUSY: begin
                mem_intf.ce_a = 1;
                mem_intf.ce_b = 1;

                addr_a = addr_a + 1;
                addr_b = addr_b + 1;

                if (addr_a == (DEPTH>>1)) begin
                    next_state = DONE;
                end
            end

            DONE: begin
                // Trigger interrupt
                rst_irq = 1;
                
                // Wait for interrupt acknowledge
                if (irq_ack) begin
                    rst_irq = 0;
                    next_state  = IDLE;
                end
            end
        endcase
    end


endmodule : sram_resetter
