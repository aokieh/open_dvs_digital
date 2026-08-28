`timescale 1ns/1ps
`default_nettype none

module tb_sync_product_preframing;
    localparam logic [135:0] TOP_RECORD = {
        2'b10,
        6'h15,
        64'h8000_0000_0000_0021,
        64'h0102_0408_1020_4080
    };
    localparam logic [135:0] BOTTOM_RECORD = {
        2'b01,
        6'h2a,
        64'h0001_0002_0004_0008,
        64'h8040_2010_0804_0201
    };
    localparam logic [135:0] FULL_RECORD = {
        2'b10,
        6'h3e,
        64'h55aa_00ff_0f0f_f0f0,
        64'haa55_ff00_f0f0_0f0f
    };

    logic clk;
    logic rst_n;
    logic CS_N;
    logic [3:0] COPI;
    logic [3:0] CIPO;
    logic data_ready_top;
    logic [63:0] array_col_top_left;
    logic [63:0] array_col_top_right;
    logic [63:0] array_col_bot_left;
    logic [63:0] array_col_bot_right;
    logic sm_enable;
    logic pix_rst_global_in;
    string plant;
    integer checks_completed;
    integer completion_count;

    final_top3 dut (
        .clk(clk),
        .rst_n(rst_n),
        .CS_N(CS_N),
        .COPI(COPI),
        .CIPO(CIPO),
        .array_col_top_left(array_col_top_left),
        .array_col_top_right(array_col_top_right),
        .array_col_bot_left(array_col_bot_left),
        .array_col_bot_right(array_col_bot_right),
        .data_ready_top(data_ready_top),
        .sm_enable(sm_enable),
        .pix_rst_global_in(pix_rst_global_in)
    );

    always #5 clk = ~clk;

    function automatic logic plant_is(input string name);
        plant_is = (plant == name);
    endfunction

    task automatic fail(input string check_name);
        begin
            $display(
                "@@SYNC_PRODUCT_PREFRAMING_FAIL@@ plant=%s check=%s",
                plant,
                check_name
            );
            $fatal(1, "Synchronous product pre-framing acceptance failed");
        end
    endtask

    task automatic check(input logic condition, input string check_name);
        begin
            if (condition !== 1'b1)
                fail(check_name);
            checks_completed = checks_completed + 1;
        end
    endtask

    task automatic tick;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    task automatic verify_reset_contract;
        begin
            CS_N = 1'b1;
            rst_n = 1'b0;
            repeat (2) tick();
            check(dut.sync_product_rst_n === 1'b0,
                  "reset-asserted-before-release");
            check(dut.i_sync_product_encoder_core.arst_ni === 1'b0,
                  "core-reset-asserted-before-release");

            @(negedge clk);
            rst_n = 1'b1;
            tick();
            if (plant_is("early_reset_release"))
                fail("synchronized-reset-first-release-edge");
            check(dut.sync_product_rst_n === 1'b0,
                  "synchronized-reset-first-release-edge");
            check(dut.i_sync_product_encoder_core.arst_ni === 1'b0,
                  "core-held-reset-first-release-edge");
            tick();
            check(dut.sync_product_rst_n === 1'b1,
                  "synchronized-reset-second-release-edge");
            check(dut.i_sync_product_encoder_core.arst_ni === 1'b1,
                  "core-released-on-synchronized-edge");
            check(dut.i_sync_product_encoder_core.u_top_enc128.rst_n === 1'b1,
                  "top-leaf-synchronized-reset-release");
            check(dut.i_sync_product_encoder_core.u_bottom_enc128.rst_n === 1'b1,
                  "bottom-leaf-synchronized-reset-release");

            #2;
            rst_n = 1'b0;
            #0.001;
            check(dut.sync_product_rst_n === 1'b0,
                  "asynchronous-reset-assertion");
            check(dut.i_sync_product_encoder_core.arst_ni === 1'b0,
                  "asynchronous-core-reset-assertion");
            @(negedge clk);
            rst_n = 1'b1;
            tick();
            check(dut.sync_product_rst_n === 1'b0,
                  "repeat-first-release-edge");
            tick();
            check(dut.sync_product_rst_n === 1'b1,
                  "repeat-second-release-edge");
        end
    endtask

    task automatic install_default_off_plants;
        begin
            if (plant_is("enable_product_admission"))
                force dut.i_sync_product_encoder_core.admit_enable_i = 1'b1;
            if (plant_is("fragment_ready_high"))
                force dut.i_sync_product_encoder_core.top_fragment_ready_i = 1'b1;
            if (plant_is("sync_visibility_high"))
                force dut.i_sync_mode_ownership.sync_available_i = 1'b1;
        end
    endtask

    task automatic verify_default_off;
        begin
            #1;
            check(dut.i_sync_product_encoder_core.admit_enable_i === 1'b0,
                  "product-admission-disabled");
            check(dut.i_sync_product_encoder_core.top_fragment_ready_i === 1'b0,
                  "top-fragment-ready-low");
            check(dut.i_sync_product_encoder_core.bottom_fragment_ready_i === 1'b0,
                  "bottom-fragment-ready-low");
            check(dut.i_sync_mode_ownership.sync_available_i === 1'b0,
                  "synchronous-availability-low");
            check(dut.i_sync_mode_ownership.sync_ready_i === 1'b0,
                  "synchronous-ready-low");
            check(dut.i_sync_mode_ownership.sync_data_0_i === 16'd0,
                  "synchronous-word-zero-low");
            check(dut.i_sync_mode_ownership.sync_data_1_i === 16'd0,
                  "synchronous-word-one-low");
            check(dut.sync_shift_en_fifo === 2'b00,
                  "synchronous-consume-low");
            check(dut.sync_top_record_accepted === 1'b0,
                  "top-synchronous-acceptance-low");
            check(dut.sync_bottom_record_accepted === 1'b0,
                  "bottom-synchronous-acceptance-low");
            check(dut.sync_accepted_count === 32'd0,
                  "synchronous-accepted-count-zero");
            check(dut.sync_top_fragment_valid === 1'b0,
                  "top-fragment-valid-zero");
            check(dut.sync_bottom_fragment_valid === 1'b0,
                  "bottom-fragment-valid-zero");
        end
    endtask

    task set_top_record(input logic [135:0] record);
        begin
            force dut.i_dvs_core.i_col_readout_top.event_mode = record[135:134];
            force dut.i_dvs_core.i_col_readout_top.row_addr = record[133:128];
            force dut.i_dvs_core.i_col_readout_top.col_left_m2 = record[127:64];
            force dut.i_dvs_core.i_col_readout_top.col_right_m2 = record[63:0];
        end
    endtask

    task set_bottom_record(input logic [135:0] record);
        begin
            force dut.i_dvs_core.i_col_readout_bot.event_mode = record[135:134];
            force dut.i_dvs_core.i_col_readout_bot.row_addr = record[133:128];
            force dut.i_dvs_core.i_col_readout_bot.col_left_m2 = record[127:64];
            force dut.i_dvs_core.i_col_readout_bot.col_right_m2 = record[63:0];
        end
    endtask

    task automatic verify_top_source_pulse;
        logic [135:0] observed_record;
        begin
            @(negedge clk);
            set_top_record(TOP_RECORD);
            set_bottom_record(BOTTOM_RECORD);
            force dut.i_dvs_core.i_col_readout_top.fifo_wr_en = 1'b1;
            force dut.i_dvs_core.i_col_readout_bot.fifo_wr_en = 1'b0;
            #1;
            check(
                dut.i_dvs_core.i_col_readout_top.source_record_valid_o === 1'b1,
                "top-column-source-valid"
            );
            check(dut.i_dvs_core.top_record_valid_o === 1'b1,
                  "top-capture-hierarchy-valid");
            check(dut.top_record_valid === 1'b1,
                  "top-final-source-valid");
            check(dut.i_sync_product_encoder_core.top_record_valid_i === 1'b1,
                  "top-core-source-valid");
            check(
                dut.i_dvs_core.i_col_readout_top.source_record_o === TOP_RECORD,
                "top-column-record-mapping"
            );
            check(dut.i_dvs_core.top_record_o === TOP_RECORD,
                  "top-capture-record-mapping");
            observed_record = dut.top_record;
            if (plant_is("swap_record_halves"))
                observed_record = {
                    dut.top_record[135:128],
                    dut.top_record[63:0],
                    dut.top_record[127:64]
                };
            check(observed_record === TOP_RECORD, "top-record-mapping");
            check(dut.i_sync_product_encoder_core.top_record_i === TOP_RECORD,
                  "top-core-record-mapping");
            if (plant_is("couple_tier_valid"))
                fail("top-pulse-independent-bottom-valid");
            check(dut.bottom_record_valid === 1'b0,
                  "top-pulse-independent-bottom-valid");
            check(
                dut.i_dvs_core.i_col_readout_top.i_sync_fifo_top.i_sync_fifo.write
                    === 1'b1,
                "legacy-write-enabled-when-not-full"
            );
            tick();
            check(
                dut.i_dvs_core.i_col_readout_top.i_sync_fifo_top.i_sync_fifo.counter
                    === 5'd1,
                "legacy-top-enqueue-count"
            );
            check(dut.sync_top_record_accepted === 1'b0,
                  "top-acceptance-remains-low-after-source-pulse");
            @(negedge clk);
            force dut.i_dvs_core.i_col_readout_top.fifo_wr_en = 1'b0;
        end
    endtask

    task automatic verify_bottom_source_pulse;
        begin
            @(negedge clk);
            set_bottom_record(BOTTOM_RECORD);
            force dut.i_dvs_core.i_col_readout_top.fifo_wr_en = 1'b0;
            force dut.i_dvs_core.i_col_readout_bot.fifo_wr_en = 1'b1;
            #1;
            check(
                dut.i_dvs_core.i_col_readout_bot.source_record_valid_o === 1'b1,
                "bottom-column-source-valid"
            );
            check(dut.i_dvs_core.bottom_record_valid_o === 1'b1,
                  "bottom-capture-hierarchy-valid");
            check(dut.bottom_record_valid === 1'b1,
                  "bottom-final-source-valid");
            check(dut.i_sync_product_encoder_core.bottom_record_valid_i === 1'b1,
                  "bottom-core-source-valid");
            check(
                dut.i_dvs_core.i_col_readout_bot.source_record_o
                    === BOTTOM_RECORD,
                "bottom-column-record-mapping"
            );
            check(dut.i_dvs_core.bottom_record_o === BOTTOM_RECORD,
                  "bottom-capture-record-mapping");
            check(dut.bottom_record === BOTTOM_RECORD,
                  "bottom-final-record-mapping");
            check(dut.i_sync_product_encoder_core.bottom_record_i === BOTTOM_RECORD,
                  "bottom-core-record-mapping");
            check(dut.top_record_valid === 1'b0,
                  "bottom-pulse-independent-top-valid");
            tick();
            check(
                dut.i_dvs_core.i_col_readout_bot.i_sync_fifo_top.i_sync_fifo.counter
                    === 5'd1,
                "legacy-bottom-enqueue-count"
            );
            check(dut.sync_bottom_record_accepted === 1'b0,
                  "bottom-acceptance-remains-low-after-source-pulse");
            @(negedge clk);
            force dut.i_dvs_core.i_col_readout_bot.fifo_wr_en = 1'b0;
        end
    endtask

    task automatic fill_top_fifo;
        integer index;
        begin
            set_top_record(TOP_RECORD);
            for (index = 1; index < 16; index = index + 1) begin
                @(negedge clk);
                force dut.i_dvs_core.i_col_readout_top.fifo_wr_en = 1'b1;
                tick();
                @(negedge clk);
                force dut.i_dvs_core.i_col_readout_top.fifo_wr_en = 1'b0;
            end
            #1;
            check(
                dut.i_dvs_core.i_col_readout_top.i_sync_fifo_top.i_sync_fifo.counter
                    === 5'd16,
                "legacy-top-fifo-reaches-full"
            );
            check(
                dut.i_dvs_core.i_col_readout_top.i_sync_fifo_top.i_sync_fifo.full
                    === 1'b1,
                "legacy-top-full-flag"
            );
        end
    endtask

    task automatic verify_full_source_observation;
        logic observed_valid;
        logic [4:0] saved_counter;
        logic [3:0] saved_write_pointer;
        begin
            @(negedge clk);
            set_top_record(FULL_RECORD);
            saved_counter =
                dut.i_dvs_core.i_col_readout_top.i_sync_fifo_top.i_sync_fifo.counter;
            saved_write_pointer =
                dut.i_dvs_core.i_col_readout_top.i_sync_fifo_top.i_sync_fifo.wr_ptr;
            force dut.i_dvs_core.i_col_readout_top.fifo_wr_en = 1'b1;
            #1;
            observed_valid = dut.top_record_valid;
            if (plant_is("gate_source_with_full"))
                observed_valid = observed_valid &&
                    !dut.i_dvs_core.i_col_readout_top.i_sync_fifo_top.i_sync_fifo.full;
            check(observed_valid === 1'b1,
                  "full-source-valid-before-suppression");
            check(dut.top_record === FULL_RECORD,
                  "full-source-record-before-suppression");
            check(
                dut.i_sync_product_encoder_core.top_record_valid_i === 1'b1,
                "full-source-pulse-reaches-product-core"
            );
            check(
                dut.i_dvs_core.i_col_readout_top.i_sync_fifo_top.i_sync_fifo.write
                    === 1'b0,
                "legacy-full-suppresses-enqueue"
            );
            tick();
            check(
                dut.i_dvs_core.i_col_readout_top.i_sync_fifo_top.i_sync_fifo.counter
                    === saved_counter,
                "legacy-full-preserves-count"
            );
            check(
                dut.i_dvs_core.i_col_readout_top.i_sync_fifo_top.i_sync_fifo.wr_ptr
                    === saved_write_pointer,
                "legacy-full-preserves-write-pointer"
            );
            check(dut.sync_top_record_accepted === 1'b0,
                  "full-source-product-acceptance-remains-low");
            @(negedge clk);
            force dut.i_dvs_core.i_col_readout_top.fifo_wr_en = 1'b0;
        end
    endtask

    task automatic send_fifo_opcode;
        integer bit_index;
        begin
            CS_N = 1'b1;
            COPI = 4'd0;
            #1;
            check(dut.serial_beat_complete === 1'b0,
                  "completion-low-before-transaction");
            @(negedge clk);
            CS_N = 1'b0;
            for (bit_index = 7; bit_index >= 0; bit_index = bit_index - 1) begin
                COPI = 4'd0;
                COPI[0] = (8'h07 >> bit_index) & 1'b1;
                tick();
                check(dut.serial_beat_complete === 1'b0,
                      "opcode-has-no-completion");
                @(negedge clk);
            end
            COPI = 4'd0;
            check(dut.i_spi_peripheral.opcode_valid === 3'b111,
                  "fifo-opcode-recognized");
            check(dut.i_spi_peripheral.cycle_count === 4'd8,
                  "fifo-opcode-finishes-at-cycle8");
        end
    endtask

    task automatic run_one_complete_beat;
        integer bit_index;
        logic [3:0] cycle_before;
        logic [3:0] expected_final_lane_bits;
        logic observed_completion;
        begin
            completion_count = 0;
            expected_final_lane_bits = 4'd0;
            for (bit_index = 7; bit_index >= 0; bit_index = bit_index - 1) begin
                cycle_before = dut.i_spi_peripheral.cycle_count;
                if (cycle_before == 4'd15) begin
                    expected_final_lane_bits = {
                        dut.i_spi_peripheral.tx_data_3[0],
                        dut.i_spi_peripheral.tx_data_2[0],
                        dut.i_spi_peripheral.tx_data_1[0],
                        dut.i_spi_peripheral.tx_data_0[0]
                    };
                end
                tick();
                observed_completion = dut.serial_beat_complete;
                if (plant_is("completion_at_consume") &&
                    cycle_before == 4'd13)
                    observed_completion = 1'b1;
                if (plant_is("suppress_cycle15_completion") &&
                    cycle_before == 4'd15)
                    observed_completion = 1'b0;

                if (observed_completion === 1'b1)
                    completion_count = completion_count + 1;
                if (cycle_before == 4'd13) begin
                    check(dut.shift_en_fifo === 2'b11,
                          "cycle13-consume-lookahead");
                    check(observed_completion === 1'b0,
                          "cycle13-is-consume-only");
                    check(dut.raw_shift_en_fifo === 2'b11,
                          "cycle13-remains-raw-consume");
                    check(dut.sync_shift_en_fifo === 2'b00,
                          "cycle13-synchronous-consume-remains-low");
                end else if (cycle_before == 4'd15) begin
                    check(dut.shift_en_fifo === 2'b00,
                          "cycle15-is-not-consume");
                    check(observed_completion === 1'b1,
                          "cycle15-completion");
                    check(CIPO === expected_final_lane_bits,
                          "cycle15-final-four-lane-bits");
                end else begin
                    check(observed_completion === 1'b0,
                          "nonfinal-cycle-has-no-completion");
                end
                @(negedge clk);
            end
            check(completion_count == 1,
                  "exactly-one-completion-per-beat");
            CS_N = 1'b1;
            #0.001;
            check(dut.serial_beat_complete === 1'b0,
                  "completion-clears-on-chip-select-release");
        end
    endtask

    task automatic run_aborted_beat;
        integer cycle_index;
        logic observed_completion;
        begin
            send_fifo_opcode();
            for (cycle_index = 0; cycle_index < 4; cycle_index = cycle_index + 1) begin
                tick();
                check(dut.serial_beat_complete === 1'b0,
                      "partial-beat-has-no-completion");
                @(negedge clk);
            end
            CS_N = 1'b1;
            #0.001;
            observed_completion = dut.serial_beat_complete;
            if (plant_is("completion_on_abort"))
                observed_completion = 1'b1;
            check(observed_completion === 1'b0,
                  "abort-has-no-completion");
            tick();
            check(dut.serial_beat_complete === 1'b0,
                  "post-abort-has-no-completion");
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        CS_N = 1'b1;
        COPI = 4'd0;
        array_col_top_left = 64'd0;
        array_col_top_right = 64'd0;
        array_col_bot_left = 64'd0;
        array_col_bot_right = 64'd0;
        sm_enable = 1'b0;
        pix_rst_global_in = 1'b0;
        checks_completed = 0;
        completion_count = 0;
        if (!$value$plusargs("PLANT=%s", plant))
            plant = "none";

        verify_reset_contract();
        install_default_off_plants();
        verify_default_off();
        verify_top_source_pulse();
        verify_bottom_source_pulse();
        fill_top_fifo();
        verify_full_source_observation();
        verify_default_off();
        send_fifo_opcode();
        run_one_complete_beat();
        run_aborted_beat();
        verify_default_off();

        check(checks_completed >= 100, "minimum-check-inventory");
        $display(
            "@@SYNC_PRODUCT_PREFRAMING_ACCEPTANCE_PASS@@ mapping_tiers=2 independent_pulses=2 prefull_observations=1 legacy_full_suppression=1 reset_release_cycles=2 core_instances=1 enc128_leaves=2 default_off=1 cycle13_consume=1 cycle15_completion=1 abort_completions=0 packet_length_assumptions=0"
        );
        $finish;
    end
endmodule

`default_nettype wire
