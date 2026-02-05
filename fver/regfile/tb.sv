`timescale 1ns/1ps

module tb ();

    localparam CLK_P = 5ns;

    // Memory Interface
    logic                  clk  = 0;
    logic                  rst_n = 0;
    logic                  we;
    logic [`RF_AWIDTH-1:0] addr;
    logic [ `RF_WIDTH-1:0] wdata;
    logic [  `RF_MASK-1:0] wmask = '1;
    logic [ `RF_WIDTH-1:0] rdata;

    // FIFO
    logic                    fifo_rst_n;
    logic                    fifo_rd_en;
    logic [`FIFO_AWIDTH-1:0] fifo_numel = 15;

    // IRQ
    logic [`FIFO_AWIDTH-1:0] irq_deassert_thresh;
    logic [`FIFO_AWIDTH-1:0] irq_assert_thresh;

    // DAC
    logic [`DAC_WIDTH-1:0] dac_config [`NUM_DACS];


    //TB added 
    logic [ `RF_WIDTH-1:0] temp_data;

    //TEST ADDITIONAL PORTS
    logic [23:0] bias [`NUM_BIASES];//added code
    logic [9:0] event_rate;         //added code

    always #(CLK_P/2) clk = ~clk;

    regfile i_regfile (
        .clk,
        .rst_n,
        .we_reg(we),
        .addr_reg(addr),
        .wdata_reg(wdata),
        .wmask_reg(wmask),
        .rdata_reg(rdata),

        .fifo_rst_n_reg(fifo_rst_n),
        .fifo_rd_en_reg(fifo_rd_en),
        .fifo_numel_reg(fifo_numel),
        
        .irq_deassert_thresh_reg(irq_deassert_thresh),
        .irq_assert_thresh_reg(irq_assert_thresh),

                // DAC outputs - connect individually
        .dac_config_0       (dac_config[0]),
        .dac_config_1       (dac_config[1]),
        .dac_config_2       (dac_config[2]),
        .dac_config_3       (dac_config[3]),
        .dac_config_4       (dac_config[4]),
        .dac_config_5       (dac_config[5]),
        .dac_config_6       (dac_config[6]),
        .dac_config_7       (dac_config[7]),

        // Bias outputs
        .bias_0             (bias[0]),
        .bias_1             (bias[1]),
        .bias_2             (bias[2]),
        .bias_3             (bias[3]),

        // .dac_config_reg(dac_config),
        // .bias_reg(bias),              //added code    
        .event_rate_reg(event_rate)          //added code
    );


    initial begin
        addr = 0;
        we = 0;
        wdata = 0;
        rst_n = 0;
        #10ns;
        rst_n = 1;

        #25ns;

        $display("\nTesting regular register writes...");
        $display("===================================\n");
        test_reg_writes();
        
        $display("\nTesting mapped register writes...");
        $display("===================================\n");
        test_mapped_writes();

        #100ns;

        $finish;
    end


    task automatic write_mem(int address, int data, logic [3:0] mask = '1);
        addr = address;
        we = 1;
        wdata = data;
        wmask = mask;
        #CLK_P;

        we = 0;
        #CLK_P;
    endtask : write_mem


    task automatic read_mem(int address);
        addr = address;
        we = 0;
        #CLK_P;
    endtask : read_mem


    task automatic test_reg_writes();
        for (int i = 0; i < `RF_DEPTH; i++) begin
            write_mem(i, 1 << i);
        end

        for (int i = 0; i < `RF_DEPTH; i++) begin
            $display("addr: %2d, rdata: %d", i, i_regfile.mem_in[i]);

            if (i_regfile.mem_in[i] !== (1 << i)) begin
                $error("Register write failed at addr %0d: expected %0d, got %0d", i, (1 << i), i_regfile.mem_in[i]);
            end
        end
    endtask : test_reg_writes


    task automatic test_mapped_writes();
        // Read Chip ID
        addr = 0;
        we = 0;
        #CLK_P;

        assert (rdata[7:0] == `CHIP_ID)
        else 
            $error("Chip ID read failed: expected %0d, got %0d", `CHIP_ID, rdata[7:0]);


        // FIFO reset
        write_mem(0, 1 << 1*8, 2);
        read_mem(0);


        //write to event counter address
        // write_mem(27, {16'h00, 16'h3FF}, '1); //invalid write
        // addr = 27;
        event_rate = 'h3FF;
        read_mem(27);  //reading data at internal event_rate ROM


        //write to dacs
        // write_mem((4+1), {32'hffff_ffff}, '1); // test write: hex bits x000_x000 DNE!
        write_mem(5, {32'h0000_0101}, '1);
        $display("\nData in mem[%d] = %0h, expected 101, current mask = %d", addr, rdata, wmask);

        write_mem(5, {32'h0102_0101}, '1);
        $display("\nData in mem[%d] = %0h, expected 102, current mask = %d", addr, rdata, wmask);

        write_mem(6, {32'h0000_0103}, '1);
        $display("\nData in mem[%d] = %0h, expected 103, current mask = %d", addr, rdata, wmask);

        write_mem(6, {32'h0104_0103}, '1);
        $display("\nData in mem[%d] = %0h, expected 104, current mask = %d", addr, rdata, wmask);

        write_mem(7, {32'h0000_0105}, '1);
        $display("\nData in mem[%d] = %0h, expected 105, current mask = %d", addr, rdata, wmask);

        write_mem(7, {32'h0106_0105}, '1);
        $display("\nData in mem[%d] = %0h, expected 106, current mask = %d", addr, rdata, wmask);

        write_mem(8, {32'h0000_0107}, '1);
        $display("\nData in mem[%d] = %0h, expected 107, current mask = %d", addr, rdata, wmask);

        write_mem(8, {32'h0108_0107}, '1);
        $display("\nData in mem[%d] = %0h, expected 108, current mask = %d", addr, rdata, wmask);


        //write to biases
        write_mem(28, {8'h00, 24'hAAA}, '1);
        $display("\nData in mem[%d] = %0h, expected aaa, current mask = %d", addr, rdata, wmask);

        write_mem(29, {8'h00, 24'hBBB}, '1);
        $display("\nData in mem[%d] = %0h, expected bbb, current mask = %d", addr, rdata, wmask);

        write_mem(30, {8'h00, 24'hCCC}, '1);
        $display("\nData in mem[%d] = %0h, expected ccc, current mask = %d", addr, rdata, wmask);

        write_mem(31, {8'h00, 24'hDDD}, '1);
        $display("\nData in mem[%d] = %0h, expected ddd, current mask = %d", addr, rdata, wmask);

        // $display("\nData in mem[%d] = %0h, expected ddd, current mask = %d", addr, rdata, wmask);
        // assert(fifo_rst_n == 1)
        // else
            // $error("FIFO reset write/read failed: expected 1, got %0d", fifo_rst_n);


        // FIFO numel read
        read_mem(1);
        assert (rdata == fifo_numel)
        else
            $error("FIFO numel read failed: expected %0d, got %0d", fifo_numel, rdata);

        
        #50ns;
        write_mem(2, 0);
    endtask : test_mapped_writes

endmodule : tb
