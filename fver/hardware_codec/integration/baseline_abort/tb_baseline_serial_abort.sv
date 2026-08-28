`timescale 1ns/1ps
`default_nettype none

module tb_baseline_serial_abort;
    localparam integer CLK_HALF_PERIOD_NS = 10;
    localparam logic [1:0] SERIALIZER_IDLE = 2'd0;
    localparam logic [1:0] SERIALIZER_DATA = 2'd1;
    localparam logic [1:0] SERIALIZER_CONTROL = 2'd2;

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

    logic [31:0] expected_words [0:8];
    logic [135:0] top_records [0:1];
    logic [135:0] bottom_records [0:1];
    logic [135:0] injected_top_record;
    logic [135:0] injected_bottom_record;

    integer top_pop_count;
    integer bottom_pop_count;
    integer replay_bursts;
    integer normal_bursts;
    integer lane_bytes;
    integer premature_pops;
    integer global_reset_cases;
    integer failing_mask;
    integer passing_boundaries;
    integer release_phase_cases;
    integer full_clock_abort_samples;

    wire [4:0] top_count =
        dut.i_dvs_core.i_col_readout_top.i_sync_fifo_top.i_sync_fifo.counter;
    wire [4:0] bottom_count =
        dut.i_dvs_core.i_col_readout_bot.i_sync_fifo_top.i_sync_fifo.counter;
    wire [3:0] top_read_pointer =
        dut.i_dvs_core.i_col_readout_top.i_sync_fifo_top.i_sync_fifo.rd_ptr;
    wire [3:0] bottom_read_pointer =
        dut.i_dvs_core.i_col_readout_bot.i_sync_fifo_top.i_sync_fifo.rd_ptr;
    wire [3:0] top_write_pointer =
        dut.i_dvs_core.i_col_readout_top.i_sync_fifo_top.i_sync_fifo.wr_ptr;
    wire [3:0] bottom_write_pointer =
        dut.i_dvs_core.i_col_readout_bot.i_sync_fifo_top.i_sync_fifo.wr_ptr;
    wire [135:0] top_head =
        dut.i_dvs_core.i_col_readout_top.i_sync_fifo_top.i_sync_fifo.rdata;
    wire [135:0] bottom_head =
        dut.i_dvs_core.i_col_readout_bot.i_sync_fifo_top.i_sync_fifo.rdata;
    wire top_accepted_pop =
        dut.i_dvs_core.i_col_readout_top.i_sync_fifo_top.i_sync_fifo.read;
    wire bottom_accepted_pop =
        dut.i_dvs_core.i_col_readout_bot.i_sync_fifo_top.i_sync_fifo.read;
    wire [1:0] top_serializer_state =
        dut.i_dvs_core.i_col_readout_top.i_sync_fifo_top.i_fifo_intf3.state;
    wire [1:0] bottom_serializer_state =
        dut.i_dvs_core.i_col_readout_bot.i_sync_fifo_top.i_fifo_intf3.state;
    wire [3:0] top_serializer_chunk =
        dut.i_dvs_core.i_col_readout_top.i_sync_fifo_top.i_fifo_intf3.shift_ctr;
    wire [3:0] bottom_serializer_chunk =
        dut.i_dvs_core.i_col_readout_bot.i_sync_fifo_top.i_fifo_intf3.shift_ctr;
    wire [15:0] top_serializer_word =
        dut.i_dvs_core.i_col_readout_top.i_sync_fifo_top.i_fifo_intf3.rdata_spi;
    wire [15:0] bottom_serializer_word =
        dut.i_dvs_core.i_col_readout_bot.i_sync_fifo_top.i_fifo_intf3.rdata_spi;
    wire synchronized_stream_abort = dut.stream_abort;

    final_top3 dut (
        .clk                 (clk),
        .rst_n               (rst_n),
        .CS_N                (CS_N),
        .COPI                (COPI),
        .CIPO                (CIPO),
        .array_col_top_left  (array_col_top_left),
        .array_col_top_right (array_col_top_right),
        .array_col_bot_left  (array_col_bot_left),
        .array_col_bot_right (array_col_bot_right),
        .data_ready_top      (data_ready_top),
        .sm_enable           (sm_enable),
        .pix_rst_global_in   (pix_rst_global_in)
    );

    always #CLK_HALF_PERIOD_NS clk = ~clk;

    always @(posedge clk) begin
        if (rst_n === 1'b1) begin
            if (top_accepted_pop === 1'b1)
                top_pop_count = top_pop_count + 1;
            if (bottom_accepted_pop === 1'b1)
                bottom_pop_count = bottom_pop_count + 1;
        end
    end

    task automatic apparatus_fail(
        input string check_name,
        input integer boundary,
        input logic [31:0] expected,
        input logic [31:0] actual
    );
        begin
            $display("@@BASELINE_SERIAL_ABORT_APPARATUS_FAIL@@ check=%s boundary=%0d expected=%08h actual=%08h",
                     check_name, boundary, expected, actual);
            $fatal(1, "Baseline serializer abort apparatus failed");
        end
    endtask

    task automatic require_known_state(input string check_name, input integer boundary);
        begin
            if ((^top_count === 1'bx) ||
                (^bottom_count === 1'bx) ||
                (^top_read_pointer === 1'bx) ||
                (^bottom_read_pointer === 1'bx) ||
                (^top_write_pointer === 1'bx) ||
                (^bottom_write_pointer === 1'bx) ||
                (^top_head === 1'bx) ||
                (^bottom_head === 1'bx) ||
                (^top_serializer_state === 1'bx) ||
                (^bottom_serializer_state === 1'bx) ||
                (^top_serializer_chunk === 1'bx) ||
                (^bottom_serializer_chunk === 1'bx) ||
                (^top_serializer_word === 1'bx) ||
                (^bottom_serializer_word === 1'bx)) begin
                apparatus_fail(check_name, boundary, 32'd0, 32'hxxxx_xxxx);
            end
        end
    endtask

    task automatic reset_design;
        begin
            CS_N = 1'b1;
            COPI = 4'd0;
            rst_n = 1'b0;
            repeat (3) begin
                @(posedge clk);
                #1;
            end
            @(negedge clk);
            rst_n = 1'b1;
            repeat (3) begin
                @(posedge clk);
                #1;
            end
            if ((top_count !== 5'd0) || (bottom_count !== 5'd0) ||
                (top_read_pointer !== 4'd0) || (bottom_read_pointer !== 4'd0) ||
                (top_write_pointer !== 4'd0) || (bottom_write_pointer !== 4'd0) ||
                (top_serializer_state !== SERIALIZER_IDLE) ||
                (bottom_serializer_state !== SERIALIZER_IDLE) ||
                (top_serializer_chunk !== 4'd0) ||
                (bottom_serializer_chunk !== 4'd0) ||
                (top_serializer_word !== 16'd0) ||
                (bottom_serializer_word !== 16'd0)) begin
                apparatus_fail("global-reset-initialization", -1, 32'd0,
                               {top_count[3:0], bottom_count[3:0],
                                top_read_pointer, bottom_read_pointer,
                                top_write_pointer, bottom_write_pointer,
                                top_serializer_chunk, bottom_serializer_chunk});
            end
        end
    endtask

    task automatic load_record_pair(input integer record_index);
        begin
            @(negedge clk);
            injected_top_record = top_records[record_index];
            injected_bottom_record = bottom_records[record_index];
            force dut.i_dvs_core.i_col_readout_top.i_sync_fifo_top.i_sync_fifo.wr_en = 1'b1;
            force dut.i_dvs_core.i_col_readout_bot.i_sync_fifo_top.i_sync_fifo.wr_en = 1'b1;
            force dut.i_dvs_core.i_col_readout_top.i_sync_fifo_top.i_sync_fifo.wdata =
                injected_top_record;
            force dut.i_dvs_core.i_col_readout_bot.i_sync_fifo_top.i_sync_fifo.wdata =
                injected_bottom_record;
            @(posedge clk);
            #1;
            force dut.i_dvs_core.i_col_readout_top.i_sync_fifo_top.i_sync_fifo.wr_en = 1'b0;
            force dut.i_dvs_core.i_col_readout_bot.i_sync_fifo_top.i_sync_fifo.wr_en = 1'b0;
            release dut.i_dvs_core.i_col_readout_top.i_sync_fifo_top.i_sync_fifo.wdata;
            release dut.i_dvs_core.i_col_readout_bot.i_sync_fifo_top.i_sync_fifo.wdata;
        end
    endtask

    task automatic load_primary_and_sentinel;
        begin
            load_record_pair(0);
            load_record_pair(1);
            @(posedge clk);
            #1;
            release dut.i_dvs_core.i_col_readout_top.i_sync_fifo_top.i_sync_fifo.wr_en;
            release dut.i_dvs_core.i_col_readout_bot.i_sync_fifo_top.i_sync_fifo.wr_en;
            @(posedge clk);
            #1;
            require_known_state("loaded-state-known", -1);
            if ((top_count !== 5'd2) || (bottom_count !== 5'd2) ||
                (top_read_pointer !== 4'd0) || (bottom_read_pointer !== 4'd0) ||
                (top_write_pointer !== 4'd2) || (bottom_write_pointer !== 4'd2) ||
                (top_head !== top_records[0]) || (bottom_head !== bottom_records[0]) ||
                (top_serializer_state !== SERIALIZER_DATA) ||
                (bottom_serializer_state !== SERIALIZER_DATA) ||
                (top_serializer_chunk !== 4'd0) ||
                (bottom_serializer_chunk !== 4'd0) ||
                ({bottom_serializer_word, top_serializer_word} !== expected_words[0]) ||
                (data_ready_top !== 1'b1)) begin
                apparatus_fail("load-primary-and-sentinel", -1, expected_words[0],
                               {bottom_serializer_word, top_serializer_word});
            end
            top_pop_count = 0;
            bottom_pop_count = 0;
        end
    endtask

    task automatic send_fifo_read_opcode;
        integer bit_index;
        begin
            if (CS_N !== 1'b1)
                apparatus_fail("opcode-chip-select-precondition", -1, 32'd1, {31'd0, CS_N});
            @(negedge clk);
            CS_N = 1'b0;
            COPI = 4'd0;
            for (bit_index = 7; bit_index >= 0; bit_index = bit_index - 1) begin
                COPI[0] = (8'h07 >> bit_index) & 1'b1;
                @(posedge clk);
                #1;
                @(negedge clk);
            end
            COPI = 4'd0;
            if ((dut.i_spi_peripheral.opcode_valid !== 3'b111) ||
                (dut.i_spi_peripheral.cycle_count !== 4'd8)) begin
                apparatus_fail("fresh-fifo-opcode", -1, 32'h0000_0708,
                               {25'd0, dut.i_spi_peripheral.opcode_valid,
                                dut.i_spi_peripheral.cycle_count});
            end
        end
    endtask

    task automatic capture_lane_word(output logic [31:0] captured_word);
        logic [7:0] lane_bytes_local [0:3];
        integer bit_index;
        begin
            lane_bytes_local[0] = 8'd0;
            lane_bytes_local[1] = 8'd0;
            lane_bytes_local[2] = 8'd0;
            lane_bytes_local[3] = 8'd0;
            for (bit_index = 7; bit_index >= 0; bit_index = bit_index - 1) begin
                @(posedge clk);
                #1;
                if (^CIPO === 1'bx)
                    apparatus_fail("unknown-return-lane", -1, 32'd0, 32'hxxxx_xxxx);
                lane_bytes_local[0][bit_index] = CIPO[0];
                lane_bytes_local[1][bit_index] = CIPO[1];
                lane_bytes_local[2][bit_index] = CIPO[2];
                lane_bytes_local[3][bit_index] = CIPO[3];
                @(negedge clk);
            end
            captured_word = {lane_bytes_local[3], lane_bytes_local[2],
                             lane_bytes_local[1], lane_bytes_local[0]};
        end
    endtask

    task automatic release_chip_select;
        begin
            CS_N = 1'b1;
            COPI = 4'd0;
            repeat (2) begin
                @(posedge clk);
                #1;
            end
            @(negedge clk);
            if ((CIPO !== 4'd0) ||
                (dut.i_spi_peripheral.cycle_count !== 4'd0) ||
                (dut.i_spi_peripheral.fifo_shift_count !== 4'd0) ||
                (dut.i_spi_peripheral.shift_en_fifo !== 2'b00)) begin
                apparatus_fail("chip-select-release", -1, 32'd0,
                               {18'd0, dut.i_spi_peripheral.cycle_count,
                                dut.i_spi_peripheral.fifo_shift_count,
                                dut.i_spi_peripheral.shift_en_fifo, CIPO});
            end
        end
    endtask

    task automatic require_no_pop(input string check_name, input integer boundary);
        begin
            if ((top_pop_count != 0) || (bottom_pop_count != 0)) begin
                premature_pops = premature_pops + top_pop_count + bottom_pop_count;
                apparatus_fail(check_name, boundary, 32'd0,
                               {16'd0, top_pop_count[7:0], bottom_pop_count[7:0]});
            end
        end
    endtask

    task automatic require_completed_pop_and_sentinel(
        input string check_name,
        input integer boundary
    );
        begin
            #1;
            if ((top_pop_count != 1) || (bottom_pop_count != 1) ||
                (top_count !== 5'd1) || (bottom_count !== 5'd1) ||
                (top_read_pointer !== 4'd1) || (bottom_read_pointer !== 4'd1) ||
                (top_write_pointer !== 4'd2) || (bottom_write_pointer !== 4'd2) ||
                (top_head !== top_records[1]) || (bottom_head !== bottom_records[1])) begin
                apparatus_fail(check_name, boundary, 32'h0101_1212,
                               {top_pop_count[3:0], bottom_pop_count[3:0],
                                top_count[3:0], bottom_count[3:0],
                                top_read_pointer, bottom_read_pointer,
                                top_write_pointer, bottom_write_pointer});
            end
        end
    endtask

    task automatic run_complete_replay(input integer boundary, input logic [31:0] first_word);
        logic [31:0] captured_word;
        integer burst_index;
        begin
            if (first_word !== expected_words[0])
                apparatus_fail("replay-burst-zero", boundary, expected_words[0], first_word);
            replay_bursts = replay_bursts + 1;
            lane_bytes = lane_bytes + 4;
            require_no_pop("replay-premature-pop-zero", boundary);
            for (burst_index = 1; burst_index < 9; burst_index = burst_index + 1) begin
                capture_lane_word(captured_word);
                if (captured_word !== expected_words[burst_index])
                    apparatus_fail("replay-word-identity", boundary,
                                   expected_words[burst_index], captured_word);
                replay_bursts = replay_bursts + 1;
                lane_bytes = lane_bytes + 4;
                if (burst_index < 8)
                    require_no_pop("replay-premature-pop", boundary);
            end
            require_completed_pop_and_sentinel("replay-completed-pop", boundary);
            release_chip_select();
            passing_boundaries = passing_boundaries + 1;
            $display("@@BASELINE_SERIAL_ABORT_BOUNDARY_PASS@@ boundary=%0d replay_bursts=9 premature_pops=0 top_pops=1 bottom_pops=1 preserved_head=1",
                     boundary);
        end
    endtask

    task automatic run_abort_boundary(input integer boundary);
        logic [31:0] captured_word;
        logic [135:0] saved_top_head;
        logic [135:0] saved_bottom_head;
        logic [135:0] saved_top_slot_zero;
        logic [135:0] saved_bottom_slot_zero;
        logic [135:0] saved_top_slot_one;
        logic [135:0] saved_bottom_slot_one;
        logic [4:0] saved_top_count;
        logic [4:0] saved_bottom_count;
        logic [3:0] saved_top_read_pointer;
        logic [3:0] saved_bottom_read_pointer;
        logic [3:0] saved_top_write_pointer;
        logic [3:0] saved_bottom_write_pointer;
        logic [1:0] retained_state;
        logic [3:0] retained_chunk;
        integer burst_index;
        begin
            reset_design();
            load_primary_and_sentinel();
            saved_top_head = top_head;
            saved_bottom_head = bottom_head;
            saved_top_slot_zero =
                dut.i_dvs_core.i_col_readout_top.i_sync_fifo_top.i_sync_fifo.fifo[0];
            saved_bottom_slot_zero =
                dut.i_dvs_core.i_col_readout_bot.i_sync_fifo_top.i_sync_fifo.fifo[0];
            saved_top_slot_one =
                dut.i_dvs_core.i_col_readout_top.i_sync_fifo_top.i_sync_fifo.fifo[1];
            saved_bottom_slot_one =
                dut.i_dvs_core.i_col_readout_bot.i_sync_fifo_top.i_sync_fifo.fifo[1];
            saved_top_count = top_count;
            saved_bottom_count = bottom_count;
            saved_top_read_pointer = top_read_pointer;
            saved_bottom_read_pointer = bottom_read_pointer;
            saved_top_write_pointer = top_write_pointer;
            saved_bottom_write_pointer = bottom_write_pointer;

            send_fifo_read_opcode();
            for (burst_index = 0; burst_index < boundary; burst_index = burst_index + 1) begin
                capture_lane_word(captured_word);
                if (captured_word !== expected_words[burst_index])
                    apparatus_fail("partial-word-identity", boundary,
                                   expected_words[burst_index], captured_word);
                require_no_pop("partial-premature-pop", boundary);
            end

            release_chip_select();
            require_known_state("post-abort-state-known", boundary);
            if ((top_count !== saved_top_count) ||
                (bottom_count !== saved_bottom_count) ||
                (top_read_pointer !== saved_top_read_pointer) ||
                (bottom_read_pointer !== saved_bottom_read_pointer) ||
                (top_write_pointer !== saved_top_write_pointer) ||
                (bottom_write_pointer !== saved_bottom_write_pointer) ||
                (top_head !== saved_top_head) || (bottom_head !== saved_bottom_head) ||
                (dut.i_dvs_core.i_col_readout_top.i_sync_fifo_top.i_sync_fifo.fifo[0] !== saved_top_slot_zero) ||
                (dut.i_dvs_core.i_col_readout_bot.i_sync_fifo_top.i_sync_fifo.fifo[0] !== saved_bottom_slot_zero) ||
                (dut.i_dvs_core.i_col_readout_top.i_sync_fifo_top.i_sync_fifo.fifo[1] !== saved_top_slot_one) ||
                (dut.i_dvs_core.i_col_readout_bot.i_sync_fifo_top.i_sync_fifo.fifo[1] !== saved_bottom_slot_one)) begin
                apparatus_fail("abort-preserves-fifo", boundary, 32'h0200_0022,
                               {top_count[3:0], bottom_count[3:0],
                                top_read_pointer, bottom_read_pointer,
                                top_write_pointer, bottom_write_pointer});
            end

            retained_state = top_serializer_state;
            retained_chunk = top_serializer_chunk;
            if ((bottom_serializer_state !== retained_state) ||
                (bottom_serializer_chunk !== retained_chunk)) begin
                apparatus_fail("paired-serializer-progress", boundary,
                               {26'd0, retained_state, retained_chunk},
                               {26'd0, bottom_serializer_state, bottom_serializer_chunk});
            end

            send_fifo_read_opcode();
            capture_lane_word(captured_word);
            if (captured_word === expected_words[0]) begin
                run_complete_replay(boundary, captured_word);
            end else begin
                if ((boundary == 0) ||
                    (captured_word !== expected_words[boundary]) ||
                    ((boundary < 8) &&
                     ((retained_state !== SERIALIZER_DATA) ||
                      (retained_chunk !== boundary[3:0]))) ||
                    ((boundary == 8) &&
                     ((retained_state !== SERIALIZER_CONTROL) ||
                      (retained_chunk !== 4'd7)))) begin
                    apparatus_fail("unexpected-replay-failure", boundary,
                                   expected_words[0], captured_word);
                end
                failing_mask = failing_mask | (1 << boundary);
                $display("@@BASELINE_SERIAL_ABORT_BOUNDARY_RED@@ boundary=%0d expected_replay=%08h actual=%08h retained_state=%0d retained_chunk=%0d",
                         boundary, expected_words[0], captured_word,
                         retained_state, retained_chunk);
                release_chip_select();
            end
        end
    endtask

    task automatic run_normal_transaction;
        logic [31:0] captured_word;
        integer burst_index;
        begin
            reset_design();
            load_primary_and_sentinel();
            send_fifo_read_opcode();
            for (burst_index = 0; burst_index < 9; burst_index = burst_index + 1) begin
                capture_lane_word(captured_word);
                if (captured_word !== expected_words[burst_index])
                    apparatus_fail("normal-word-identity", -1,
                                   expected_words[burst_index], captured_word);
                normal_bursts = normal_bursts + 1;
                lane_bytes = lane_bytes + 4;
                if (burst_index < 8)
                    require_no_pop("normal-premature-pop", -1);
            end
            require_completed_pop_and_sentinel("normal-completed-pop", -1);
            release_chip_select();
            $display("@@BASELINE_SERIAL_ABORT_NORMAL_PASS@@ bursts=9 lane_bytes=36 top_pops=1 bottom_pops=1");
        end
    endtask

    task automatic run_global_reset_during_partial;
        logic [31:0] captured_word;
        integer burst_index;
        begin
            reset_design();
            load_primary_and_sentinel();
            send_fifo_read_opcode();
            for (burst_index = 0; burst_index < 4; burst_index = burst_index + 1) begin
                capture_lane_word(captured_word);
                if (captured_word !== expected_words[burst_index])
                    apparatus_fail("global-reset-partial-word", -1,
                                   expected_words[burst_index], captured_word);
                require_no_pop("global-reset-partial-pop", -1);
            end
            rst_n = 1'b0;
            repeat (2) begin
                @(posedge clk);
                #1;
            end
            require_known_state("global-reset-partial-known", -1);
            if ((top_count !== 5'd0) || (bottom_count !== 5'd0) ||
                (top_read_pointer !== 4'd0) || (bottom_read_pointer !== 4'd0) ||
                (top_write_pointer !== 4'd0) || (bottom_write_pointer !== 4'd0) ||
                (top_serializer_state !== SERIALIZER_IDLE) ||
                (bottom_serializer_state !== SERIALIZER_IDLE) ||
                (top_serializer_chunk !== 4'd0) ||
                (bottom_serializer_chunk !== 4'd0) ||
                (top_serializer_word !== 16'd0) ||
                (bottom_serializer_word !== 16'd0)) begin
                apparatus_fail("global-reset-during-partial", -1, 32'd0,
                               {top_count[3:0], bottom_count[3:0],
                                top_read_pointer, bottom_read_pointer,
                                top_serializer_chunk, bottom_serializer_chunk,
                                top_serializer_state, bottom_serializer_state});
            end
            @(negedge clk);
            CS_N = 1'b1;
            COPI = 4'd0;
            repeat (2) begin
                @(posedge clk);
                #1;
            end
            @(negedge clk);
            rst_n = 1'b1;
            global_reset_cases = global_reset_cases + 1;
            $display("@@BASELINE_SERIAL_ABORT_GLOBAL_RESET_PASS@@ partial_bursts=4 count=0 read_pointer=0 serializer_chunk=0");
        end
    endtask

    task automatic run_release_phase_case(input integer phase_case);
        logic [31:0] captured_word;
        logic [135:0] saved_top_head;
        logic [135:0] saved_bottom_head;
        logic [4:0] saved_top_count;
        logic [4:0] saved_bottom_count;
        logic [3:0] saved_top_read_pointer;
        logic [3:0] saved_bottom_read_pointer;
        logic [3:0] saved_top_write_pointer;
        logic [3:0] saved_bottom_write_pointer;
        logic [1:0] retained_top_state;
        logic [1:0] retained_bottom_state;
        logic [3:0] retained_top_chunk;
        logic [3:0] retained_bottom_chunk;
        integer burst_index;
        integer wait_cycles;
        integer abort_seen;
        begin
            reset_design();
            load_primary_and_sentinel();
            send_fifo_read_opcode();
            for (burst_index = 0; burst_index < 4; burst_index = burst_index + 1) begin
                capture_lane_word(captured_word);
                if (captured_word !== expected_words[burst_index])
                    apparatus_fail("release-phase-partial-word", phase_case,
                                   expected_words[burst_index], captured_word);
                require_no_pop("release-phase-partial-pop", phase_case);
            end

            saved_top_head = top_head;
            saved_bottom_head = bottom_head;
            saved_top_count = top_count;
            saved_bottom_count = bottom_count;
            saved_top_read_pointer = top_read_pointer;
            saved_bottom_read_pointer = bottom_read_pointer;
            saved_top_write_pointer = top_write_pointer;
            saved_bottom_write_pointer = bottom_write_pointer;

            // Exercise a midpoint release and releases two picoseconds before
            // and after a rising edge. The one-picosecond follow-up catches any
            // raw-CS_N asynchronous reset before the synchronizer can react.
            case (phase_case)
                0: #5.000;
                1: #9.998;
                2: begin
                    @(posedge clk);
                    #0.002;
                end
                default: apparatus_fail("release-phase-selector", phase_case,
                                        32'h0000_0002, phase_case);
            endcase

            retained_top_state = top_serializer_state;
            retained_bottom_state = bottom_serializer_state;
            retained_top_chunk = top_serializer_chunk;
            retained_bottom_chunk = bottom_serializer_chunk;
            CS_N = 1'b1;
            COPI = 4'd0;
            #0.001;
            if ((synchronized_stream_abort !== 1'b0) ||
                (top_serializer_state !== retained_top_state) ||
                (bottom_serializer_state !== retained_bottom_state) ||
                (top_serializer_chunk !== retained_top_chunk) ||
                (bottom_serializer_chunk !== retained_bottom_chunk)) begin
                apparatus_fail(
                    "release-phase-no-asynchronous-reset", phase_case,
                    {19'd0, 1'b0, retained_top_state, retained_top_chunk,
                     retained_bottom_state, retained_bottom_chunk},
                    {19'd0, synchronized_stream_abort, top_serializer_state,
                     top_serializer_chunk, bottom_serializer_state,
                     bottom_serializer_chunk}
                );
            end

            abort_seen = 0;
            wait_cycles = 0;
            while ((abort_seen == 0) && (wait_cycles < 6)) begin
                @(negedge clk);
                #0.001;
                wait_cycles = wait_cycles + 1;
                if (synchronized_stream_abort === 1'b1) begin
                    abort_seen = 1;
                    full_clock_abort_samples = full_clock_abort_samples + 1;
                end else if (synchronized_stream_abort !== 1'b0) begin
                    apparatus_fail("release-phase-abort-known", phase_case,
                                   32'd0, 32'hxxxx_xxxx);
                end
            end
            if (abort_seen != 1)
                apparatus_fail("release-phase-abort-observed", phase_case,
                               32'd1, abort_seen);

            // The pulse remains asserted through this rising edge, where the
            // serializer consumes it synchronously, and then deasserts.
            @(posedge clk);
            #0.001;
            if ((synchronized_stream_abort !== 1'b0) ||
                (top_serializer_state !== SERIALIZER_IDLE) ||
                (bottom_serializer_state !== SERIALIZER_IDLE) ||
                (top_serializer_chunk !== 4'd0) ||
                (bottom_serializer_chunk !== 4'd0) ||
                (top_serializer_word !== 16'd0) ||
                (bottom_serializer_word !== 16'd0)) begin
                apparatus_fail("release-phase-synchronous-abort", phase_case,
                               32'd0,
                               {3'd0, synchronized_stream_abort,
                                top_serializer_state, bottom_serializer_state,
                                top_serializer_chunk, bottom_serializer_chunk,
                                top_serializer_word});
            end
            if ((top_count !== saved_top_count) ||
                (bottom_count !== saved_bottom_count) ||
                (top_read_pointer !== saved_top_read_pointer) ||
                (bottom_read_pointer !== saved_bottom_read_pointer) ||
                (top_write_pointer !== saved_top_write_pointer) ||
                (bottom_write_pointer !== saved_bottom_write_pointer) ||
                (top_head !== saved_top_head) ||
                (bottom_head !== saved_bottom_head) ||
                (top_pop_count != 0) || (bottom_pop_count != 0)) begin
                apparatus_fail("release-phase-preserves-fifo", phase_case,
                               32'h0200_0022,
                               {top_count[3:0], bottom_count[3:0],
                                top_read_pointer, bottom_read_pointer,
                                top_write_pointer, bottom_write_pointer});
            end
            release_phase_cases = release_phase_cases + 1;
        end
    endtask

    initial begin
        integer boundary;
        integer phase_case;

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

        expected_words[0] = 32'hf81e0088;
        expected_words[1] = 32'h092d1199;
        expected_words[2] = 32'h1a3c22aa;
        expected_words[3] = 32'h2b4b33bb;
        expected_words[4] = 32'h3c5a44cc;
        expected_words[5] = 32'h4d6955dd;
        expected_words[6] = 32'h5e7866ee;
        expected_words[7] = 32'h6f8777ff;
        expected_words[8] = 32'h3c3ca5a5;

        top_records[0] = {8'hA5, 64'h7766554433221100, 64'hFFEEDDCCBBAA9988};
        bottom_records[0] = {8'h3C, 64'h6F5E4D3C2B1A09F8, 64'h8778695A4B3C2D1E};
        top_records[1] = {8'h5A, 64'h0123456789ABCDEF, 64'h0F1E2D3C4B5A6978};
        bottom_records[1] = {8'hC3, 64'hFEDCBA9876543210, 64'hF0E1D2C3B4A59687};

        top_pop_count = 0;
        bottom_pop_count = 0;
        replay_bursts = 0;
        normal_bursts = 0;
        lane_bytes = 0;
        premature_pops = 0;
        global_reset_cases = 0;
        failing_mask = 0;
        passing_boundaries = 0;
        release_phase_cases = 0;
        full_clock_abort_samples = 0;

        for (boundary = 0; boundary < 9; boundary = boundary + 1)
            run_abort_boundary(boundary);

        run_normal_transaction();
        run_global_reset_during_partial();

        if ($test$plusargs("BASELINE_ABORT_RELEASE_PHASE")) begin
            for (phase_case = 0; phase_case < 3; phase_case = phase_case + 1)
                run_release_phase_case(phase_case);
            if ((release_phase_cases == 3) && (full_clock_abort_samples == 3)) begin
                $display("@@BASELINE_SERIAL_ABORT_RELEASE_PHASE_PASS@@ cases=3 near_edge_ps=2 full_clock_abort_samples=3 asynchronous_resets=0");
            end else begin
                apparatus_fail("release-phase-aggregate", -1, 32'h0000_0303,
                               {16'd0, release_phase_cases[7:0],
                                full_clock_abort_samples[7:0]});
            end
        end

        if ((failing_mask == 9'h1fe) &&
            (passing_boundaries == 1) &&
            (normal_bursts == 9) &&
            (premature_pops == 0) &&
            (global_reset_cases == 1)) begin
            $display("@@BASELINE_SERIAL_ABORT_RED@@ failing_boundaries=1,2,3,4,5,6,7,8 reason=serializer_progress_survives_chip_select_release");
        end else if ((failing_mask == 0) &&
                     (passing_boundaries == 9) &&
                     (replay_bursts == 81) &&
                     (normal_bursts == 9) &&
                     (lane_bytes == 360) &&
                     (premature_pops == 0) &&
                     (global_reset_cases == 1)) begin
            $display("@@BASELINE_SERIAL_ABORT_ACCEPTANCE_PASS@@ boundaries=9 replay_bursts=81 normal_bursts=9 lane_bytes=360 premature_pops=0 global_reset_cases=1");
        end else begin
            apparatus_fail("aggregate-result", -1, 32'h0009_0951,
                           {failing_mask[8:0], passing_boundaries[3:0],
                            replay_bursts[7:0], normal_bursts[3:0],
                            premature_pops[3:0], global_reset_cases[2:0]});
        end

        $finish;
    end
endmodule

`default_nettype wire
