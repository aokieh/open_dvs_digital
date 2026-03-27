`timescale 1ns/1ps

// `include "defines.sv"
import pkg_spi_fver::*;

module tb();
    
    localparam CLK_P = 20ns;

    logic clk  = 0;
    logic rst_n = 0;
    integer log_file;
    integer image_dump_file; // NEW: File pointer for the 10-bit image reconstruction

    // Power pins
    `ifndef USE_POWER_PINS
        logic vccd1_dummy = 1'b1;
        logic vssd1_dummy = 1'b0;
    `endif

    // SPI Controller Interface
    spi_intf i_spi_intf(.CS_N(), .SCK(), .COPI(), .CIPO());
    class_spi_ctrl spi_ctrl = new (i_spi_intf);

    always #(CLK_P/2) clk = ~clk;

    // Monitor CIPO out to log file
    always @(negedge i_spi_intf.SCK) begin
        if (!i_spi_intf.CS_N) $fwrite(log_file, "%0t, %b\n", $time, i_spi_intf.CIPO);
    end

    //---------------------------------------------------
    // NEW: Reconstructed 10-bit Image monitor
    //---------------------------------------------------
    logic [9:0] shift_reg_0, shift_reg_1, shift_reg_2, shift_reg_3;
    integer bit_idx = 0;

    always @(posedge i_spi_intf.SCK) begin
        // Only sample when CS_N is low and we are in continuous read mode (Opcode 111)
        if (!i_spi_intf.CS_N && i_dut.i_spi_peripheral.opcode_valid == 3'b111) begin
            
            // Shift data in (MSB first)
            shift_reg_0 <= {shift_reg_0[8:0], i_spi_intf.CIPO[0]};
            shift_reg_1 <= {shift_reg_1[8:0], i_spi_intf.CIPO[1]};
            shift_reg_2 <= {shift_reg_2[8:0], i_spi_intf.CIPO[2]};
            shift_reg_3 <= {shift_reg_3[8:0], i_spi_intf.CIPO[3]};
            
            bit_idx <= bit_idx + 1;

            // Once we collect 10 bits, dump to file and reset
            if (bit_idx == 9) begin
                $fwrite(image_dump_file, "%03h  %03h  %03h  %03h\n", 
                    {shift_reg_3[8:0], i_spi_intf.CIPO[3]}, 
                    {shift_reg_2[8:0], i_spi_intf.CIPO[2]}, 
                    {shift_reg_1[8:0], i_spi_intf.CIPO[1]}, 
                    {shift_reg_0[8:0], i_spi_intf.CIPO[0]}
                );
                bit_idx <= 0;
            end
        end else begin
            bit_idx <= 0;
        end
    end

    //---------------------------------------------------
    // DUT Interconnects & Test Variables
    //---------------------------------------------------
    logic [3:0] data_req = '0;
    logic [3:0] data_ack;
    logic [9:0] wdata_0, wdata_1, wdata_2, wdata_3;
    
    // Regfile Outputs
    logic we_out;
    logic [9:0] irq_deassert_thresh_reg;
    logic [9:0] irq_assert_thresh_reg;
    logic [11:0] dac_config_0, dac_config_1, dac_config_2, dac_config_3;
    logic [11:0] dac_config_4, dac_config_5, dac_config_6, dac_config_7;
    logic [23:0] bias_0, bias_1, bias_2, bias_3;

    // Registers for error checking & random sequence generation
    logic [11:0] dac_write_data     [7:0];
    logic [23:0] bias_write_data    [3:0];
    logic [11:0] irq_deassert_write_val = $random & 12'h3FF;
    logic [11:0] irq_assert_write_val   = $random & 12'h3FF;

    // Add memory arrays at the top of your testbench or inside the initial block
    logic [7:0] ch0_mem [0:511];
    logic [7:0] ch1_mem [0:511];
    logic [7:0] ch2_mem [0:511];
    logic [7:0] ch3_mem [0:511];

    //---------------------------------------------------
    // DUT Instantiation
    //---------------------------------------------------
    spi_async_fifo_regfile i_dut (
        `ifdef USE_POWER_PINS
            .vccd1(vccd1_dummy),
            .vssd1(vssd1_dummy),
        `endif
        
        .clk(clk), .rst_n(rst_n),
        .CS_N(i_spi_intf.CS_N), .SCK(i_spi_intf.SCK), .COPI(i_spi_intf.COPI), .CIPO(i_spi_intf.CIPO),
        
        // Async FIFO Data
        .data_req(data_req), .data_ack(data_ack),
        .wdata_0(wdata_0), .wdata_1(wdata_1), .wdata_2(wdata_2), .wdata_3(wdata_3),
        
        // Regfile connections
        .event_rate_reg(10'd0), // Tied off inputs
        .we_out(we_out),
        .irq_deassert_thresh_reg(irq_deassert_thresh_reg),
        .irq_assert_thresh_reg(irq_assert_thresh_reg),
        .dac_config_0(dac_config_0), .dac_config_1(dac_config_1), .dac_config_2(dac_config_2), .dac_config_3(dac_config_3),
        .dac_config_4(dac_config_4), .dac_config_5(dac_config_5), .dac_config_6(dac_config_6), .dac_config_7(dac_config_7),
        .bias_0(bias_0), .bias_1(bias_1), .bias_2(bias_2), .bias_3(bias_3)
    );

    //---------------------------------------------------
    // Regfile Verification Tasks
    //---------------------------------------------------

    task automatic pulse_fifo_rst_n(input logic [3:0] val);
        spi_ctrl.trans(WRITE_BT, 1, val);
        #CLK_P;
    endtask

    task automatic set_irq(input logic [11:0] deassert_val, input logic [11:0] assert_val, input logic mode_read);
        spi_ctrl.trans(WRITE_HW, 12, deassert_val);
        #CLK_P;
        spi_ctrl.trans(WRITE_HW, 14, assert_val);
        #CLK_P;
        if(mode_read) begin
            spi_ctrl.trans(READ_HW, 12, 0, deassert_val);
            #CLK_P;
            spi_ctrl.trans(READ_HW, 14, 0, assert_val);
            #CLK_P;
        end 
    endtask

    task automatic write_dacs(input logic [11:0] val, input logic mode_read);
        for (int i = 0; i < `NUM_DACS; i++) begin
            spi_ctrl.trans(WRITE_HW, i*2 + 20, val);
            dac_write_data[i] = val;
            #CLK_P;
        end
        if (mode_read) begin
            for (int i = 0; i < `NUM_DACS; i++) begin
                spi_ctrl.trans(READ_HW, i*2 + 20, 0, val);
                #CLK_P;
            end
        end
    endtask

    task automatic read_dacs(input logic [11:0] val);
        for (int i = 0; i < `NUM_DACS; i++) begin
            spi_ctrl.trans(WRITE_HW, i*2 + 20, val+i);
            dac_write_data[i] = val;
            #CLK_P;
        end
        for (int i = 0; i < `NUM_DACS; i++) begin
            spi_ctrl.trans(READ_HW, i*2 + 20, 0, val+i);
            #CLK_P;
        end
    endtask

    task automatic write_dacs_seq();
        for (int i = 0; i < 10; i++) begin
            spi_ctrl.trans(WRITE_HW, i*2 + 20, 'h5aa + i);
            dac_write_data[i] = 'h5aa + i;
            #CLK_P;
        end
    endtask

    task automatic write_biases(input logic [3:0] start_val, input logic is_uniform, input logic mode_read);
        logic [3:0] digit;
        logic [23:0] bias_val;
        for (int i = 0; i < `NUM_BIASES; i++) begin
            if (is_uniform) digit = start_val;
            else            digit = (start_val + i) & 4'hF;
            
            bias_val = {6{digit}};
            spi_ctrl.trans(WRITE_WD, 112 + i*4, bias_val);
            bias_write_data[i] = bias_val;
            $display("Bias[%0d] write = %06h", i, bias_val);
            #CLK_P;
        end

        for (int i = 0; i < `NUM_BIASES; i++) begin
            if(mode_read) begin
                if (is_uniform) digit = start_val;
                else            digit = (start_val + i) & 4'hF;
                
                bias_val = {6{digit}};
                spi_ctrl.trans(READ_WD, 112 + i*4, 0, bias_val);
                bias_write_data[i] = bias_val;
                $display("Bias[%0d] read expected = %06h", i, bias_val);
                #CLK_P;
            end
        end
    endtask

    //---------------------------------------------------
    // FIFO Verification Tasks
    //---------------------------------------------------

    task automatic write_data(int num = 0); //write to all FIFO addresses
        // Write a bunch of data to the FIFO
        $display("\nWriting a bunch of data to the FIFO...");

        for (int i = 0; i < num; i++) begin
            @(posedge clk);
            #2.5ns; //off cycle to see synchronization
            data_req = 4'b1111;

            // Assigning data to the bus
            wdata_0 = {$urandom()};
            wdata_1 = {$urandom()};
            wdata_2 = {$urandom()};
            wdata_3 = {$urandom()};

            // Wait for the ack
            wait(data_ack == 4'b1111);

            @(posedge clk);
            data_req = 4'b0000;

            // Wait for the data_ack to reset
            #(3 * CLK_P);
        end

        $display("\n...... Completed writing to FIFO ......");
    endtask : write_data

    task automatic write_async_imager_frames(int num_rows, int base_delay_ns);
        int total_words;
        int words_sent [3:0];
        int row [3:0];
        int word [3:0];
        
        logic sof [3:0];
        logic sor [3:0];
        logic [7:0] data_val [3:0]; // WIDENED to 8 bits for real pixel data
        logic [3:0] req_mask;
        
        total_words = num_rows * 8;
        words_sent = '{0, 0, 0, 0};
        
        $display("\n[IMAGER] Starting Fully Asynchronous %0d-row Transmission...", num_rows);
        
        while (words_sent[0] < total_words || words_sent[1] < total_words || 
               words_sent[2] < total_words || words_sent[3] < total_words) begin
            
            req_mask = 4'b0000;
            
            for (int i = 0; i < 4; i++) begin
                if (words_sent[i] < total_words) begin
                    if (($urandom() % 10) < 8) begin // 20% asynchronous lag
                        req_mask[i] = 1'b1;
                        
                        row[i]  = words_sent[i] / 8;
                        word[i] = words_sent[i] % 8;
                        
                        sof[i] = (row[i] % 64 == 0 && word[i] == 0);
                        sor[i] = (word[i] == 0);
                        
                        // FETCH REAL DATA FROM THE PYTHON ARRAYS (modulo 512 for multi-frame loops)
                        case (i)
                            0: data_val[0] = ch0_mem[words_sent[0] % 512];
                            1: data_val[1] = ch1_mem[words_sent[1] % 512];
                            2: data_val[2] = ch2_mem[words_sent[2] % 512];
                            3: data_val[3] = ch3_mem[words_sent[3] % 512];
                        endcase
                        
                        // Pack into exactly 10 bits {SOF, SOR, 8-bit PIXELS}
                        case (i)
                            0: wdata_0 = {sof[0], sor[0], data_val[0]};
                            1: wdata_1 = {sof[1], sor[1], data_val[1]};
                            2: wdata_2 = {sof[2], sor[2], data_val[2]};
                            3: wdata_3 = {sof[3], sor[3], data_val[3]};
                        endcase
                        
                        words_sent[i]++;
                    end
                end
            end
            
            if (req_mask != 4'b0000) begin
                
                // PHASE 1: Delay and Assert Request
                // By removing @(posedge clk), the 2.5ns offset perfectly 
                // forces the req to hit the CDC synchronizers mid-cycle. 
                #((base_delay_ns * 1ns) + 2.5ns); 
                data_req = req_mask;
                
                // PHASE 2: Wait for Acknowledge to go HIGH
                wait((data_ack & req_mask) == req_mask);
                
                // PHASE 3: De-assert Request
                // A tiny 1ns delay mimics physical gate propagation and avoids 
                // zero-time simulator glitches before dropping the line.
                #1ns;
                data_req = 4'b0000;
                
                // PHASE 4: Wait for Acknowledge to go LOW (The Missing Link)
                // This guarantees the FIFO's state machine has fully reset 
                // before we allow the loop to blast the next pixel at it.
                wait((data_ack & req_mask) == 4'b0000);
                
            end else begin
                // If no channels fired this loop, just advance time to avoid hanging
                #(base_delay_ns * 1ns);
            end
        end
        $display("[IMAGER] Asynchronous Transmission Complete.");
    endtask : write_async_imager_frames

    //---------------------------------------------------
    // Main Test Sequence
    //---------------------------------------------------
    initial begin

// Load the Python-generated Hex files using absolute paths
        // $readmemh("/LinuxRAID/home/aokieh1/projects/open_dvs_digital/fver/spi_async_fifo_reg/python/ch0_data.txt", ch0_mem);
        // $readmemh("/LinuxRAID/home/aokieh1/projects/open_dvs_digital/fver/spi_async_fifo_reg/python/ch1_data.txt", ch1_mem);
        // $readmemh("/LinuxRAID/home/aokieh1/projects/open_dvs_digital/fver/spi_async_fifo_reg/python/ch2_data.txt", ch2_mem);
        // $readmemh("/LinuxRAID/home/aokieh1/projects/open_dvs_digital/fver/spi_async_fifo_reg/python/ch3_data.txt", ch3_mem);

        $readmemh("/LinuxRAID/home/aokieh1/projects/open_dvs_digital/fver/spi_async_fifo_reg/python/ch0_papa.txt", ch0_mem);
        $readmemh("/LinuxRAID/home/aokieh1/projects/open_dvs_digital/fver/spi_async_fifo_reg/python/ch1_papa.txt", ch1_mem);
        $readmemh("/LinuxRAID/home/aokieh1/projects/open_dvs_digital/fver/spi_async_fifo_reg/python/ch2_papa.txt", ch2_mem);
        $readmemh("/LinuxRAID/home/aokieh1/projects/open_dvs_digital/fver/spi_async_fifo_reg/python/ch3_papa.txt", ch3_mem);

        log_file = $fopen("spi_cipo_monitor.txt", "w");
        image_dump_file = $fopen("imager_reconstruction.txt", "w"); // NEW: Open the 10-bit reconstruction file
        $fwrite(image_dump_file, "CH3  CH2  CH1  CH0\n");           // NEW: Write the header for the python parser
        
        spi_ctrl.init();

        #(10*CLK_P); rst_n = 1;
        #(10*CLK_P); rst_n = 0;
        #(10*CLK_P); rst_n = 1;
        #(5*CLK_P);

        $display("\n==================================================");
        $display("   PHASE 1: Register File Integrity Verification");
        $display("==================================================");

        // ---------------- Write all ones ------------------------
        pulse_fifo_rst_n('hf);
        set_irq('hfff, 'hfff, 0);
        write_dacs('hfff, 0);
        write_biases(4'hf, 1, 0);
        #500ns;

        // ---------------- Write all zeros -----------------------
        pulse_fifo_rst_n('h0);
        set_irq('h000, 'h000, 0);
        write_dacs('h000, 0);
        write_biases(4'h0, 1, 0);
        #500ns;

        // ---------------- Write sequence data -------------------
        write_dacs_seq();
        write_biases(4'ha, 0, 0);              // starts A, increments
        set_irq('h2AA, 'h2AA, 0);
        #500ns;

        // ---------------- Read and dump comparison --------------
        // Read Chip ID
        spi_ctrl.trans(READ_BT, 0, 0, 'h55);
        #CLK_P;

        set_irq(irq_deassert_write_val, irq_assert_write_val, 1);
        read_dacs('h100);   // writes consecutive data to dacs & reads
        write_biases(4'h3, 0, 1);  // write and read beginning at 333333
        
        #500ns;

        $display("\n====================================================");
        $display("   PHASE 2: Asynchronous Imager Starvation Test");
        $display("====================================================");
        
        pulse_fifo_rst_n('hf); 
        #100ns;


        // Run the Imager and the SPI Controller SIMULTANEOUSLY
        fork
            // THREAD 1: SPI Controller Readout
            // Reading 1000 words to capture 520 valid pixels + the ~300 words of 3AA padding
            // caused by the 500ns imager base delay and the 20% random asynchronous lag.
            begin
                $display("[SPI] Starting Continuous Read for Full Frame...");
                spi_ctrl.trans(READ_FIFO, 0, 1000);
                $display("[SPI] Continuous Read Complete.");
            end
            
            // THREAD 2: Imager Event Generation
            begin
                write_async_imager_frames(65, 78); //200.5 ns
            end
        join

        #1500ns; // Let any final SPI transactions settle

        $fclose(log_file);
        if (image_dump_file) $fclose(image_dump_file);
        $display("\n\nSimulation Complete. The full frame is in 'imager_reconstruction.txt'!");

        $stop;
    end

endmodule : tb