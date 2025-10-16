
// Memory map: read/write configuration
`define mem_map(signal, byte_addr) \
    begin \
        int __row, __lsb; \
        __row = (byte_addr) >> ROW_DIV; \
        __lsb = (byte_addr) % `LSB_DIV; \
        signal = mem_in[__row][8*__lsb +: $bits(signal)]; \
        mem_out[__row][8*__lsb +: $bits(signal)] = signal; \
    end

// Memory map: read-only configuration
`define mem_map_ro(signal, byte_addr) \
    begin \
        int __row, __lsb; \
        __row = (byte_addr) >> ROW_DIV; \
        __lsb = (byte_addr) % `LSB_DIV; \
        mem_out[__row][8*__lsb +: $bits(signal)] = signal; \
    end

// Memory map: pulse on write - LEAST SIG BYTE
`define mem_map_pulse(signal, row, lsb) \
    signal <= 0; \
    if (we && (addr==row) && wmask[lsb]) \
	    signal <= 1;



module regfile (
    input  logic                  clk,
    input  logic                  rst_n,

    // Memory Interface (SPI <-> Mem)
    input  logic [`RF_AWIDTH-1:0] addr,
    input  logic                  we,
    input  logic [ `RF_WIDTH-1:0] wdata,
    input  logic [  `RF_MASK-1:0] wmask,
    output logic [ `RF_WIDTH-1:0] rdata,

    // FIFO
    output logic                    fifo_rst_n,
    // input  logic                    fifo_empty,
    // input  logic                    fifo_full,
    output logic                    fifo_rd_en,
    input  logic [`FIFO_AWIDTH-1:0] fifo_numel,
    // input  logic [ `FIFO_WIDTH-1:0] fifo_rdata,

    // IRQ
    output logic [9:0] irq_deassert_thresh,
    output logic [9:0] irq_assert_thresh,

    // DAC
    output logic [`DAC_WIDTH-1:0] dac_config [`NUM_DACS],

    //TEST ADDITIONAL PORTS
    output logic [23:0] bias [4],
    input logic [9:0] event_rate
);

    logic [`RF_WIDTH-1:0] mem_in  [`RF_DEPTH];
    logic [`RF_WIDTH-1:0] mem_out [`RF_DEPTH];

    localparam ROW_DIV = $clog2(`LSB_DIV);


    //---------------------------------------------------------------
    // RW/RO Mappings
    //---------------------------------------------------------------
    always_comb begin
        foreach(mem_out[i])
            mem_out[i] = '0;

        mem_out[0][7:0] = `CHIP_ID; // Hardwired RF ID

        // FIFO
        // `mem_map_ro(fifo_empty, 2)
        // `mem_map_ro(fifo_full,  3)
        `mem_map_ro(fifo_numel, 4)
        // `mem_map_ro(fifo_rdata, 8)
        
        // IRQ
        `mem_map(irq_deassert_thresh, 12)
        `mem_map(irq_assert_thresh, 14)

        // DACs - TODO: insert proper DAC addresses
        for (int i = 0; i < `NUM_DACS; i++) begin
            `mem_map(dac_config[i], i*2 + 20)
        end

        // TEST ADDITIONAL SIGNALS
        // biases
        for (int i = 0; i < `NUM_BIASES; i++) begin
            `mem_map(bias[i], i*4 + 112) //incrementing 4 bytest per bias
        end

        //INTERNAL EVENT RATE
        `mem_map_ro(event_rate, 108) //addressing byte 

    end


    //---------------------------------------------------------------
    // Pulsed Mappings
    //---------------------------------------------------------------
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            fifo_rd_en <= 0;
            fifo_rst_n <= 0;
        end 
        else begin
            `mem_map_pulse(fifo_rst_n, 0, 1)
            `mem_map_pulse(fifo_rd_en, 2, 0)
        end
    end


    //---------------------------------------------------------------
    // Write data
    //---------------------------------------------------------------
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            foreach (mem_in[i])
                mem_in[i] <= '0;
        end 
        else begin
            if (we) begin
                foreach (wmask[i]) begin
                    if (wmask[i]) 
                        mem_in[addr][i*8 +: 8] <= wdata[i*8 +: 8];
                end
            end
        end
    end

    
    //---------------------------------------------------------------
    // Read data
    //---------------------------------------------------------------
    always_comb begin
        rdata <= mem_out[addr];	
    end
    
endmodule : regfile


`undef mem_map

`undef mem_map_ro

`undef mem_map_pulse