`timescale 1ns/1ps
`default_nettype none

module tb_opendvs_self_delimiting_packet_path;
    localparam string PASS_MARKER =
        "@@OPENDVS_SELF_DELIMITING_PACKET_PATH_PASS@@ rtl_literals=6 grammar_literals=7 populations=128 padding_residues=4 abort_prefixes=319 banks=1 max_bytes=40 plants=12";
    localparam string FAIL_MARKER =
        "@@OPENDVS_SELF_DELIMITING_PACKET_PATH_FAIL@@";

    logic clk_i = 1'b0;
    always #5 clk_i = ~clk_i;

    logic arst_ni = 1'b0;
    logic sync_mode_active_i = 1'b0;
    logic sync_mode_entry_i = 1'b0;
    logic drain_i = 1'b0;
    logic top_fragment_valid_i = 1'b0;
    wire top_fragment_ready_o;
    logic top_fragment_raw_i = 1'b0;
    logic [4:0] top_fragment_length_i = 5'd0;
    logic [135:0] top_fragment_payload_i = 136'd0;
    logic bottom_fragment_valid_i = 1'b0;
    wire bottom_fragment_ready_o;
    logic bottom_fragment_raw_i = 1'b0;
    logic [4:0] bottom_fragment_length_i = 5'd0;
    logic [135:0] bottom_fragment_payload_i = 136'd0;
    logic encoder_quiescent_i = 1'b1;
    logic serial_boundary_quiescent_i = 1'b1;
    logic [1:0] serial_consume_i = 2'b00;
    logic serial_beat_complete_i = 1'b0;
    logic stream_abort_i = 1'b0;
    wire core_admit_enable_o;
    wire packet_ready_o;
    wire [15:0] serial_data_0_o;
    wire [15:0] serial_data_1_o;
    wire quiescent_o;
    wire sticky_fault_o;
    wire [7:0] sequence_o;
    wire [1:0] mode_epoch_o;
    wire [5:0] packet_bytes_o;
    wire [3:0] beat_index_o;
    wire completion_pending_o;

    opendvs_self_delimiting_packet_path dut (
        .clk_i(clk_i),
        .arst_ni(arst_ni),
        .sync_mode_active_i(sync_mode_active_i),
        .sync_mode_entry_i(sync_mode_entry_i),
        .drain_i(drain_i),
        .top_fragment_valid_i(top_fragment_valid_i),
        .top_fragment_ready_o(top_fragment_ready_o),
        .top_fragment_raw_i(top_fragment_raw_i),
        .top_fragment_length_i(top_fragment_length_i),
        .top_fragment_payload_i(top_fragment_payload_i),
        .bottom_fragment_valid_i(bottom_fragment_valid_i),
        .bottom_fragment_ready_o(bottom_fragment_ready_o),
        .bottom_fragment_raw_i(bottom_fragment_raw_i),
        .bottom_fragment_length_i(bottom_fragment_length_i),
        .bottom_fragment_payload_i(bottom_fragment_payload_i),
        .encoder_quiescent_i(encoder_quiescent_i),
        .serial_boundary_quiescent_i(serial_boundary_quiescent_i),
        .serial_consume_i(serial_consume_i),
        .serial_beat_complete_i(serial_beat_complete_i),
        .stream_abort_i(stream_abort_i),
        .core_admit_enable_o(core_admit_enable_o),
        .packet_ready_o(packet_ready_o),
        .serial_data_0_o(serial_data_0_o),
        .serial_data_1_o(serial_data_1_o),
        .quiescent_o(quiescent_o),
        .sticky_fault_o(sticky_fault_o),
        .sequence_o(sequence_o),
        .mode_epoch_o(mode_epoch_o),
        .packet_bytes_o(packet_bytes_o),
        .beat_index_o(beat_index_o),
        .completion_pending_o(completion_pending_o)
    );

    // Positional guard freezes the exact 31-port order as well as the names
    // checked by the Python preflight.
    wire guard_top_ready;
    wire guard_bottom_ready;
    wire guard_core_admit;
    wire guard_packet_ready;
    wire [15:0] guard_data_0;
    wire [15:0] guard_data_1;
    wire guard_quiescent;
    wire guard_fault;
    wire [7:0] guard_sequence;
    wire [1:0] guard_epoch;
    wire [5:0] guard_packet_bytes;
    wire [3:0] guard_beat_index;
    wire guard_pending;
    opendvs_self_delimiting_packet_path exact_31_port_guard (
        1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
        1'b0, guard_top_ready, 1'b0, 5'd0, 136'd0,
        1'b0, guard_bottom_ready, 1'b0, 5'd0, 136'd0,
        1'b1, 1'b1, 2'b00, 1'b0, 1'b0,
        guard_core_admit, guard_packet_ready, guard_data_0, guard_data_1,
        guard_quiescent, guard_fault, guard_sequence, guard_epoch,
        guard_packet_bytes, guard_beat_index, guard_pending
    );

    logic [7:0] expected_body [0:35];
    logic [7:0] expected_packet [0:39];
    integer expected_body_length;
    integer expected_packet_length;
    integer population_case_count;
    integer abort_prefix_count;
    integer literal_case_count;
    task automatic fail(input string check_name, input string message);
        begin
            $display("%s check=%s time=%0t message=%s",
                     FAIL_MARKER, check_name, $time, message);
            $finish_and_return(1);
        end
    endtask

    function automatic [7:0] crc8_byte(
        input [7:0] crc_in,
        input [7:0] data
    );
        reg [7:0] crc;
        integer bit_index;
        begin
            crc = crc_in ^ data;
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1)
                crc = crc[7] ? ((crc << 1) ^ 8'h07) : (crc << 1);
            crc8_byte = crc;
        end
    endfunction

    function automatic [127:0] patterned_mask(
        input integer population,
        input integer pattern_index
    );
        integer item;
        integer position;
        begin
            patterned_mask = 128'd0;
            for (item = 0; item < population; item = item + 1) begin
                case (pattern_index)
                    0: position = item;
                    1: position = 127 - item;
                    default: begin
                        if (item < 64)
                            position = item * 2;
                        else
                            position = ((item - 64) * 2) + 1;
                    end
                endcase
                patterned_mask[position] = 1'b1;
            end
        end
    endfunction

    task automatic clear_expected;
        integer index;
        begin
            expected_body_length = 0;
            expected_packet_length = 0;
            for (index = 0; index < 36; index = index + 1)
                expected_body[index] = 8'h00;
            for (index = 0; index < 40; index = index + 1)
                expected_packet[index] = 8'h00;
        end
    endtask

    task automatic append_expected_record(
        input         tier,
        input         polarity,
        input [5:0]   row,
        input [127:0] mask
    );
        integer population;
        integer column;
        integer emitted;
        integer index;
        begin
            population = 0;
            for (column = 0; column < 128; column = column + 1)
                population = population + mask[column];
            if ((population < 1) || (population > 128))
                fail("oracle_population", "independent oracle population outside [1,128]");
            expected_body[expected_body_length] =
                {(population <= 15), polarity, 6'b000000};
            expected_body[expected_body_length + 1] = {1'b0, tier, row};
            if (population <= 15) begin
                emitted = 0;
                for (column = 127; column >= 0; column = column - 1) begin
                    if (mask[column]) begin
                        emitted = emitted + 1;
                        expected_body[expected_body_length + 1 + emitted] =
                            {(emitted == population), column[6:0]};
                    end
                end
                expected_body_length = expected_body_length + population + 2;
            end else begin
                for (index = 0; index < 16; index = index + 1)
                    expected_body[expected_body_length + 2 + index] =
                        mask[8*index +: 8];
                expected_body_length = expected_body_length + 18;
            end
            if (expected_body_length > 36)
                fail("oracle_body_bound", "independent oracle exceeded 36 bytes");
        end
    endtask

    task automatic finalize_expected(
        input [7:0] sequence_value,
        input [1:0] epoch
    );
        integer index;
        reg [7:0] crc;
        begin
            expected_packet[0] = {4'h2, 2'b01, epoch};
            expected_packet[1] = sequence_value;
            expected_packet[2] = expected_body_length[7:0];
            crc = 8'h00;
            crc = crc8_byte(crc, expected_packet[0]);
            crc = crc8_byte(crc, expected_packet[1]);
            crc = crc8_byte(crc, expected_packet[2]);
            for (index = 0; index < expected_body_length; index = index + 1)
                crc = crc8_byte(crc, expected_body[index]);
            expected_packet[3] = crc;
            for (index = 0; index < expected_body_length; index = index + 1)
                expected_packet[4 + index] = expected_body[index];
            expected_packet_length = 4 + (((expected_body_length + 3) / 4) * 4);
            for (index = 4 + expected_body_length;
                 index < expected_packet_length; index = index + 1)
                expected_packet[index] = 8'h00;
        end
    endtask

    task automatic make_fragment(
        input         tier,
        input         polarity,
        input [5:0]   row,
        input integer population,
        input integer pattern_index,
        output        is_raw,
        output [4:0]  length,
        output [135:0] payload,
        output [127:0] mask
    );
        reg raw_work;
        reg [4:0] length_work;
        reg [135:0] payload_work;
        reg [127:0] mask_work;
        integer column;
        integer emitted;
        begin
            mask_work = patterned_mask(population, pattern_index);
            payload_work = 136'd0;
            if (population <= 15) begin
                raw_work = 1'b0;
                length_work = population + 2;
                payload_work[7:0] = {1'b1, polarity, 6'b000000};
                payload_work[15:8] = {1'b0, tier, row};
                emitted = 0;
                for (column = 127; column >= 0; column = column - 1) begin
                    if (mask_work[column]) begin
                        emitted = emitted + 1;
                        payload_work[8*(emitted+1) +: 8] =
                            {(emitted == population), column[6:0]};
                    end
                end
            end else begin
                raw_work = 1'b1;
                length_work = 5'd17;
                payload_work[127:0] = mask_work;
                payload_work[135:128] = {
                    (polarity ? 2'b10 : 2'b01), row
                };
            end
            is_raw = raw_work;
            length = length_work;
            payload = payload_work;
            mask = mask_work;
        end
    endtask

    task automatic clear_inputs;
        begin
            sync_mode_entry_i = 1'b0;
            drain_i = 1'b0;
            top_fragment_valid_i = 1'b0;
            top_fragment_raw_i = 1'b0;
            top_fragment_length_i = 5'd0;
            top_fragment_payload_i = 136'd0;
            bottom_fragment_valid_i = 1'b0;
            bottom_fragment_raw_i = 1'b0;
            bottom_fragment_length_i = 5'd0;
            bottom_fragment_payload_i = 136'd0;
            encoder_quiescent_i = 1'b1;
            serial_boundary_quiescent_i = 1'b1;
            serial_consume_i = 2'b00;
            serial_beat_complete_i = 1'b0;
            stream_abort_i = 1'b0;
        end
    endtask

    task automatic hard_reset;
        begin
            @(negedge clk_i);
            clear_inputs();
            sync_mode_active_i = 1'b0;
            arst_ni = 1'b0;
            #1;
            if ({top_fragment_ready_o, bottom_fragment_ready_o,
                 core_admit_enable_o, packet_ready_o, serial_data_0_o,
                 serial_data_1_o, sticky_fault_o, sequence_o,
                 packet_bytes_o, beat_index_o, completion_pending_o} !== '0)
                fail("reset_clamp", "visible state was not clamped by asynchronous reset");
            if (mode_epoch_o !== 2'b11)
                fail("reset_epoch", "reset epoch was not seeded to three");
            repeat (2) @(posedge clk_i);
            @(negedge clk_i);
            arst_ni = 1'b1;
            @(posedge clk_i);
            #1;
            if (!quiescent_o)
                fail("reset_quiescent", "empty reset state was not quiescent");
        end
    endtask

    task automatic pulse_mode_entry;
        begin
            @(negedge clk_i);
            sync_mode_active_i = 1'b1;
            sync_mode_entry_i = 1'b1;
            @(posedge clk_i);
            #1;
            @(negedge clk_i);
            sync_mode_entry_i = 1'b0;
        end
    endtask

    task automatic set_epoch(input integer target_epoch);
        integer count;
        begin
            for (count = 0; count <= target_epoch; count = count + 1)
                pulse_mode_entry();
            if (mode_epoch_o !== target_epoch[1:0])
                fail("epoch_entry", "mode entry did not establish target epoch");
            if (sequence_o !== 8'h00)
                fail("entry_sequence_reset", "mode entry did not reset sequence");
        end
    endtask

    task automatic drive_single_fragment(
        input tier,
        input is_raw,
        input [4:0] length,
        input [135:0] payload
    );
        begin
            @(negedge clk_i);
            if (!tier) begin
                top_fragment_valid_i = 1'b1;
                top_fragment_raw_i = is_raw;
                top_fragment_length_i = length;
                top_fragment_payload_i = payload;
            end else begin
                bottom_fragment_valid_i = 1'b1;
                bottom_fragment_raw_i = is_raw;
                bottom_fragment_length_i = length;
                bottom_fragment_payload_i = payload;
            end
            #1;
            if (top_fragment_ready_o || bottom_fragment_ready_o)
                fail("early_fragment_ack", "fragment ready asserted before commit edge");
            @(posedge clk_i);
            #1;
            if ((!tier && (!top_fragment_ready_o || bottom_fragment_ready_o)) ||
                (tier && (!bottom_fragment_ready_o || top_fragment_ready_o)))
                fail("atomic_fragment_ack", "fragment ready did not identify atomic commit");
            if (!packet_ready_o)
                fail("immediate_closure", "eligible fragment did not close immediately");
            @(negedge clk_i);
            top_fragment_valid_i = 1'b0;
            bottom_fragment_valid_i = 1'b0;
            top_fragment_payload_i = ~payload;
            bottom_fragment_payload_i = ~payload;
            @(posedge clk_i);
            #1;
            if (top_fragment_ready_o || bottom_fragment_ready_o)
                fail("ready_pulse", "fragment ready lasted more than one cycle");
        end
    endtask

    task automatic drive_pair_fragments(
        input top_raw,
        input [4:0] top_length,
        input [135:0] top_payload,
        input bottom_raw,
        input [4:0] bottom_length,
        input [135:0] bottom_payload
    );
        begin
            @(negedge clk_i);
            top_fragment_valid_i = 1'b1;
            top_fragment_raw_i = top_raw;
            top_fragment_length_i = top_length;
            top_fragment_payload_i = top_payload;
            bottom_fragment_valid_i = 1'b1;
            bottom_fragment_raw_i = bottom_raw;
            bottom_fragment_length_i = bottom_length;
            bottom_fragment_payload_i = bottom_payload;
            #1;
            if (top_fragment_ready_o || bottom_fragment_ready_o)
                fail("early_fragment_ack", "paired ready asserted before commit edge");
            @(posedge clk_i);
            #1;
            if (!top_fragment_ready_o || !bottom_fragment_ready_o ||
                !packet_ready_o)
                fail("paired_atomic_commit", "paired fragments did not commit atomically");
            @(negedge clk_i);
            top_fragment_valid_i = 1'b0;
            bottom_fragment_valid_i = 1'b0;
            top_fragment_payload_i = ~top_payload;
            bottom_fragment_payload_i = ~bottom_payload;
            @(posedge clk_i);
            #1;
        end
    endtask

    task automatic check_current_beat(input string check_name);
        integer offset;
        begin
            offset = beat_index_o * 4;
            if (serial_data_0_o !== {expected_packet[offset+1], expected_packet[offset]})
                fail(check_name, "serializer word zero disagreed with lane bytes 1 and 0");
            if (serial_data_1_o !== {expected_packet[offset+3], expected_packet[offset+2]})
                fail(check_name, "serializer word one disagreed with lane bytes 3 and 2");
        end
    endtask

    task automatic observe_current_serial_bit(
        input integer bit_in_beat,
        input integer serialized_bit,
        input string check_name
    );
        integer lane;
        integer lane_bit;
        integer packet_byte;
        reg observed_bit;
        reg expected_bit;
        begin
            lane = bit_in_beat / 8;
            lane_bit = bit_in_beat % 8;
            packet_byte = (beat_index_o * 4) + lane;
            case (lane)
                0: observed_bit = serial_data_0_o[7-lane_bit];
                1: observed_bit = serial_data_0_o[15-lane_bit];
                2: observed_bit = serial_data_1_o[7-lane_bit];
                default: observed_bit = serial_data_1_o[15-lane_bit];
            endcase
            expected_bit = expected_packet[packet_byte][7-lane_bit];
            if (observed_bit !== expected_bit)
                fail(check_name,
                     $sformatf("serialized prefix bit %0d differed", serialized_bit));
        end
    endtask

    task automatic consume_current_beat(input string check_name);
        reg [7:0] sequence_before;
        reg [3:0] beat_before;
        begin
            sequence_before = sequence_o;
            beat_before = beat_index_o;
            @(negedge clk_i);
            serial_consume_i = 2'b11;
            @(posedge clk_i);
            #1;
            if (!completion_pending_o || beat_index_o !== beat_before ||
                sequence_o !== sequence_before || !packet_ready_o)
                fail(check_name, "look-ahead consume advanced or retired the packet");
            @(negedge clk_i);
            serial_consume_i = 2'b00;
            serial_beat_complete_i = 1'b1;
            @(posedge clk_i);
            #1;
            @(negedge clk_i);
            serial_beat_complete_i = 1'b0;
        end
    endtask

    task automatic verify_and_retire(input string check_name);
        integer beat;
        integer beats;
        reg [7:0] sequence_before;
        begin
            beats = expected_packet_length / 4;
            if (packet_bytes_o !== expected_packet_length)
                fail(check_name, "packet byte count differed from independent oracle");
            sequence_before = sequence_o;
            for (beat = 0; beat < beats; beat = beat + 1) begin
                if (beat_index_o !== beat[3:0])
                    fail(check_name, "beat index differed before serialization");
                check_current_beat(check_name);
                consume_current_beat(check_name);
                if (beat < beats - 1) begin
                    if (!packet_ready_o || beat_index_o !== (beat + 1))
                        fail(check_name, "non-final completion did not advance one beat");
                end else begin
                    if (packet_ready_o || sequence_o !== (sequence_before + 8'd1))
                        fail(check_name, "final completion did not retire exactly once");
                end
            end
        end
    endtask

    task automatic assert_literal_vector(
        input integer wire_bytes,
        input [319:0] packed_literal,
        input string check_name
    );
        integer index;
        begin
            if (expected_packet_length != wire_bytes)
                fail(check_name, "literal wire length differed");
            for (index = 0; index < wire_bytes; index = index + 1)
                if (expected_packet[index] !==
                    packed_literal[(wire_bytes*8-1)-(index*8) -: 8])
                    fail(check_name, $sformatf("literal byte %0d differed", index));
        end
    endtask

    task automatic commit_record_case(
        input tier,
        input polarity,
        input [5:0] row,
        input integer population,
        input integer pattern_index,
        input string check_name
    );
        reg raw;
        reg [4:0] length;
        reg [135:0] payload;
        reg [127:0] mask;
        begin
            make_fragment(tier, polarity, row, population, pattern_index,
                          raw, length, payload, mask);
            clear_expected();
            append_expected_record(tier, polarity, row, mask);
            finalize_expected(sequence_o, mode_epoch_o);
            drive_single_fragment(tier, raw, length, payload);
            verify_and_retire(check_name);
        end
    endtask

    task automatic advance_sequence(input integer count);
        integer index;
        begin
            for (index = 0; index < count; index = index + 1)
                commit_record_case(1'b0, index[0], index[5:0], 1, 1,
                                   "sequence_advance_fixture");
        end
    endtask

    task automatic run_literal_cases;
        reg raw_top;
        reg raw_bottom;
        reg [4:0] length_top;
        reg [4:0] length_bottom;
        reg [135:0] payload_top;
        reg [135:0] payload_bottom;
        reg [127:0] mask_top;
        reg [127:0] mask_bottom;
        begin
            // position-p1
            hard_reset(); set_epoch(0);
            make_fragment(0, 0, 0, 1, 1, raw_top, length_top, payload_top, mask_top);
            clear_expected(); append_expected_record(0, 0, 0, mask_top);
            finalize_expected(sequence_o, mode_epoch_o);
            assert_literal_vector(8, 320'h2400035d8000ff00, "literal_position_p1");
            drive_single_fragment(0, raw_top, length_top, payload_top);
            verify_and_retire("literal_position_p1"); literal_case_count = literal_case_count + 1;

            // position-p2
            hard_reset(); set_epoch(1); advance_sequence(255);
            mask_bottom = 128'd0;
            mask_bottom[127] = 1'b1;
            mask_bottom[0] = 1'b1;
            payload_bottom = 136'd0;
            payload_bottom[7:0] = 8'hc0;
            payload_bottom[15:8] = 8'h7f;
            payload_bottom[23:16] = 8'h7f;
            payload_bottom[31:24] = 8'h80;
            raw_bottom = 1'b0;
            length_bottom = 5'd4;
            clear_expected(); append_expected_record(1, 1, 63, mask_bottom);
            finalize_expected(sequence_o, mode_epoch_o);
            assert_literal_vector(8, 320'h25ff0449c07f7f80, "literal_position_p2");
            drive_single_fragment(1, raw_bottom, length_bottom, payload_bottom);
            verify_and_retire("literal_position_p2"); literal_case_count = literal_case_count + 1;

            // position-p3 and the explicit first-beat lane-bit fixture.
            hard_reset(); set_epoch(2); advance_sequence(16);
            mask_top = 128'd0; mask_top[127]=1'b1; mask_top[64]=1'b1; mask_top[0]=1'b1;
            payload_top = 136'd0; payload_top[7:0]=8'hc0; payload_top[15:8]=8'h05;
            payload_top[23:16]=8'h7f; payload_top[31:24]=8'h40; payload_top[39:32]=8'h80;
            raw_top=0; length_top=5;
            clear_expected(); append_expected_record(0, 1, 5, mask_top);
            finalize_expected(sequence_o, mode_epoch_o);
            assert_literal_vector(12, 320'h261005b9c0057f4080000000, "literal_position_p3");
            drive_single_fragment(0, raw_top, length_top, payload_top);
            if ({serial_data_1_o[15],serial_data_1_o[7],serial_data_0_o[15],serial_data_0_o[7]} !==
                {expected_packet[3][7],expected_packet[2][7],expected_packet[1][7],expected_packet[0][7]})
                fail("lane_msb_first", "first serialized lane bit was not each byte MSB");
            verify_and_retire("literal_position_p3"); literal_case_count = literal_case_count + 1;

            // position-p4
            hard_reset(); set_epoch(3); advance_sequence(17);
            mask_bottom=128'd0; mask_bottom[127]=1; mask_bottom[96]=1; mask_bottom[32]=1; mask_bottom[0]=1;
            payload_bottom=136'd0; payload_bottom[7:0]=8'h80; payload_bottom[15:8]=8'h47;
            payload_bottom[23:16]=8'h7f; payload_bottom[31:24]=8'h60;
            payload_bottom[39:32]=8'h20; payload_bottom[47:40]=8'h80;
            raw_bottom=0; length_bottom=6;
            clear_expected(); append_expected_record(1,0,7,mask_bottom);
            finalize_expected(sequence_o,mode_epoch_o);
            assert_literal_vector(12,320'h2711068280477f6020800000,"literal_position_p4");
            drive_single_fragment(1,raw_bottom,length_bottom,payload_bottom);
            verify_and_retire("literal_position_p4"); literal_case_count=literal_case_count+1;

            // raw-p16-direct-mask
            hard_reset(); set_epoch(3); advance_sequence(126);
            mask_bottom=128'd0;
            mask_bottom[0]=1; mask_bottom[1]=1; mask_bottom[2]=1; mask_bottom[3]=1;
            mask_bottom[7]=1; mask_bottom[8]=1; mask_bottom[9]=1; mask_bottom[15]=1;
            mask_bottom[63]=1; mask_bottom[64]=1; mask_bottom[65]=1; mask_bottom[71]=1;
            mask_bottom[72]=1; mask_bottom[80]=1; mask_bottom[120]=1; mask_bottom[127]=1;
            payload_bottom=136'd0; payload_bottom[127:0]=mask_bottom; payload_bottom[135:128]=8'haa;
            raw_bottom=1; length_bottom=17;
            clear_expected(); append_expected_record(1,1,42,mask_bottom);
            finalize_expected(sequence_o,mode_epoch_o);
            assert_literal_vector(24,320'h277e120b406a8f8300000000008083010100000000810000,
                                  "literal_raw_p16");
            drive_single_fragment(1,raw_bottom,length_bottom,payload_bottom);
            verify_and_retire("literal_raw_p16"); literal_case_count=literal_case_count+1;

            // raw-p128-two-record-max
            hard_reset(); set_epoch(2); advance_sequence(254);
            make_fragment(0,0,0,128,0,raw_top,length_top,payload_top,mask_top);
            make_fragment(1,1,63,128,0,raw_bottom,length_bottom,payload_bottom,mask_bottom);
            clear_expected(); append_expected_record(0,0,0,mask_top);
            append_expected_record(1,1,63,mask_bottom);
            finalize_expected(sequence_o,mode_epoch_o);
            assert_literal_vector(40,
                320'h26fe24930000ffffffffffffffffffffffffffffffff407fffffffffffffffffffffffffffffffff,
                "literal_raw_p128_max");
            drive_pair_fragments(raw_top,length_top,payload_top,
                                 raw_bottom,length_bottom,payload_bottom);
            verify_and_retire("literal_raw_p128_max"); literal_case_count=literal_case_count+1;
        end
    endtask

    task automatic run_population_matrix;
        integer population;
        integer tier;
        integer polarity;
        integer row_case;
        reg [5:0] row;
        begin
            hard_reset(); set_epoch(0);
            population_case_count = 0;
            for (population = 1; population <= 128; population = population + 1)
                for (tier = 0; tier < 2; tier = tier + 1)
                    for (polarity = 0; polarity < 2; polarity = polarity + 1)
                        for (row_case = 0; row_case < 2; row_case = row_case + 1) begin
                            row = row_case ? 6'd63 : 6'd0;
                            commit_record_case(tier[0], polarity[0], row,
                                               population, population % 3,
                                               "population_matrix");
                            population_case_count = population_case_count + 1;
                        end
            if (population_case_count != 1024)
                fail("population_count", "population/tier/label/row matrix count differed");
        end
    endtask

    task automatic run_order_backpressure_and_late_fragment;
        reg top_raw;
        reg bottom_raw;
        reg [4:0] top_length;
        reg [4:0] bottom_length;
        reg [135:0] top_payload;
        reg [135:0] bottom_payload;
        reg [127:0] top_mask;
        reg [127:0] bottom_mask;
        reg [15:0] held_word;
        begin
            hard_reset(); set_epoch(0);
            make_fragment(0,0,1,3,1,top_raw,top_length,top_payload,top_mask);
            make_fragment(1,1,2,4,1,bottom_raw,bottom_length,bottom_payload,bottom_mask);
            clear_expected(); append_expected_record(0,0,1,top_mask);
            append_expected_record(1,1,2,bottom_mask); finalize_expected(sequence_o,mode_epoch_o);
            drive_pair_fragments(top_raw,top_length,top_payload,
                                 bottom_raw,bottom_length,bottom_payload);
            verify_and_retire("round_robin_top_first");

            clear_expected(); append_expected_record(1,1,2,bottom_mask);
            append_expected_record(0,0,1,top_mask); finalize_expected(sequence_o,mode_epoch_o);
            drive_pair_fragments(top_raw,top_length,top_payload,
                                 bottom_raw,bottom_length,bottom_payload);
            verify_and_retire("round_robin_bottom_first");

            // One-bank backpressure and late-fragment exclusion.
            clear_expected(); append_expected_record(0,0,1,top_mask);
            finalize_expected(sequence_o,mode_epoch_o);
            drive_single_fragment(0,top_raw,top_length,top_payload);
            held_word = serial_data_0_o;
            @(negedge clk_i);
            bottom_fragment_valid_i=1'b1; bottom_fragment_raw_i=bottom_raw;
            bottom_fragment_length_i=bottom_length;
            bottom_fragment_payload_i=bottom_payload;
            repeat (3) begin
                @(posedge clk_i); #1;
                if (bottom_fragment_ready_o || serial_data_0_o !== held_word)
                    fail("bank_overwrite", "full bank acknowledged or changed for late fragment");
            end
            @(negedge clk_i); bottom_fragment_valid_i=1'b0;
            verify_and_retire("late_fragment_first_packet");
            clear_expected(); append_expected_record(1,1,2,bottom_mask);
            finalize_expected(sequence_o,mode_epoch_o);
            drive_single_fragment(1,bottom_raw,bottom_length,bottom_payload);
            verify_and_retire("late_fragment_next_packet");
        end
    endtask

    task automatic commit_max_packet;
        reg top_raw;
        reg bottom_raw;
        reg [4:0] top_length;
        reg [4:0] bottom_length;
        reg [135:0] top_payload;
        reg [135:0] bottom_payload;
        reg [127:0] top_mask;
        reg [127:0] bottom_mask;
        begin
            make_fragment(0,0,0,128,0,top_raw,top_length,top_payload,top_mask);
            make_fragment(1,1,63,128,0,bottom_raw,bottom_length,bottom_payload,bottom_mask);
            clear_expected(); append_expected_record(0,0,0,top_mask);
            append_expected_record(1,1,63,bottom_mask); finalize_expected(sequence_o,mode_epoch_o);
            drive_pair_fragments(top_raw,top_length,top_payload,
                                 bottom_raw,bottom_length,bottom_payload);
        end
    endtask

    // Every fixture mutation is exercised through the same ordinary lifecycle
    // assertions used for product qualification.  The testbench never branches
    // on the requested mutation name.
    task automatic run_mutation_contracts;
        reg top_raw;
        reg bottom_raw;
        reg [4:0] top_length;
        reg [4:0] bottom_length;
        reg [135:0] top_payload;
        reg [135:0] bottom_payload;
        reg [127:0] top_mask;
        reg [127:0] bottom_mask;
        reg [15:0] held_word;
        begin
            // CRC, lane order, early acknowledgement, and consume retirement.
            hard_reset(); set_epoch(0);
            make_fragment(0,0,0,1,1,top_raw,top_length,top_payload,top_mask);
            clear_expected(); append_expected_record(0,0,0,top_mask);
            finalize_expected(sequence_o,mode_epoch_o);
            drive_single_fragment(0,top_raw,top_length,top_payload);
            verify_and_retire("mutation_sparse_packet");

            // Raw right-half/left-half byte order.
            hard_reset(); set_epoch(0);
            make_fragment(1,1,9,16,2,bottom_raw,bottom_length,
                          bottom_payload,bottom_mask);
            clear_expected(); append_expected_record(1,1,9,bottom_mask);
            finalize_expected(sequence_o,mode_epoch_o);
            drive_single_fragment(1,bottom_raw,bottom_length,bottom_payload);
            verify_and_retire("mutation_raw_packet");

            // Persistent paired arbitration order.
            hard_reset(); set_epoch(0);
            make_fragment(0,0,1,2,1,top_raw,top_length,top_payload,top_mask);
            make_fragment(1,1,2,3,1,bottom_raw,bottom_length,
                          bottom_payload,bottom_mask);
            clear_expected(); append_expected_record(0,0,1,top_mask);
            append_expected_record(1,1,2,bottom_mask);
            finalize_expected(sequence_o,mode_epoch_o);
            drive_pair_fragments(top_raw,top_length,top_payload,
                                 bottom_raw,bottom_length,bottom_payload);
            verify_and_retire("mutation_pair_packet");

            // An occupied bank must neither change nor acknowledge a late input.
            hard_reset(); set_epoch(0);
            clear_expected(); append_expected_record(0,0,1,top_mask);
            finalize_expected(sequence_o,mode_epoch_o);
            drive_single_fragment(0,top_raw,top_length,top_payload);
            held_word = serial_data_0_o;
            @(negedge clk_i);
            bottom_fragment_valid_i=1'b1;
            bottom_fragment_raw_i=bottom_raw;
            bottom_fragment_length_i=bottom_length;
            bottom_fragment_payload_i=bottom_payload;
            @(posedge clk_i); #1;
            if (bottom_fragment_ready_o || serial_data_0_o !== held_word)
                fail("bank_overwrite", "occupied bank changed or acknowledged a late fragment");
            @(negedge clk_i); bottom_fragment_valid_i=1'b0;

            // Abort without completion preserves the bank and rewinds it.
            hard_reset(); set_epoch(0); commit_max_packet();
            @(negedge clk_i); stream_abort_i=1'b1;
            @(posedge clk_i); #1;
            @(negedge clk_i); stream_abort_i=1'b0;
            if (!packet_ready_o || beat_index_o !== 0 ||
                completion_pending_o || sequence_o !== 0)
                fail("mutation_abort_replay", "abort did not preserve and rewind the packet");
            check_current_beat("mutation_abort_replay");

            // Abort coincident with a pending non-final completion has priority.
            hard_reset(); set_epoch(0); commit_max_packet();
            @(negedge clk_i); serial_consume_i=2'b11;
            @(posedge clk_i); #1;
            if (!completion_pending_o || beat_index_o !== 0)
                fail("abort_pending_nonfinal", "first beat did not become pending");
            @(negedge clk_i);
            serial_consume_i=2'b00;
            stream_abort_i=1'b1;
            serial_beat_complete_i=1'b1;
            @(posedge clk_i); #1;
            @(negedge clk_i);
            stream_abort_i=1'b0;
            serial_beat_complete_i=1'b0;
            if (!packet_ready_o || beat_index_o !== 0 ||
                completion_pending_o || sequence_o !== 0)
                fail("abort_pending_nonfinal",
                     "abort lost priority to pending non-final completion");
            check_current_beat("abort_pending_nonfinal");

            // Sequence wraps only after final completion.
            hard_reset(); set_epoch(0); advance_sequence(255);
            commit_record_case(0,0,0,1,1,"mutation_sequence_wrap");
            if (sequence_o !== 8'h00)
                fail("mutation_sequence_wrap", "sequence did not wrap modulo 256");

            // Malformed sparse input is faulted and never acknowledged.
            hard_reset(); set_epoch(0);
            make_fragment(0,0,0,2,1,top_raw,top_length,top_payload,top_mask);
            top_payload[8*(top_length-1)+7] = 1'b0;
            @(negedge clk_i);
            top_fragment_valid_i=1'b1;
            top_fragment_raw_i=top_raw;
            top_fragment_length_i=top_length;
            top_fragment_payload_i=top_payload;
            @(posedge clk_i); #1;
            if (!sticky_fault_o || top_fragment_ready_o || packet_ready_o)
                fail("malformed_ack", "malformed sparse fragment did not fail closed");
            @(negedge clk_i); top_fragment_valid_i=1'b0;

            // Drain remains nonquiescent while its retained bank is occupied.
            hard_reset(); set_epoch(0); drain_i=1'b1;
            make_fragment(0,0,0,2,1,top_raw,top_length,top_payload,top_mask);
            clear_expected(); append_expected_record(0,0,0,top_mask);
            finalize_expected(sequence_o,mode_epoch_o);
            drive_single_fragment(0,top_raw,top_length,top_payload);
            if (quiescent_o)
                fail("drain_early_quiescent", "drain reported quiescent with bank occupied");
        end
    endtask

    task automatic run_abort_prefixes;
        integer prefix;
        integer serialized_bit;
        integer beat;
        begin
            abort_prefix_count = 0;
            for (prefix = 0; prefix < 319; prefix = prefix + 1) begin
                hard_reset(); set_epoch(0); commit_max_packet();
                for (serialized_bit = 0; serialized_bit < prefix;
                     serialized_bit = serialized_bit + 1) begin
                    observe_current_serial_bit(serialized_bit % 32,
                                               serialized_bit,
                                               "abort_prefix_observation");
                    if (((serialized_bit + 1) % 32) == 0)
                        consume_current_beat("abort_prefix_before_advance");
                end
                if (beat_index_o !== (prefix / 32))
                    fail("abort_prefix_observation",
                         "serialized prefix did not reach its distinct beat");
                @(negedge clk_i); stream_abort_i=1'b1;
                @(posedge clk_i); #1;
                @(negedge clk_i); stream_abort_i=1'b0;
                if (!packet_ready_o || beat_index_o !== 0 ||
                    completion_pending_o || sequence_o !== 0)
                    fail("abort_replay", "pre-final abort did not rewind immutable packet");
                check_current_beat("abort_replay");
                abort_prefix_count = abort_prefix_count + 1;
            end
            if (abort_prefix_count != 319)
                fail("abort_prefix_count", "abort prefix campaign count differed");

            // Abort also wins when a non-final beat is already pending.
            hard_reset(); set_epoch(0); commit_max_packet();
            @(negedge clk_i); serial_consume_i=2'b11;
            @(posedge clk_i); #1;
            if (!completion_pending_o || beat_index_o !== 0)
                fail("abort_pending_nonfinal", "non-final consume did not become pending");
            @(negedge clk_i); serial_consume_i=2'b00;
            stream_abort_i=1'b1; serial_beat_complete_i=1'b1;
            @(posedge clk_i); #1;
            @(negedge clk_i); stream_abort_i=1'b0; serial_beat_complete_i=1'b0;
            if (!packet_ready_o || beat_index_o !== 0 || sequence_o !== 0 ||
                completion_pending_o)
                fail("abort_pending_nonfinal",
                     "abort/completion priority advanced a non-final pending beat");
            check_current_beat("abort_pending_nonfinal");

            // Abort after final look-ahead consume has priority over completion.
            hard_reset(); set_epoch(0); commit_max_packet();
            for (beat = 0; beat < 9; beat = beat + 1)
                consume_current_beat("abort_after_final_consume_setup");
            @(negedge clk_i); serial_consume_i=2'b11;
            @(posedge clk_i); #1;
            if (!completion_pending_o || beat_index_o !== 9)
                fail("abort_after_final_consume_setup", "final consume did not become pending");
            @(negedge clk_i); serial_consume_i=2'b00;
            stream_abort_i=1'b1; serial_beat_complete_i=1'b1;
            @(posedge clk_i); #1;
            @(negedge clk_i); stream_abort_i=1'b0; serial_beat_complete_i=1'b0;
            if (!packet_ready_o || beat_index_o !== 0 || sequence_o !== 0 ||
                completion_pending_o)
                fail("abort_loses_pending", "abort/completion priority retired final pending beat");
            check_current_beat("abort_loses_pending");
        end
    endtask

    task automatic run_wrap_drain_malformed_reset;
        reg raw;
        reg [4:0] length;
        reg [135:0] payload;
        reg [127:0] mask;
        integer index;
        begin
            // Sequence wraps only on final completion.
            hard_reset(); set_epoch(0); advance_sequence(255);
            if (sequence_o !== 8'hff)
                fail("sequence_no_wrap", "sequence did not reach 255");
            commit_record_case(0,0,0,1,1,"sequence_wrap_packet");
            if (sequence_o !== 8'h00)
                fail("sequence_no_wrap", "sequence did not wrap modulo 256");

            // Epoch starts at three and the first through fifth entries are
            // zero, one, two, three, zero.  Every entry also resets sequence.
            hard_reset();
            for (index = 0; index < 5; index = index + 1) begin
                pulse_mode_entry();
                if (mode_epoch_o !== index[1:0])
                    fail("epoch_wrap", "epoch did not wrap modulo four");
                if (sequence_o !== 0)
                    fail("entry_sequence_reset", "entry did not reset sequence");
            end

            // Synchronous-mode entry owns sequence zero when it coincides with
            // completion of the preceding epoch's final serialized bit.
            hard_reset(); set_epoch(0);
            commit_record_case(0,0,0,1,1,"entry_completion_seed");
            make_fragment(0,0,0,1,1,raw,length,payload,mask);
            clear_expected(); append_expected_record(0,0,0,mask);
            finalize_expected(sequence_o,mode_epoch_o);
            drive_single_fragment(0,raw,length,payload);
            consume_current_beat("entry_completion_collision_setup");
            check_current_beat("entry_completion_collision_setup");
            @(negedge clk_i); serial_consume_i=2'b11;
            @(posedge clk_i); #1;
            if (!completion_pending_o || beat_index_o !== 1)
                fail("entry_completion_collision", "final beat did not become pending");
            @(negedge clk_i);
            serial_consume_i=2'b00;
            serial_beat_complete_i=1'b1;
            sync_mode_entry_i=1'b1;
            @(posedge clk_i); #1;
            if (packet_ready_o || completion_pending_o ||
                sequence_o !== 8'h00 || mode_epoch_o !== 2'd1)
                fail("entry_completion_collision",
                     "mode entry did not dominate coincident final completion");
            @(negedge clk_i);
            serial_beat_complete_i=1'b0;
            sync_mode_entry_i=1'b0;

            // Drain: disable new core admission, still commit an already-held
            // fragment, and wait for bank, pending, encoder, and serial boundary.
            hard_reset(); set_epoch(0);
            drain_i=1'b1; #1;
            if (core_admit_enable_o)
                fail("drain_admission", "drain did not disable core admission");
            if (!quiescent_o)
                fail("drain_empty", "empty drain was not quiescent");
            make_fragment(0,0,0,2,1,raw,length,payload,mask);
            clear_expected(); append_expected_record(0,0,0,mask);
            finalize_expected(sequence_o,mode_epoch_o);
            drive_single_fragment(0,raw,length,payload);
            if (quiescent_o)
                fail("drain_early_quiescent", "drain reported quiescent with bank occupied");
            @(negedge clk_i); serial_consume_i=2'b11;
            @(posedge clk_i); #1;
            if (quiescent_o)
                fail("drain_pending", "drain reported quiescent with completion pending");
            @(negedge clk_i); stream_abort_i=1'b1; serial_consume_i=2'b00;
            @(posedge clk_i); #1;
            @(negedge clk_i); stream_abort_i=1'b0;
            verify_and_retire("drain_retirement");
            encoder_quiescent_i=1'b0; #1;
            if (quiescent_o)
                fail("drain_encoder_boundary", "encoder nonquiescence was ignored");
            encoder_quiescent_i=1'b1; serial_boundary_quiescent_i=1'b0; #1;
            if (quiescent_o)
                fail("drain_serial_boundary", "serial boundary nonquiescence was ignored");
            serial_boundary_quiescent_i=1'b1; #1;
            if (!quiescent_o)
                fail("drain_final_quiescent", "fully drained path was not quiescent");

            // Malformed sparse fragment: missing terminal marker, no ack,
            // sticky fault, and reset-only recovery.
            hard_reset(); set_epoch(0);
            make_fragment(0,0,0,2,1,raw,length,payload,mask);
            payload[8*(length-1)+7] = 1'b0;
            @(negedge clk_i); top_fragment_valid_i=1'b1;
            top_fragment_raw_i=raw; top_fragment_length_i=length;
            top_fragment_payload_i=payload;
            @(posedge clk_i); #1;
            if (!sticky_fault_o || top_fragment_ready_o || packet_ready_o)
                fail("malformed_ack", "malformed sparse fragment did not fail closed");
            @(negedge clk_i); top_fragment_valid_i=1'b0;
            repeat (2) @(posedge clk_i);
            if (!sticky_fault_o || core_admit_enable_o)
                fail("malformed_sticky", "malformed fault was not sticky or did not disable admission");
            hard_reset(); set_epoch(0);
            if (sticky_fault_o)
                fail("malformed_reset_recovery", "reset did not recover malformed fault");

            // Malformed raw fragment: raw length must be exactly 17.
            make_fragment(1,1,63,16,0,raw,length,payload,mask);
            @(negedge clk_i); bottom_fragment_valid_i=1'b1;
            bottom_fragment_raw_i=1'b1; bottom_fragment_length_i=5'd16;
            bottom_fragment_payload_i=payload;
            @(posedge clk_i); #1;
            if (!sticky_fault_o || bottom_fragment_ready_o || packet_ready_o)
                fail("malformed_raw", "malformed raw fragment did not fail closed");

            // Reset while faulted, banked, and completion-pending.
            hard_reset(); set_epoch(0); commit_record_case(0,0,0,1,1,"reset_empty_seed");
            commit_max_packet(); hard_reset();
            set_epoch(0); commit_max_packet();
            @(negedge clk_i); serial_consume_i=2'b11;
            @(posedge clk_i); #1;
            hard_reset();
            if (!quiescent_o || packet_ready_o || completion_pending_o || sticky_fault_o)
                fail("reset_all_states", "reset left stale lifecycle state");
        end
    endtask

    initial begin
        literal_case_count = 0;
        population_case_count = 0;
        abort_prefix_count = 0;
        clear_inputs();
        run_mutation_contracts();
        run_literal_cases();
        run_population_matrix();
        run_order_backpressure_and_late_fragment();
        run_abort_prefixes();
        run_wrap_drain_malformed_reset();
        if (literal_case_count != 6)
            fail("rtl_literal_count", "reachable RTL literal count differed");
        if (population_case_count != 1024 || abort_prefix_count != 319)
            fail("coverage_counts", "frozen exhaustive counts differed");
        $display("%s", PASS_MARKER);
        $finish_and_return(0);
    end

    initial begin
        #500000000;
        fail("watchdog", "testbench exceeded watchdog");
    end
endmodule

`default_nettype wire
