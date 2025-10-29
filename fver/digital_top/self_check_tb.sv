`timescale 1ns/1ps
import pkg_spi_fver::*;

module tb ();

    localparam CLK_P = 25ns;
    localparam DEPTH = 8;
    localparam DEASSERT_THRESH = 11;
    localparam ASSERT_THRESH   = 789;

    logic clk  = 0;
    logic rst_n = 0;

    // SPI Interface
    logic CS_N;
    logic SCK;
    logic [3:0] COPI;
    logic [3:0] CIPO;

    // Regfile interface
    logic [`BIAS_WIDTH-1:0] biases [`NUM_BIASES-1:0];    
    logic [`DAC_WIDTH-1:0] dac_configs [`NUM_DACS-1:0];

    // some are removable signals that we aren't using (in the end)
    logic                        we_out;
    logic [`FIFO_AWIDTH-1:0]     irq_assert_thresh;
    logic [`FIFO_AWIDTH-1:0]     irq_deassert_thresh;
    logic [`FIFO_AWIDTH-1:0]     fifo_numel;
    logic                        fifo_rd_en;
    logic                        fifo_rst_n;
    logic [3:0]                  digit;


    // TODO (REMOVE?): Ports on behavioral models, gave us issues?
    supply1 VDD; // Ideal 1 (Power Source)
    supply0 VSS; // Ideal 0 (Ground Source)
    wire vccd1; // Core Power Net (VCC)
    wire vssd1; // Core Ground Net (VSS)
    // assign VPB   = VDD; // Tie P-Well bias (VPB) to VDD
    // assign VNB   = VSS; // Tie N-Well bias (VNB) to VSS

    assign vccd1 = VDD;
    assign vssd1 = VSS;

    // Registers for error checking
    logic [11:0] dac_write_data     [0:7];
    logic [11:0] dac_read_data      [0:7];

    logic [23:0] bias_write_data    [0:3];
    logic [23:0] bias_read_data     [0:3];

    spi_intf i_spi_intf(
        .CS_N,
        .SCK ,
        .COPI,
        .CIPO
    );

    class_spi_ctrl spi_ctrl = new (i_spi_intf);

    always #(CLK_P/2) clk = ~clk;

    digital_top i_digital_top (
        .clk         (clk),
        .rst_n       (rst_n),
        .vccd1       (vccd1),
        .vssd1       (vssd1),
        .CS_N        (CS_N),
        .SCK         (SCK),
        .COPI        (COPI),
        .CIPO        (CIPO),
        .bias_0      (biases[0]),
        .bias_1      (biases[1]),
        .bias_2      (biases[2]),
        .bias_3      (biases[3]),
        .we_out      (we_out),
        .dac_config_0(dac_configs[0]),
        .dac_config_1(dac_configs[1]),
        .dac_config_2(dac_configs[2]),
        .dac_config_3(dac_configs[3]),
        .dac_config_4(dac_configs[4]),
        .dac_config_5(dac_configs[5]),
        .dac_config_6(dac_configs[6]),
        .dac_config_7(dac_configs[7]),
        .irq_assert_thresh(irq_assert_thresh),
        .irq_deassert_thresh(irq_deassert_thresh),
        .fifo_numel        (fifo_numel),
        .fifo_rd_en        (fifo_rd_en),
        .fifo_rst_n        (fifo_rst_n)
    );

    // ---------------- Tasks and Verification Sequences ------------------

    task automatic pulse_fifo_rst_n(input logic [3:0] val);
        spi_ctrl.trans(WRITE_BT, 1, val);
        #CLK_P;
    endtask

    task automatic set_irq(input logic [11:0] deassert_val, input logic [11:0] assert_val);
        spi_ctrl.trans(WRITE_HW, 12, deassert_val);
        #CLK_P;
        spi_ctrl.trans(WRITE_HW, 14, assert_val);
        #CLK_P;
    endtask

    task automatic write_dacs(input logic [11:0] val);
        for (int i = 0; i < `NUM_DACS; i++) begin
            spi_ctrl.trans(WRITE_HW, i*2 + 20, val);
            dac_write_data[i] = val;
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

    task automatic write_biases(input logic [3:0] start_val, input logic is_uniform);
        logic [3:0] digit;
        logic [23:0] bias_val;
        for (int i = 0; i < `NUM_BIASES; i++) begin
            if (is_uniform)
                digit = start_val;
            else
                digit = (start_val + i) & 4'hF;

            bias_val = {6{digit}};
            spi_ctrl.trans(WRITE_WD, 112 + i*4, bias_val);
            bias_write_data[i] = bias_val;
            $display("Bias[%0d] write = %06h", i, bias_val);
            #CLK_P;
        end
    endtask
    // TODO: create task read_and_check, but is strongly test dependent

    // --------------------- Test Sequence ------------------------------
    initial begin
        spi_ctrl.init();

        // Reset sequence
        #(10*CLK_P); rst_n = 1;
        #(10*CLK_P); rst_n = 0;
        #(10*CLK_P); rst_n = 1;
        #(5*CLK_P);

        // Read Chip ID
        spi_ctrl.trans(READ_BT, 0, 0, 'h55);
        #CLK_P;

        // ---------------- Write all ones ------------------------
        pulse_fifo_rst_n('hf);
        set_irq('hfff, 'hfff);
        write_dacs('hfff);
        write_biases(4'hf, 1);
        #500ns;

        // ---------------- Write all zeros -----------------------
        pulse_fifo_rst_n('h0);
        set_irq('h000, 'h000);
        write_dacs('h000);
        write_biases(4'h0, 1);
        #500ns;

        // ---------------- Write sequence data -------------------
        write_dacs_seq();
        write_biases(4'ha, 0); // starts A, increments
        #500ns;

        // ---------------- Read and dump comparison --------------
        spi_ctrl.trans(READ_HW, 12, 0, DEASSERT_THRESH);
        #CLK_P;
        spi_ctrl.trans(READ_HW, 14, 0, ASSERT_THRESH);
        #CLK_P;

        for (int i = 0; i < `NUM_DACS; i++) begin
            spi_ctrl.trans(READ_HW, i*2 + 20, 0, dac_write_data[i]);
            #CLK_P;
        end

        for (int i = 0; i < `NUM_BIASES; i++) begin
            spi_ctrl.trans(READ_WD, 112 + i*4, bias_write_data[i], bias_write_data[i]);
            #CLK_P;
        end

        #300ns;
        $stop;
    end

endmodule : tb