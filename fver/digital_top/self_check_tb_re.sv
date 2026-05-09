`timescale 1ns/1ps
import pkg_spi_fver::*;

module tb ();

    localparam CLK_P = 20ns;
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
    // logic                        we_out;
    // logic [`FIFO_AWIDTH-1:0]     irq_assert_thresh;
    // logic [`FIFO_AWIDTH-1:0]     irq_deassert_thresh;
    // logic [`FIFO_AWIDTH-1:0]     fifo_numel;
    // logic                        fifo_rd_en;
    logic                        fifo_rst_n_reg;
    logic [3:0]                  digit;

    // FSM PULSE REGISTERS
    logic         fsm_rst_n_reg;
    logic [13:0]  p_pre_charge;
    logic [13:0]  p_buffer;
    logic [13:0]  p_detect;
    logic [13:0]  p_on_detect;
    logic [13:0]  p_off_detect;
    logic [13:0]  p_rst;

    // FINE & COARSE DAC REGISTERS
    logic [`FINE_CODE_WIDTH-1:0] fine_codes [`NUM_FINE_CODES];
    logic [`nFINE_CODE_WIDTH-1:0] nfine_codes [`NUM_nFINE_CODES];
    logic [`COARSE_CODE_WIDTH-1:0] coarse_one_hot_codes [`NUM_COARSE_CODES];

    // NEW BIAS REGISTERS
    logic [`BIAS_COMBINED_WIDTH-1:0] LowBiasInterfaceEn;
    logic [`BIAS_COMBINED_WIDTH-1:0] nLowBiasInterfaceEn;
    logic [`BIAS_COMBINED_WIDTH-1:0] CoarseOneHotLowBiasEn;
    logic [`BIAS_COMBINED_WIDTH-1:0] LowBiasBuffEn;
    logic [`BIAS_COMBINED_WIDTH-1:0] nLowBiasBuffEn;
    logic [`BIAS_COMBINED_WIDTH-1:0] nBiasEn;
    logic [`BIAS_COMBINED_WIDTH-1:0] pBiasEn;
    logic [`BIAS_COMBINED_WIDTH-1:0] BiasEnable;
    logic [`BIAS_COMBINED_WIDTH-1:0] BiasDisable;

    // TODO (REMOVE?): Ports on behavioral models, gave us issues?
    supply1 VDD; // Ideal 1 (Power Source)
    supply0 VSS; // Ideal 0 (Ground Source)
    wire vccd1; // Core Power Net (VCC)
    wire vssd1; // Core Ground Net (VSS)
    // assign VPB   = VDD; // Tie P-Well bias (VPB) to VDD
    // assign VNB   = VSS; // Tie N-Well bias (VNB) to VSS

    assign vccd1 = VDD;
    assign vssd1 = VSS;

    //---- Registers for error checking ----
    logic [11:0] dac_write_data     [9:0];
    logic [11:0] dac_read_data      [9:0];

    logic [23:0] bias_write_data    [3:0];
    logic [23:0] bias_read_data     [3:0];

    // // Example on assigning random data to registers
    // logic [11:0] irq_deassert_write_val = $random & 10'h3FF;
    // logic [11:0] irq_assert_write_val   = $random & 10'h3FF;

    logic [7:0] fine_code_write_data     [9:0];
    logic [7:0] nfine_code_write_data    [9:0];
    logic [7:0] coarse_onehot_write_data [9:0];

    logic [7:0] fine_code_read_data      [9:0];
    logic [7:0] nfine_code_read_data     [9:0];
    logic [7:0] coarse_onehot_read_data  [9:0];

    logic [9:0]  bias_combined_write_data [8:0];
    logic [9:0]  bias_combined_read_data  [8:0];
    
    logic [13:0] fsm_write_data [5:0];
    logic [13:0] fsm_read_data  [5:0];

    spi_intf i_spi_intf(
        .CS_N,
        .SCK ,
        .COPI,
        .CIPO
    );

    class_spi_ctrl spi_ctrl = new (i_spi_intf);

    always #(CLK_P/2) clk = ~clk;

    digital_top_re i_digital_top (
        .clk         (clk),
        .rst_n       (rst_n),
        .vccd1       (vccd1),
        .vssd1       (vssd1),
        .CS_N        (CS_N),
        .SCK         (SCK),
        .COPI        (COPI),
        .CIPO        (CIPO),
        // .bias_0      (biases[0]),
        // .bias_1      (biases[1]),
        // .bias_2      (biases[2]),
        // .bias_3      (biases[3]),
        .we_out      (we_out),
        // Dummy Dac Registers
        .dac_config_0(dac_configs[0]),
        .dac_config_1(dac_configs[1]),
        .dac_config_2(dac_configs[2]),
        .dac_config_3(dac_configs[3]),
        .dac_config_4(dac_configs[4]),
        .dac_config_5(dac_configs[5]),
        .dac_config_6(dac_configs[6]),
        .dac_config_7(dac_configs[7]),
        .dac_config_8(dac_configs[8]),
        .dac_config_9(dac_configs[9]),

        // Internal reset pulses - MUST BE INVERTED
        .fsm_rst_n_reg,
        .fifo_rst_n_reg,

        // Interfacing with FIFO
        .shift_en_fifo(),
        .rdata_spi_0(),
        .rdata_spi_1(),

        // Programmable Timing Inputs (14-BIT TUNING)
        .p_pre_charge,           // Left open (output not routed to top)
        .p_buffer,
        .p_detect,
        .p_on_detect,
        .p_off_detect,
        .p_rst,
        
        // Rui Analog Registers
        .fine_code_0(fine_codes[0]),
        .fine_code_1(fine_codes[1]),
        .fine_code_2(fine_codes[2]),
        .fine_code_3(fine_codes[3]),
        .fine_code_4(fine_codes[4]),
        .fine_code_5(fine_codes[5]),
        .fine_code_6(fine_codes[6]),
        .fine_code_7(fine_codes[7]),
        .fine_code_8(fine_codes[8]),
        .fine_code_9(fine_codes[9]),

        .nfine_code_0(nfine_codes[0]),
        .nfine_code_1(nfine_codes[1]),
        .nfine_code_2(nfine_codes[2]),
        .nfine_code_3(nfine_codes[3]),
        .nfine_code_4(nfine_codes[4]),
        .nfine_code_5(nfine_codes[5]),
        .nfine_code_6(nfine_codes[6]),
        .nfine_code_7(nfine_codes[7]),
        .nfine_code_8(nfine_codes[8]),
        .nfine_code_9(nfine_codes[9]),

        .coarse_code_0(coarse_one_hot_codes[0]),
        .coarse_code_1(coarse_one_hot_codes[1]),
        .coarse_code_2(coarse_one_hot_codes[2]),
        .coarse_code_3(coarse_one_hot_codes[3]),
        .coarse_code_4(coarse_one_hot_codes[4]),
        .coarse_code_5(coarse_one_hot_codes[5]),
        .coarse_code_6(coarse_one_hot_codes[6]),
        .coarse_code_7(coarse_one_hot_codes[7]),
        .coarse_code_8(coarse_one_hot_codes[8]),
        .coarse_code_9(coarse_one_hot_codes[9]),

        .LowBiasInterfaceEn,
        .nLowBiasInterfaceEn,
        .CoarseOneHotLowBiasEn,
        .LowBiasBuffEn,
        .nLowBiasBuffEn,
        .nBiasEn,
        .pBiasEn,
        .BiasEnable,
        .BiasDisable
    );

    // ---------------- Tasks and Verification Sequences ------------------

    task automatic pulse_fifo_rst_n(input logic [3:0] val);
        spi_ctrl.trans(WRITE_BT, 1, val);
        #CLK_P;
    endtask

    task automatic pulse_fsm_rst_n(input logic [3:0] val);
        spi_ctrl.trans(WRITE_BT, 2, val);
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
                // dac_write_data[i] = val;
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

    task automatic write_dacs_seq(input logic [11:0] val);
        for (int i = 0; i < 10; i++) begin
            spi_ctrl.trans(WRITE_HW, i*2 + 20, val+i);
            dac_write_data[i] = val + i;
            #CLK_P;
        end
    endtask

    task automatic write_biases(input logic [3:0] start_val, input logic is_uniform, input logic mode_read);
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

        for (int i = 0; i < `NUM_BIASES; i++) begin
            if(mode_read) begin
                if (is_uniform)
                    digit = start_val;
                else
                    digit = (start_val + i) & 4'hF;
                bias_val = {6{digit}};
                spi_ctrl.trans(READ_WD, 112 + i*4, 0, bias_val);
                bias_write_data[i] = bias_val;
                $display("Bias[%0d] write = %06h", i, bias_val);
                #CLK_P;
            end
        end
    endtask

    // --------------------- New Additions ------------------------------ 
    // ---------------------------------------------------------
    // 8-BIT ARRAYS (Fine, nFine, Coarse) - 1 Byte Stride
    // ---------------------------------------------------------
    task automatic write_fine(input logic [7:0] val, input logic mode_read);
        for (int i = 0; i < `NUM_FINE_CODES; i++) begin
            spi_ctrl.trans(WRITE_BT, i + 40, val);
            fine_code_write_data[i] = val;
            #CLK_P;
        end
        if (mode_read) read_fine_seq(val);
    endtask

    task automatic write_fine_seq(input logic [7:0] start_val);
        for (int i = 0; i < `NUM_FINE_CODES; i++) begin
            spi_ctrl.trans(WRITE_BT, i + 40, start_val + i);
            fine_code_write_data[i] = start_val + i;
            #CLK_P;
        end
    endtask

    task automatic read_fine_seq(input logic [7:0] expected_start_val);
        logic [7:0] val;
        for (int i = 0; i < `NUM_FINE_CODES; i++) begin
            spi_ctrl.trans(READ_BT, i + 40, 0, val);
            fine_code_read_data[i] = val;
            #CLK_P;
        end
    endtask

    task automatic write_nfine(input logic [7:0] val, input logic mode_read);
        for (int i = 0; i < `NUM_nFINE_CODES; i++) begin
            spi_ctrl.trans(WRITE_BT, i + 52, val);
            nfine_code_write_data[i] = val;
            #CLK_P;
        end
        if (mode_read) read_nfine_seq(val);
    endtask

    task automatic write_nfine_seq(input logic [7:0] start_val);
        for (int i = 0; i < `NUM_nFINE_CODES; i++) begin
            spi_ctrl.trans(WRITE_BT, i + 52, start_val + i);
            nfine_code_write_data[i] = start_val + i;
            #CLK_P;
        end
    endtask

    task automatic read_nfine_seq(input logic [7:0] expected_start_val);
        logic [7:0] val;
        for (int i = 0; i < `NUM_nFINE_CODES; i++) begin
            spi_ctrl.trans(READ_BT, i + 52, 0, val);
            nfine_code_read_data[i] = val;
            #CLK_P;
        end
    endtask

    task automatic write_coarse(input logic [7:0] val, input logic mode_read);
        for (int i = 0; i < `NUM_COARSE_CODES; i++) begin
            spi_ctrl.trans(WRITE_BT, i + 64, val);
            coarse_onehot_write_data[i] = val;
            #CLK_P;
        end
        if (mode_read) read_coarse_seq(val);
    endtask

    task automatic write_coarse_seq(input logic [7:0] start_val);
        for (int i = 0; i < `NUM_COARSE_CODES; i++) begin
            spi_ctrl.trans(WRITE_BT, i + 64, start_val + i);
            coarse_onehot_write_data[i] = start_val + i;
            #CLK_P;
        end
    endtask

    task automatic read_coarse_seq(input logic [7:0] expected_start_val);
        logic [7:0] val;
        for (int i = 0; i < `NUM_COARSE_CODES; i++) begin
            spi_ctrl.trans(READ_BT, i + 64, 0, val);
            coarse_onehot_read_data[i] = val;
            #CLK_P;
        end
    endtask

    // ---------------------------------------------------------
    // 10-BIT & 14-BIT ARRAYS (Bias, FSM) - 2 Byte Stride
    // ---------------------------------------------------------
    task automatic write_bias_combined(input logic [15:0] val, input logic mode_read);
        for (int i = 0; i < 9; i++) begin
            spi_ctrl.trans(WRITE_HW, (i*2) + 76, val);
            bias_combined_write_data[i] = val[9:0];
            #CLK_P;
        end
        if (mode_read) read_bias_combined_seq(val);
    endtask

    task automatic write_bias_combined_seq(input logic [15:0] start_val);
        for (int i = 0; i < 9; i++) begin
            spi_ctrl.trans(WRITE_HW, (i*2) + 76, start_val + i);
            bias_combined_write_data[i] = (start_val + i) & 10'h3FF;
            #CLK_P;
        end
    endtask

    task automatic read_bias_combined_seq(input logic [15:0] expected_start_val);
        logic [15:0] val;
        for (int i = 0; i < 9; i++) begin
            spi_ctrl.trans(READ_HW, (i*2) + 76, 0, val);
            bias_combined_read_data[i] = val[9:0];
            #CLK_P;
        end
    endtask

    task automatic write_fsm(input logic [15:0] val, input logic mode_read);
        for (int i = 0; i < 6; i++) begin
            spi_ctrl.trans(WRITE_HW, (i*2) + 112, val);
            fsm_write_data[i] = val[13:0];
            #CLK_P;
        end
        if (mode_read) read_fsm_seq(val);
    endtask

    task automatic write_fsm_seq(input logic [15:0] start_val);
        for (int i = 0; i < 6; i++) begin
            spi_ctrl.trans(WRITE_HW, (i*2) + 112, start_val + i);
            fsm_write_data[i] = (start_val + i) & 14'h3FFF;
            #CLK_P;
        end
    endtask

    task automatic read_fsm_seq(input logic [15:0] expected_start_val);
        logic [15:0] val;
        for (int i = 0; i < 6; i++) begin
            spi_ctrl.trans(READ_HW, (i*2) + 112, 0, val);
            fsm_read_data[i] = val[13:0];
            #CLK_P;
        end
    endtask

    task automatic check_results();
        int errors = 0;
        $display("\n--- Starting Read/Write Verification ---");

        // 1. Check DACs
        for (int i = 0; i < `NUM_DACS; i++) begin
            if (dac_read_data[i] !== dac_write_data[i]) begin
                $error("Mismatch in DAC[%0d]: Wrote %h, Read %h", i, dac_write_data[i], dac_read_data[i]);
                errors++;
            end
        end

        // 2. Check Fine Codes
        for (int i = 0; i < `NUM_FINE_CODES; i++) begin
            if (fine_code_read_data[i] !== fine_code_write_data[i]) begin
                $error("Mismatch in FineCode[%0d]: Wrote %h, Read %h", i, fine_code_write_data[i], fine_code_read_data[i]);
                errors++;
            end
        end

        // 3. Check nFine Codes
        for (int i = 0; i < `NUM_nFINE_CODES; i++) begin
            if (nfine_code_read_data[i] !== nfine_code_write_data[i]) begin
                $error("Mismatch in nFineCode[%0d]: Wrote %h, Read %h", i, nfine_code_write_data[i], nfine_code_read_data[i]);
                errors++;
            end
        end

        // 4. Check Coarse Codes
        for (int i = 0; i < `NUM_COARSE_CODES; i++) begin
            if (coarse_onehot_read_data[i] !== coarse_onehot_write_data[i]) begin
                $error("Mismatch in CoarseCode[%0d]: Wrote %h, Read %h", i, coarse_onehot_write_data[i], coarse_onehot_read_data[i]);
                errors++;
            end
        end

        // 5. Check 10-Bit Biases (9 registers)
        for (int i = 0; i < 9; i++) begin
            if (bias_combined_read_data[i] !== bias_combined_write_data[i]) begin
                $error("Mismatch in BiasCombined[%0d]: Wrote %h, Read %h", i, bias_combined_write_data[i], bias_combined_read_data[i]);
                errors++;
            end
        end

        // 6. Check 14-Bit FSM Timings (6 registers)
        for (int i = 0; i < 6; i++) begin
            if (fsm_read_data[i] !== fsm_write_data[i]) begin
                $error("Mismatch in FSM[%0d]: Wrote %h, Read %h", i, fsm_write_data[i], fsm_read_data[i]);
                errors++;
            end
        end

        // Print Final Status
        if (errors == 0) begin
            $display("========================================");
            $display("     SUCCESS: ALL REGISTERS MATCH!      ");
            $display("========================================");
        end else begin
            $display("========================================");
            $display("     FAILED: %0d MISMATCHES FOUND       ", errors);
            $display("========================================");
        end
    endtask
    // --------------------- Test Sequence ------------------------------
    initial begin
        //local sdf folder
        
                // For corner: max_ff_n40C_1v95
        // $sdf_annotate("/home/aokieh1/projects/digital_top_hardened_macro/openlane/digital_top/runs/antenna_clean/final/sdf/max_ff_n40C_1v95/digital_top__max_ff_n40C_1v95.sdf", i_digital_top);
        
                // For corner: max_ss_100C_1v60
        // $sdf_annotate("/home/aokieh1/projects/digital_top_hardened_macro/openlane/digital_top/runs/antenna_clean/final/sdf/max_ss_100C_1v60/digital_top__max_ss_100C_1v60.sdf", i_digital_top);
        
                // For corner: max_tt_025C_1v80
        // $sdf_annotate("/home/aokieh1/projects/digital_top_hardened_macro/openlane/digital_top/runs/antenna_clean/final/sdf/max_tt_025C_1v80/digital_top__max_tt_025C_1v80.sdf", i_digital_top);
        
                // For corner: min_ff_n40C_1v95
        // $sdf_annotate("/home/aokieh1/projects/digital_top_hardened_macro/openlane/digital_top/runs/antenna_clean/final/sdf/min_ff_n40C_1v95/digital_top__min_ff_n40C_1v95.sdf", i_digital_top);
        
                // For corner: min_ss_100C_1v60
        // $sdf_annotate("/home/aokieh1/projects/digital_top_hardened_macro/openlane/digital_top/runs/antenna_clean/final/sdf/min_ss_100C_1v60/digital_top__min_ss_100C_1v60.sdf", i_digital_top);
        
                // For corner: min_tt_025C_1v80
        // $sdf_annotate("/home/aokieh1/projects/digital_top_hardened_macro/openlane/digital_top/runs/antenna_clean/final/sdf/min_tt_025C_1v80/digital_top__min_tt_025C_1v80.sdf", i_digital_top);
        
                // For corner: nom_ff_n40C_1v95
        // $sdf_annotate("/home/aokieh1/projects/digital_top_hardened_macro/openlane/digital_top/runs/antenna_clean/final/sdf/nom_ff_n40C_1v95/digital_top__nom_ff_n40C_1v95.sdf", i_digital_top);
        
                // For corner: nom_ss_100C_1v60
        // $sdf_annotate("/home/aokieh1/projects/digital_top_hardened_macro/openlane/digital_top/runs/antenna_clean/final/sdf/nom_ss_100C_1v60/digital_top__nom_ss_100C_1v60.sdf", i_digital_top);
        
                // For corner: nom_tt_025C_1v80
        // $sdf_annotate("/home/aokieh1/projects/digital_top_hardened_macro/openlane/digital_top/runs/antenna_clean/final/sdf/nom_tt_025C_1v80/digital_top__nom_tt_025C_1v80.sdf", i_digital_top);
        
        spi_ctrl.init();

        // Reset sequence
        #(10*CLK_P); rst_n = 1;
        #(10*CLK_P); rst_n = 0;
        #(10*CLK_P); rst_n = 1;
        #(5*CLK_P);

        // ---------------- Write all ones ------------------------
        pulse_fifo_rst_n('hf);
        pulse_fsm_rst_n('hf);
        // set_irq('hfff, 'hfff, 0);
        write_dacs('hfff, 0);
        // write_biases(4'hf, 1, 0);

        write_fine(8'hFF, 0);
        write_nfine(8'hFF, 0);
        write_coarse(8'hFF, 0);
        write_bias_combined(16'h03FF, 0); // Max 10-bit value
        write_fsm(16'h3FFF, 0);           // Max 14-bit value
        #500ns;

        // ---------------- Write all zeros -----------------------
        pulse_fifo_rst_n('h0);
        pulse_fsm_rst_n('h0);
        // set_irq('h000, 'h000, 0);
        write_dacs('h000, 0);
        // write_biases(4'h0, 1, 0);

        write_fine(8'h00, 0);
        write_nfine(8'h00, 0);
        write_coarse(8'h00, 0);
        write_bias_combined(16'h0000, 0);
        write_fsm(16'h0000, 0);
        #500ns;

        // ---------------- Write sequence data -------------------
        write_dacs_seq('h5aa);
        // write_biases(4'ha, 0, 0);              // starts A, increments
        // set_irq('h2AA, 'h2AA, 0);
        write_fine_seq(8'hA0);
        write_nfine_seq(8'hB0);
        write_coarse_seq(8'hC0);
        write_bias_combined_seq(16'h0200);
        write_fsm_seq(16'h0A00);        
        #500ns;

        // ---------------- Write sequence data -------------------
        write_dacs_seq('hfaa);
        // write_biases(4'hf, 0, 0);              // starts F, increments
        // set_irq('h0CC, 'h1DD, 0);
        write_fine_seq(8'h10);
        write_nfine_seq(8'h30);
        write_coarse_seq(8'h50);
        write_bias_combined_seq(16'h0010);
        write_fsm_seq(16'h0100);
        #500ns;

        // ---------------- Read and dump comparison --------------
        // Read Chip ID
        spi_ctrl.trans(READ_BT, 0, 0, 'h55);
        #CLK_P;

        // set_irq(irq_deassert_write_val, irq_assert_write_val, 1);
        read_dacs('h100);   //writes consecutive data to dacs & reads
        // write_biases(4'h3, 0, 1);  //write and read beginning at 333333
        read_fine_seq(8'hA0);
        read_nfine_seq(8'hB0);
        read_coarse_seq(8'hC0);
        read_bias_combined_seq(16'h0200);
        read_fsm_seq(16'h0A00);
        #300ns;

        // Trigger the automated check
        check_results();
        $stop;
    end

endmodule : tb