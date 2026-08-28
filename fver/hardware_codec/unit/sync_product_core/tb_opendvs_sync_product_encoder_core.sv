`timescale 1ns/1ps
`default_nettype none

module tb_opendvs_sync_product_encoder_core;
    localparam integer QUEUE_DEPTH = 4;
    localparam integer MAPPING_CASES = 3096;
    localparam integer MAX_WAIT_CYCLES = 2000;

    localparam string PASS_MARKER =
        "@@OPENDVS_SYNC_PRODUCT_CORE_PASS@@ mapping_cases=3096 tiers=2 sparse_boundary=15 raw_boundary=16 queue_depth_test=4";
    localparam string FAIL_MARKER =
        "@@OPENDVS_SYNC_PRODUCT_CORE_FAIL@@";
    localparam string PLANT_MARKER =
        "@@OPENDVS_SYNC_PRODUCT_CORE_PLANT_DETECTED@@";

    logic clk_i = 1'b0;
    always #5 clk_i = ~clk_i;

    logic         arst_ni = 1'b0;
    logic         admit_enable_i = 1'b0;
    logic         top_record_valid_i = 1'b0;
    logic [135:0] top_record_i = '0;
    wire          top_record_accepted_o;
    logic         bottom_record_valid_i = 1'b0;
    logic [135:0] bottom_record_i = '0;
    wire          bottom_record_accepted_o;
    wire          top_fragment_valid_o;
    logic         top_fragment_ready_i = 1'b0;
    wire          top_fragment_raw_o;
    wire [4:0]    top_fragment_length_o;
    wire [135:0]  top_fragment_payload_o;
    wire          bottom_fragment_valid_o;
    logic         bottom_fragment_ready_i = 1'b0;
    wire          bottom_fragment_raw_o;
    wire [4:0]    bottom_fragment_length_o;
    wire [135:0]  bottom_fragment_payload_o;
    wire          quiescent_o;
    wire [31:0]   accepted_count_o;
    wire [31:0]   empty_suppressed_count_o;
    wire [31:0]   illegal_label_count_o;
    wire [31:0]   disabled_suppressed_count_o;
    wire [31:0]   overflow_count_o;
    wire [31:0]   sparse_count_o;
    wire [31:0]   raw_count_o;
    wire [31:0]   retired_count_o;
    wire          sticky_fault_o;

    opendvs_sync_product_encoder_core #(.QUEUE_DEPTH(QUEUE_DEPTH)) dut (
        .clk_i(clk_i),
        .arst_ni(arst_ni),
        .admit_enable_i(admit_enable_i),
        .top_record_valid_i(top_record_valid_i),
        .top_record_i(top_record_i),
        .top_record_accepted_o(top_record_accepted_o),
        .bottom_record_valid_i(bottom_record_valid_i),
        .bottom_record_i(bottom_record_i),
        .bottom_record_accepted_o(bottom_record_accepted_o),
        .top_fragment_valid_o(top_fragment_valid_o),
        .top_fragment_ready_i(top_fragment_ready_i),
        .top_fragment_raw_o(top_fragment_raw_o),
        .top_fragment_length_o(top_fragment_length_o),
        .top_fragment_payload_o(top_fragment_payload_o),
        .bottom_fragment_valid_o(bottom_fragment_valid_o),
        .bottom_fragment_ready_i(bottom_fragment_ready_i),
        .bottom_fragment_raw_o(bottom_fragment_raw_o),
        .bottom_fragment_length_o(bottom_fragment_length_o),
        .bottom_fragment_payload_o(bottom_fragment_payload_o),
        .quiescent_o(quiescent_o),
        .accepted_count_o(accepted_count_o),
        .empty_suppressed_count_o(empty_suppressed_count_o),
        .illegal_label_count_o(illegal_label_count_o),
        .disabled_suppressed_count_o(disabled_suppressed_count_o),
        .overflow_count_o(overflow_count_o),
        .sparse_count_o(sparse_count_o),
        .raw_count_o(raw_count_o),
        .retired_count_o(retired_count_o),
        .sticky_fault_o(sticky_fault_o)
    );

    // Positional elaboration guard: any added, removed, or reordered port makes
    // this exact 29-port contract fail compilation.  The instance stays reset.
    wire guard_top_accepted;
    wire guard_bottom_accepted;
    wire guard_top_valid;
    wire guard_top_raw;
    wire [4:0] guard_top_length;
    wire [135:0] guard_top_payload;
    wire guard_bottom_valid;
    wire guard_bottom_raw;
    wire [4:0] guard_bottom_length;
    wire [135:0] guard_bottom_payload;
    wire guard_quiescent;
    wire [31:0] guard_accepted_count;
    wire [31:0] guard_empty_count;
    wire [31:0] guard_illegal_count;
    wire [31:0] guard_disabled_count;
    wire [31:0] guard_overflow_count;
    wire [31:0] guard_sparse_count;
    wire [31:0] guard_raw_count;
    wire [31:0] guard_retired_count;
    wire guard_sticky_fault;
    opendvs_sync_product_encoder_core #(.QUEUE_DEPTH(QUEUE_DEPTH))
        exact_29_port_guard (
            1'b0, 1'b0, 1'b0,
            1'b0, 136'd0, guard_top_accepted,
            1'b0, 136'd0, guard_bottom_accepted,
            guard_top_valid, 1'b0, guard_top_raw, guard_top_length,
            guard_top_payload,
            guard_bottom_valid, 1'b0, guard_bottom_raw, guard_bottom_length,
            guard_bottom_payload,
            guard_quiescent, guard_accepted_count, guard_empty_count,
            guard_illegal_count, guard_disabled_count, guard_overflow_count,
            guard_sparse_count, guard_raw_count, guard_retired_count,
            guard_sticky_fault
        );

    string plant;
    integer mapping_case_count = 0;
    logic last_top_accepted = 1'b0;
    logic last_bottom_accepted = 1'b0;

    function automatic integer expected_plant_check(
        input string plant_name,
        input string check_name
    );
        begin
            expected_plant_check =
                ((plant_name == "half_order_swap") &&
                 (check_name == "half_order_swap")) ||
                ((plant_name == "ascending_sparse_positions") &&
                 (check_name == "ascending_sparse_positions")) ||
                ((plant_name == "launch_population_16") &&
                 (check_name == "launch_population_16")) ||
                ((plant_name == "nonzero_delta_time") &&
                 (check_name == "nonzero_delta_time")) ||
                ((plant_name == "raw_byte_reversal") &&
                 (check_name == "raw_byte_reversal")) ||
                ((plant_name == "retained_fragment_overwrite") &&
                 (check_name == "retained_fragment_overwrite")) ||
                ((plant_name == "duplicate_retirement") &&
                 (check_name == "duplicate_retirement")) ||
                ((plant_name == "lost_retirement") &&
                 (check_name == "lost_retirement")) ||
                ((plant_name == "overflow_without_sticky_fault") &&
                 (check_name == "overflow_without_sticky_fault"));
        end
    endfunction

    task automatic semantic_fail(input string check_name, input string message);
        begin
            if ((plant != "none") && expected_plant_check(plant, check_name)) begin
                $display("%s plant=%s check=%s", PLANT_MARKER, plant, check_name);
                $finish_and_return(10);
            end
            $display("%s check=%s time=%0t message=%s",
                     FAIL_MARKER, check_name, $time, message);
            $finish_and_return(1);
        end
    endtask

    function automatic [135:0] make_record(
        input logic [1:0] event_mode,
        input logic [5:0] local_row,
        input logic [127:0] mask
    );
        begin
            make_record = {event_mode, local_row, mask[127:64], mask[63:0]};
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

    function automatic integer population128(input logic [127:0] mask);
        integer column;
        begin
            population128 = 0;
            for (column = 0; column < 128; column = column + 1)
                population128 = population128 + mask[column];
        end
    endfunction

    function automatic logic legal_label(input logic [1:0] event_mode);
        begin
            legal_label = (event_mode == 2'b01) || (event_mode == 2'b10);
        end
    endfunction

    function automatic logic label_polarity(input logic [1:0] event_mode);
        begin
            label_polarity = (event_mode == 2'b10);
        end
    endfunction

    function automatic [31:0] saturating_increment(input logic [31:0] value);
        begin
            if (value == 32'hffff_ffff)
                saturating_increment = 32'hffff_ffff;
            else
                saturating_increment = value + 32'd1;
        end
    endfunction

    task automatic reference_encode(
        input  logic         tier,
        input  logic [135:0] record,
        output logic         expected_raw,
        output logic [4:0]   expected_length,
        output logic [135:0] expected_payload
    );
        logic [1:0] event_mode;
        logic [5:0] local_row;
        logic [127:0] mask;
        integer population;
        integer byte_index;
        integer column;
        integer emitted;
        begin
            event_mode = record[135:134];
            local_row = record[133:128];
            mask = {record[127:64], record[63:0]};
            population = population128(mask);
            expected_raw = 1'b0;
            expected_length = 5'd0;
            expected_payload = 136'd0;
            if (population == 0) begin
                expected_raw = 1'b0;
            end else if (population <= 15) begin
                expected_payload[7:0] =
                    {1'b1, label_polarity(event_mode), 6'd0};
                expected_payload[15:8] = {1'b0, tier, local_row};
                emitted = 0;
                byte_index = 2;
                for (column = 127; column >= 0; column = column - 1) begin
                    if (mask[column]) begin
                        emitted = emitted + 1;
                        expected_payload[8*byte_index +: 8] =
                            {(emitted == population), column[6:0]};
                        byte_index = byte_index + 1;
                    end
                end
                expected_length = population + 2;
            end else begin
                expected_raw = 1'b1;
                expected_length = 5'd17;
                for (byte_index = 0; byte_index < 8;
                     byte_index = byte_index + 1) begin
                    expected_payload[8*byte_index +: 8] =
                        record[8*byte_index +: 8];
                    expected_payload[8*(byte_index+8) +: 8] =
                        record[64 + 8*byte_index +: 8];
                end
                expected_payload[135:128] = {event_mode, local_row};
            end
        end
    endtask

    // This decoder is deliberately separate from reference_encode.  It parses
    // the observed wire representation back to semantic label, row, and mask.
    task automatic reference_decode_and_check(
        input logic         tier,
        input logic [135:0] source_record,
        input logic         observed_raw,
        input logic [4:0]   observed_length,
        input logic [135:0] observed_payload,
        input string        check_name
    );
        logic [1:0] source_mode;
        logic [5:0] source_row;
        logic [127:0] source_mask;
        logic [1:0] decoded_mode;
        logic [5:0] decoded_row;
        logic decoded_tier;
        logic [127:0] decoded_mask;
        integer source_population;
        integer byte_index;
        integer position;
        integer previous_position;
        begin
            source_mode = source_record[135:134];
            source_row = source_record[133:128];
            source_mask = {source_record[127:64], source_record[63:0]};
            source_population = population128(source_mask);
            decoded_mode = 2'b00;
            decoded_row = 6'd0;
            decoded_tier = 1'b0;
            decoded_mask = 128'd0;

            if (observed_raw) begin
                if (observed_length != 5'd17)
                    semantic_fail(check_name, "raw decoder length was not 17");
                for (byte_index = 0; byte_index < 8;
                     byte_index = byte_index + 1) begin
                    decoded_mask[8*byte_index +: 8] =
                        observed_payload[8*byte_index +: 8];
                    decoded_mask[64 + 8*byte_index +: 8] =
                        observed_payload[8*(byte_index+8) +: 8];
                end
                decoded_mode = observed_payload[135:134];
                decoded_row = observed_payload[133:128];
                decoded_tier = tier;
            end else begin
                if (observed_length != source_population + 2)
                    semantic_fail(check_name, "sparse decoder length mismatch");
                if (observed_payload[7] !== 1'b1)
                    semantic_fail(check_name, "sparse mode bit was not one");
                if (observed_payload[5:0] !== 6'd0)
                    semantic_fail(check_name, "sparse delta time was not structural zero");
                decoded_mode = observed_payload[6] ? 2'b10 : 2'b01;
                if (observed_payload[15] !== 1'b0)
                    semantic_fail(check_name, "sparse row marker was not zero");
                decoded_tier = observed_payload[14];
                decoded_row = observed_payload[13:8];
                previous_position = 128;
                for (byte_index = 2; byte_index < observed_length;
                     byte_index = byte_index + 1) begin
                    position = observed_payload[8*byte_index +: 7];
                    if ((position >= previous_position) || decoded_mask[position])
                        semantic_fail(check_name,
                                      "sparse positions were not unique descending values");
                    if (observed_payload[8*byte_index+7] !==
                        (byte_index == observed_length-1))
                        semantic_fail(check_name,
                                      "sparse terminal marker was not on the final position");
                    decoded_mask[position] = 1'b1;
                    previous_position = position;
                end
            end

            if (decoded_mode !== source_mode)
                semantic_fail(check_name, "decoded event mode mismatch");
            if (decoded_tier !== tier)
                semantic_fail(check_name, "decoded tier mismatch");
            if (decoded_row !== source_row)
                semantic_fail(check_name, "decoded local row mismatch");
            if (decoded_mask !== source_mask)
                semantic_fail(check_name, "decoded 128-bit mask mismatch");
        end
    endtask

    task automatic check_fragment_values(
        input logic         tier,
        input logic [135:0] source_record,
        input logic         observed_raw,
        input logic [4:0]   observed_length,
        input logic [135:0] observed_payload,
        input string        check_name
    );
        logic expected_raw;
        logic [4:0] expected_length;
        logic [135:0] expected_payload;
        integer byte_index;
        begin
            reference_encode(tier, source_record, expected_raw,
                             expected_length, expected_payload);
            if (observed_raw !== expected_raw)
                semantic_fail(check_name, "fragment raw flag mismatch");
            if (observed_length !== expected_length)
                semantic_fail(check_name, "fragment length mismatch");
            for (byte_index = 0; byte_index < expected_length;
                 byte_index = byte_index + 1)
                if (observed_payload[8*byte_index +: 8] !==
                    expected_payload[8*byte_index +: 8])
                    semantic_fail(check_name,
                                  $sformatf("fragment byte %0d mismatch", byte_index));
            for (byte_index = expected_length; byte_index < 17;
                 byte_index = byte_index + 1)
                if (observed_payload[8*byte_index +: 8] !== 8'h00)
                    semantic_fail(check_name, "unused payload byte was nonzero");
            reference_decode_and_check(tier, source_record, observed_raw,
                                       observed_length, observed_payload,
                                       check_name);
        end
    endtask

    task automatic clear_inputs;
        begin
            top_record_valid_i = 1'b0;
            top_record_i = 136'd0;
            bottom_record_valid_i = 1'b0;
            bottom_record_i = 136'd0;
            top_fragment_ready_i = 1'b0;
            bottom_fragment_ready_i = 1'b0;
        end
    endtask

    task automatic check_reset_clamp;
        begin
            if ({top_record_accepted_o, bottom_record_accepted_o,
                 top_fragment_valid_o, top_fragment_payload_o,
                 bottom_fragment_valid_o, bottom_fragment_payload_o,
                 accepted_count_o, empty_suppressed_count_o,
                 illegal_label_count_o, disabled_suppressed_count_o,
                 overflow_count_o, sparse_count_o, raw_count_o,
                 retired_count_o, sticky_fault_o} !== '0)
                semantic_fail("reset_clamp",
                              "visible state was not zero while reset was asserted");
        end
    endtask

    task automatic hard_reset;
        integer cycle;
        begin
            @(negedge clk_i);
            clear_inputs();
            admit_enable_i = 1'b0;
            arst_ni = 1'b0;
            #0.2;
            check_reset_clamp();
            for (cycle = 0; cycle < 2; cycle = cycle + 1) begin
                @(posedge clk_i);
                #1;
                check_reset_clamp();
            end
            @(negedge clk_i);
            arst_ni = 1'b1;
            admit_enable_i = 1'b1;
            @(posedge clk_i);
            #1;
            if (!quiescent_o)
                semantic_fail("reset_quiescence", "empty core was not quiescent");
            if ({top_fragment_valid_o, bottom_fragment_valid_o,
                 accepted_count_o, empty_suppressed_count_o,
                 illegal_label_count_o, disabled_suppressed_count_o,
                 overflow_count_o, sparse_count_o, raw_count_o,
                 retired_count_o, sticky_fault_o} !== '0)
                semantic_fail("reset_release", "reset state leaked after release");
        end
    endtask

    task automatic pulse_record(
        input logic tier,
        input logic [135:0] record
    );
        begin
            @(negedge clk_i);
            if (!tier) begin
                top_record_i = record;
                top_record_valid_i = 1'b1;
            end else begin
                bottom_record_i = record;
                bottom_record_valid_i = 1'b1;
            end
            @(posedge clk_i);
            #1;
            last_top_accepted = top_record_accepted_o;
            last_bottom_accepted = bottom_record_accepted_o;
            @(negedge clk_i);
            top_record_valid_i = 1'b0;
            bottom_record_valid_i = 1'b0;
            top_record_i = ~record;
            bottom_record_i = ~record;
        end
    endtask

    task automatic pulse_both_records(
        input logic [135:0] top_record,
        input logic [135:0] bottom_record
    );
        begin
            @(negedge clk_i);
            top_record_i = top_record;
            bottom_record_i = bottom_record;
            top_record_valid_i = 1'b1;
            bottom_record_valid_i = 1'b1;
            @(posedge clk_i);
            #1;
            last_top_accepted = top_record_accepted_o;
            last_bottom_accepted = bottom_record_accepted_o;
            @(negedge clk_i);
            top_record_valid_i = 1'b0;
            bottom_record_valid_i = 1'b0;
            top_record_i = ~top_record;
            bottom_record_i = ~bottom_record;
        end
    endtask

    task automatic settle_accept_pulse;
        begin
            @(posedge clk_i);
            #1;
            if (top_record_accepted_o || bottom_record_accepted_o)
                semantic_fail("accepted_pulse_width",
                              "accepted output lasted more than one cycle");
        end
    endtask

    task automatic capture_fragment(
        input  logic         tier,
        output logic         observed_raw,
        output logic [4:0]   observed_length,
        output logic [135:0] observed_payload
    );
        begin
            if (!tier) begin
                observed_raw = top_fragment_raw_o;
                observed_length = top_fragment_length_o;
                observed_payload = top_fragment_payload_o;
            end else begin
                observed_raw = bottom_fragment_raw_o;
                observed_length = bottom_fragment_length_o;
                observed_payload = bottom_fragment_payload_o;
            end
        end
    endtask

    task automatic wait_for_fragment(
        input logic tier,
        input logic [135:0] source_record,
        input integer stall_cycles,
        input string check_name
    );
        logic observed_raw;
        logic [4:0] observed_length;
        logic [135:0] observed_payload;
        logic [31:0] retired_before;
        integer waits;
        integer stall;
        begin
            waits = 0;
            while ((!tier && !top_fragment_valid_o) ||
                   (tier && !bottom_fragment_valid_o)) begin
                @(posedge clk_i);
                #1;
                waits = waits + 1;
                if (waits > MAX_WAIT_CYCLES)
                    semantic_fail("fragment_timeout", "fragment never became valid");
            end
            capture_fragment(tier, observed_raw, observed_length,
                             observed_payload);
            check_fragment_values(tier, source_record, observed_raw,
                                  observed_length, observed_payload, check_name);
            for (stall = 0; stall < stall_cycles; stall = stall + 1) begin
                @(posedge clk_i);
                #1;
                if ((!tier && !top_fragment_valid_o) ||
                    (tier && !bottom_fragment_valid_o))
                    semantic_fail("payload_stability", "stalled valid was lost");
                if (!tier && ({top_fragment_raw_o, top_fragment_length_o,
                               top_fragment_payload_o} !==
                              {observed_raw, observed_length,
                               observed_payload}))
                    semantic_fail("payload_stability", "top fragment changed under stall");
                if (tier && ({bottom_fragment_raw_o,
                              bottom_fragment_length_o,
                              bottom_fragment_payload_o} !==
                             {observed_raw, observed_length,
                              observed_payload}))
                    semantic_fail("payload_stability",
                                  "bottom fragment changed under stall");
            end
            retired_before = retired_count_o;
            @(negedge clk_i);
            if (!tier)
                top_fragment_ready_i = 1'b1;
            else
                bottom_fragment_ready_i = 1'b1;
            @(posedge clk_i);
            #1;
            if (retired_count_o !== saturating_increment(retired_before))
                semantic_fail("exactly_once_retirement",
                              "retirement handshake did not increment once");
            @(negedge clk_i);
            top_fragment_ready_i = 1'b0;
            bottom_fragment_ready_i = 1'b0;
            repeat (2) begin
                @(posedge clk_i);
                #1;
            end
            if (retired_count_o !== saturating_increment(retired_before))
                semantic_fail("exactly_once_retirement",
                              "retirement increment duplicated after handshake");
        end
    endtask

    task automatic run_mapping_corpus;
        integer tier;
        integer polarity_index;
        integer row_index;
        integer population;
        integer pattern_index;
        logic [1:0] event_mode;
        logic [5:0] local_row;
        logic [127:0] mask;
        logic [135:0] record;
        logic [31:0] accepted_before;
        logic [31:0] empty_before;
        begin
            hard_reset();
            mapping_case_count = 0;
            for (tier = 0; tier < 2; tier = tier + 1)
                for (polarity_index = 0; polarity_index < 2;
                     polarity_index = polarity_index + 1)
                    for (row_index = 0; row_index < 2;
                         row_index = row_index + 1)
                        for (population = 0; population <= 128;
                             population = population + 1)
                            for (pattern_index = 0; pattern_index < 3;
                                 pattern_index = pattern_index + 1) begin
                                event_mode = polarity_index ? 2'b10 : 2'b01;
                                local_row = row_index ? 6'd63 : 6'd0;
                                mask = patterned_mask(population, pattern_index);
                                record = make_record(event_mode, local_row, mask);
                                accepted_before = accepted_count_o;
                                empty_before = empty_suppressed_count_o;
                                pulse_record(tier[0], record);
                                mapping_case_count = mapping_case_count + 1;
                                if (population == 0) begin
                                    if (last_top_accepted || last_bottom_accepted)
                                        semantic_fail("mapping_empty_accept",
                                                      "empty mapping case was accepted");
                                    if (accepted_count_o !== accepted_before)
                                        semantic_fail("mapping_empty_accounting",
                                                      "empty case changed accepted count");
                                    if (empty_suppressed_count_o !== empty_before + 1)
                                        semantic_fail("mapping_empty_accounting",
                                                      "empty suppression did not increment");
                                    settle_accept_pulse();
                                    if (top_fragment_valid_o || bottom_fragment_valid_o)
                                        semantic_fail("mapping_empty_fragment",
                                                      "empty case emitted a fragment");
                                end else begin
                                    if ((!tier && !last_top_accepted) ||
                                        (tier && !last_bottom_accepted) ||
                                        (!tier && last_bottom_accepted) ||
                                        (tier && last_top_accepted))
                                        semantic_fail("mapping_acceptance",
                                                      "mapping acceptance tier mismatch");
                                    if (accepted_count_o !== accepted_before + 1)
                                        semantic_fail("mapping_accepted_accounting",
                                                      "accepted mapping count mismatch");
                                    if (quiescent_o)
                                        semantic_fail("mapping_quiescence",
                                                      "quiescent stayed high on acceptance");
                                    settle_accept_pulse();
                                    wait_for_fragment(tier[0], record,
                                                      (mapping_case_count % 3),
                                                      "mapping_fragment");
                                    if (!quiescent_o)
                                        semantic_fail("mapping_conservation",
                                                      "core did not quiesce after retirement");
                                end
                            end

            if (mapping_case_count != MAPPING_CASES)
                semantic_fail("mapping_case_count", "mapping corpus count mismatch");
            if (accepted_count_o !== 32'd3072)
                semantic_fail("mapping_total_accepted", "expected 3072 accepted cases");
            if (empty_suppressed_count_o !== 32'd24)
                semantic_fail("mapping_total_empty", "expected 24 empty cases");
            if (sparse_count_o !== 32'd360)
                semantic_fail("mapping_total_sparse", "expected 360 sparse cases");
            if (raw_count_o !== 32'd2712)
                semantic_fail("mapping_total_raw", "expected 2712 raw cases");
            if (retired_count_o !== 32'd3072)
                semantic_fail("mapping_total_retired", "expected 3072 retirements");
            if ({illegal_label_count_o, disabled_suppressed_count_o,
                 overflow_count_o, sticky_fault_o} !== '0)
                semantic_fail("mapping_clean_accounting",
                              "clean mapping corpus changed fault accounting");
            if (accepted_count_o !== retired_count_o || !quiescent_o)
                semantic_fail("mapping_conservation",
                              "mapping corpus violated conservation");
        end
    endtask

    task automatic run_accounting_priority;
        logic [135:0] legal_empty;
        logic [135:0] illegal_nonempty_a;
        logic [135:0] illegal_nonempty_b;
        begin
            hard_reset();
            legal_empty = make_record(2'b01, 6'h01, 128'd0);
            illegal_nonempty_a = make_record(2'b00, 6'h02, patterned_mask(2, 0));
            illegal_nonempty_b = make_record(2'b11, 6'h03, patterned_mask(3, 1));

            admit_enable_i = 1'b0;
            pulse_both_records(illegal_nonempty_a, legal_empty);
            if (last_top_accepted || last_bottom_accepted ||
                disabled_suppressed_count_o !== 32'd2 ||
                illegal_label_count_o !== 32'd0 ||
                empty_suppressed_count_o !== 32'd0 || sticky_fault_o)
                semantic_fail("disabled_priority",
                              "disabled admission did not dominate both records");
            settle_accept_pulse();

            admit_enable_i = 1'b1;
            pulse_both_records(illegal_nonempty_a, illegal_nonempty_b);
            if (last_top_accepted || last_bottom_accepted ||
                illegal_label_count_o !== 32'd2 || !sticky_fault_o)
                semantic_fail("illegal_accounting",
                              "illegal labels were not independently faulted");
            settle_accept_pulse();

            pulse_both_records(legal_empty, legal_empty);
            if (last_top_accepted || last_bottom_accepted ||
                empty_suppressed_count_o !== 32'd2)
                semantic_fail("empty_accounting",
                              "legal empty masks were not independently suppressed");
            settle_accept_pulse();
            if (accepted_count_o !== 32'd0 ||
                top_fragment_valid_o || bottom_fragment_valid_o || !quiescent_o)
                semantic_fail("suppression_conservation",
                              "suppressed records entered the product pipeline");
        end
    endtask

    task automatic run_simultaneous_and_backpressure;
        logic [135:0] top_a;
        logic [135:0] bottom_a;
        logic [135:0] top_b;
        logic top_raw;
        logic bottom_raw;
        logic top_b_raw;
        logic [4:0] top_length;
        logic [4:0] bottom_length;
        logic [4:0] top_b_length;
        logic [135:0] top_payload;
        logic [135:0] bottom_payload;
        logic [135:0] top_b_payload;
        integer waits;
        integer stall;
        begin
            hard_reset();
            top_a = make_record(2'b10, 6'd63, patterned_mask(15, 2));
            bottom_a = make_record(2'b01, 6'd0, patterned_mask(16, 0));
            top_b = make_record(2'b01, 6'd17, patterned_mask(1, 1));
            pulse_both_records(top_a, bottom_a);
            if (!last_top_accepted || !last_bottom_accepted ||
                accepted_count_o !== 32'd2)
                semantic_fail("simultaneous_acceptance",
                              "both tiers were not accepted together");
            settle_accept_pulse();

            waits = 0;
            while (!top_fragment_valid_o || !bottom_fragment_valid_o) begin
                @(posedge clk_i);
                #1;
                waits = waits + 1;
                if (waits > MAX_WAIT_CYCLES)
                    semantic_fail("simultaneous_fragment_timeout",
                                  "both tier fragments did not become retained");
            end
            capture_fragment(1'b0, top_raw, top_length, top_payload);
            capture_fragment(1'b1, bottom_raw, bottom_length, bottom_payload);
            check_fragment_values(1'b0, top_a, top_raw, top_length, top_payload,
                                  "simultaneous_top_fragment");
            check_fragment_values(1'b1, bottom_a, bottom_raw, bottom_length,
                                  bottom_payload, "simultaneous_bottom_fragment");
            for (stall = 0; stall < 4; stall = stall + 1) begin
                @(posedge clk_i);
                #1;
                if ({top_fragment_valid_o, top_fragment_raw_o,
                     top_fragment_length_o, top_fragment_payload_o,
                     bottom_fragment_valid_o, bottom_fragment_raw_o,
                     bottom_fragment_length_o, bottom_fragment_payload_o} !==
                    {1'b1, top_raw, top_length, top_payload,
                     1'b1, bottom_raw, bottom_length, bottom_payload})
                    semantic_fail("simultaneous_stability",
                                  "simultaneously stalled fragments changed");
            end

            // Retire only the top tier.  The bottom tier must remain stable.
            @(negedge clk_i);
            top_fragment_ready_i = 1'b1;
            @(posedge clk_i);
            #1;
            if (retired_count_o !== 32'd1 || !bottom_fragment_valid_o ||
                ({bottom_fragment_raw_o, bottom_fragment_length_o,
                  bottom_fragment_payload_o} !==
                 {bottom_raw, bottom_length, bottom_payload}))
                semantic_fail("independent_backpressure",
                              "top retirement disturbed stalled bottom fragment");
            @(negedge clk_i);
            top_fragment_ready_i = 1'b0;

            pulse_record(1'b0, top_b);
            if (!last_top_accepted)
                semantic_fail("independent_reacceptance",
                              "free top tier did not accept while bottom stalled");
            settle_accept_pulse();
            waits = 0;
            while (!top_fragment_valid_o) begin
                @(posedge clk_i);
                #1;
                waits = waits + 1;
                if (!bottom_fragment_valid_o ||
                    ({bottom_fragment_raw_o, bottom_fragment_length_o,
                      bottom_fragment_payload_o} !==
                     {bottom_raw, bottom_length, bottom_payload}))
                    semantic_fail("independent_backpressure",
                                  "bottom retained fragment was overwritten");
                if (waits > MAX_WAIT_CYCLES)
                    semantic_fail("independent_fragment_timeout",
                                  "second top fragment did not appear");
            end
            capture_fragment(1'b0, top_b_raw, top_b_length, top_b_payload);
            check_fragment_values(1'b0, top_b, top_b_raw, top_b_length,
                                  top_b_payload, "independent_top_fragment");

            @(negedge clk_i);
            top_fragment_ready_i = 1'b1;
            bottom_fragment_ready_i = 1'b1;
            @(posedge clk_i);
            #1;
            if (retired_count_o !== 32'd3)
                semantic_fail("simultaneous_retirement",
                              "two simultaneous handshakes did not retire twice");
            @(negedge clk_i);
            top_fragment_ready_i = 1'b0;
            bottom_fragment_ready_i = 1'b0;
            repeat (2) @(posedge clk_i);
            #1;
            if (!quiescent_o || accepted_count_o !== retired_count_o)
                semantic_fail("simultaneous_conservation",
                              "simultaneous tier traffic did not conserve records");
        end
    endtask

    task automatic fill_top_queue_and_overflow(
        output logic         retained_raw,
        output logic [4:0]   retained_length,
        output logic [135:0] retained_payload
    );
        logic [135:0] retained_record;
        logic [135:0] queued_record;
        integer index;
        integer waits;
        begin
            retained_record = make_record(2'b10, 6'd9,
                                          patterned_mask(16, 2));
            pulse_record(1'b0, retained_record);
            if (!last_top_accepted)
                semantic_fail("overflow_fixture", "retained record was not accepted");
            settle_accept_pulse();
            waits = 0;
            while (!top_fragment_valid_o) begin
                @(posedge clk_i);
                #1;
                waits = waits + 1;
                if (waits > MAX_WAIT_CYCLES)
                    semantic_fail("overflow_fixture", "retained fragment timeout");
            end
            capture_fragment(1'b0, retained_raw, retained_length,
                             retained_payload);
            check_fragment_values(1'b0, retained_record, retained_raw,
                                  retained_length, retained_payload,
                                  "overflow_retained_fragment");
            for (index = 0; index < QUEUE_DEPTH; index = index + 1) begin
                queued_record = make_record(index[0] ? 2'b10 : 2'b01,
                                            index[5:0],
                                            patterned_mask(index+1,
                                                           index % 3));
                pulse_record(1'b0, queued_record);
                if (!last_top_accepted)
                    semantic_fail("queue_depth_four",
                                  "one of four queue entries was rejected");
                if (!top_fragment_valid_o ||
                    ({top_fragment_raw_o, top_fragment_length_o,
                      top_fragment_payload_o} !==
                     {retained_raw, retained_length, retained_payload}))
                    semantic_fail("queue_retained_stability",
                                  "queue fill overwrote retained fragment");
                settle_accept_pulse();
            end
        end
    endtask

    task automatic run_queue_overflow;
        logic retained_raw;
        logic [4:0] retained_length;
        logic [135:0] retained_payload;
        logic [135:0] overflow_record;
        begin
            hard_reset();
            fill_top_queue_and_overflow(retained_raw, retained_length,
                                        retained_payload);
            if (accepted_count_o !== 32'd5)
                semantic_fail("queue_depth_four",
                              "retained plus four queued records were not accepted");
            overflow_record = make_record(2'b10, 6'd55,
                                          patterned_mask(8, 1));
            pulse_record(1'b0, overflow_record);
            if (last_top_accepted || overflow_count_o !== 32'd1 ||
                !sticky_fault_o || accepted_count_o !== 32'd5)
                semantic_fail("queue_overflow",
                              "fifth queued record did not overflow with sticky fault");
            if (!top_fragment_valid_o ||
                ({top_fragment_raw_o, top_fragment_length_o,
                  top_fragment_payload_o} !==
                 {retained_raw, retained_length, retained_payload}))
                semantic_fail("queue_retained_stability",
                              "overflow changed the retained fragment");
            settle_accept_pulse();
        end
    endtask

    task automatic assert_no_stale_after_reset(input string check_name);
        integer cycle;
        begin
            #0.2;
            check_reset_clamp();
            for (cycle = 0; cycle < 2; cycle = cycle + 1) begin
                @(posedge clk_i);
                #1;
                check_reset_clamp();
            end
            @(negedge clk_i);
            arst_ni = 1'b1;
            admit_enable_i = 1'b1;
            for (cycle = 0; cycle < 6; cycle = cycle + 1) begin
                @(posedge clk_i);
                #1;
                if (top_fragment_valid_o || bottom_fragment_valid_o ||
                    accepted_count_o || retired_count_o || sticky_fault_o)
                    semantic_fail(check_name, "stale state appeared after reset");
            end
            if (!quiescent_o)
                semantic_fail(check_name, "core was not quiescent after reset");
        end
    endtask

    task automatic run_reset_state_witnesses;
        logic [135:0] first_record;
        logic [135:0] second_record;
        integer waits;
        begin
            // Reset with one retained fragment and another record queued.
            hard_reset();
            first_record = make_record(2'b10, 6'd10, patterned_mask(16, 0));
            second_record = make_record(2'b01, 6'd11, patterned_mask(4, 1));
            pulse_record(1'b0, first_record);
            settle_accept_pulse();
            waits = 0;
            while (!top_fragment_valid_o) begin
                @(posedge clk_i);
                #1;
                waits = waits + 1;
                if (waits > MAX_WAIT_CYCLES)
                    semantic_fail("reset_queued", "retained fixture timed out");
            end
            pulse_record(1'b0, second_record);
            if (!last_top_accepted || quiescent_o)
                semantic_fail("reset_queued", "queued reset witness was not owned");
            @(negedge clk_i);
            clear_inputs();
            arst_ni = 1'b0;
            assert_no_stale_after_reset("reset_queued");

            // Reset a sparse record while its leaf is emitting bytes.
            hard_reset();
            first_record = make_record(2'b10, 6'd12, patterned_mask(15, 2));
            pulse_record(1'b1, first_record);
            if (!last_bottom_accepted)
                semantic_fail("reset_encoding", "encoding witness was not accepted");
            settle_accept_pulse();
            repeat (3) begin
                @(posedge clk_i);
                #1;
                if (bottom_fragment_valid_o)
                    semantic_fail("reset_encoding",
                                  "sparse fragment completed before encoding reset witness");
            end
            @(negedge clk_i);
            clear_inputs();
            arst_ni = 1'b0;
            assert_no_stale_after_reset("reset_encoding");

            // Reset an unstalled retained raw fragment.
            hard_reset();
            first_record = make_record(2'b01, 6'd13, patterned_mask(16, 1));
            pulse_record(1'b0, first_record);
            settle_accept_pulse();
            waits = 0;
            while (!top_fragment_valid_o) begin
                @(posedge clk_i);
                #1;
                waits = waits + 1;
                if (waits > MAX_WAIT_CYCLES)
                    semantic_fail("reset_retained", "retained reset witness timed out");
            end
            arst_ni = 1'b0;
            assert_no_stale_after_reset("reset_retained");

            // Reset a sparse retained fragment after an extended stall.
            hard_reset();
            first_record = make_record(2'b10, 6'd14, patterned_mask(8, 0));
            pulse_record(1'b1, first_record);
            settle_accept_pulse();
            waits = 0;
            while (!bottom_fragment_valid_o) begin
                @(posedge clk_i);
                #1;
                waits = waits + 1;
                if (waits > MAX_WAIT_CYCLES)
                    semantic_fail("reset_stalled", "stalled reset witness timed out");
            end
            repeat (5) begin
                @(posedge clk_i);
                #1;
                if (!bottom_fragment_valid_o)
                    semantic_fail("reset_stalled", "stalled witness was not retained");
            end
            arst_ni = 1'b0;
            assert_no_stale_after_reset("reset_stalled");
        end
    endtask

    // Saturation is reached without four billion cycles by depositing the
    // penultimate value into each public counter state variable, then exercising
    // only normal interface events.  A release must preserve the deposited value;
    // the next two qualifying events must produce max, then max again.
    task automatic run_saturating_counters;
        logic [135:0] sparse_record;
        logic [135:0] raw_record;
        logic [135:0] empty_record;
        logic retained_raw;
        logic [4:0] retained_length;
        logic [135:0] retained_payload;
        integer index;
        begin
            sparse_record = make_record(2'b10, 6'd21, patterned_mask(3, 2));
            raw_record = make_record(2'b01, 6'd22, patterned_mask(16, 1));
            empty_record = make_record(2'b01, 6'd23, 128'd0);

            hard_reset();
            force dut.disabled_suppressed_count_o = 32'hffff_fffe;
            #1;
            release dut.disabled_suppressed_count_o;
            admit_enable_i = 1'b0;
            pulse_record(1'b0, sparse_record);
            pulse_record(1'b0, sparse_record);
            if (disabled_suppressed_count_o !== 32'hffff_ffff)
                semantic_fail("saturating_disabled", "disabled counter wrapped");

            hard_reset();
            force dut.illegal_label_count_o = 32'hffff_fffe;
            #1;
            release dut.illegal_label_count_o;
            pulse_record(1'b0, make_record(2'b00, 6'd1, patterned_mask(1, 0)));
            pulse_record(1'b0, make_record(2'b11, 6'd1, patterned_mask(1, 0)));
            if (illegal_label_count_o !== 32'hffff_ffff)
                semantic_fail("saturating_illegal", "illegal counter wrapped");

            hard_reset();
            force dut.empty_suppressed_count_o = 32'hffff_fffe;
            #1;
            release dut.empty_suppressed_count_o;
            pulse_record(1'b0, empty_record);
            pulse_record(1'b0, empty_record);
            if (empty_suppressed_count_o !== 32'hffff_ffff)
                semantic_fail("saturating_empty", "empty counter wrapped");

            hard_reset();
            force dut.accepted_count_o = 32'hffff_fffe;
            force dut.sparse_count_o = 32'hffff_fffe;
            force dut.retired_count_o = 32'hffff_fffe;
            #1;
            release dut.accepted_count_o;
            release dut.sparse_count_o;
            release dut.retired_count_o;
            for (index = 0; index < 2; index = index + 1) begin
                pulse_record(1'b0, sparse_record);
                if (!last_top_accepted)
                    semantic_fail("saturating_accepted", "saturation sparse record rejected");
                settle_accept_pulse();
                wait_for_fragment(1'b0, sparse_record, 0, "saturation_sparse_fragment");
            end
            if (accepted_count_o !== 32'hffff_ffff ||
                sparse_count_o !== 32'hffff_ffff ||
                retired_count_o !== 32'hffff_ffff)
                semantic_fail("saturating_sparse_lifecycle",
                              "accepted/sparse/retired counter wrapped");

            hard_reset();
            force dut.raw_count_o = 32'hffff_fffe;
            #1;
            release dut.raw_count_o;
            for (index = 0; index < 2; index = index + 1) begin
                pulse_record(1'b1, raw_record);
                settle_accept_pulse();
                wait_for_fragment(1'b1, raw_record, 0, "saturation_raw_fragment");
            end
            if (raw_count_o !== 32'hffff_ffff)
                semantic_fail("saturating_raw", "raw counter wrapped");

            hard_reset();
            fill_top_queue_and_overflow(retained_raw, retained_length,
                                        retained_payload);
            force dut.overflow_count_o = 32'hffff_fffe;
            #1;
            release dut.overflow_count_o;
            for (index = 0; index < 2; index = index + 1)
                pulse_record(1'b0,
                             make_record(2'b10, 6'd42,
                                         patterned_mask(2, index)));
            if (overflow_count_o !== 32'hffff_ffff)
                semantic_fail("saturating_overflow", "overflow counter wrapped");
        end
    endtask

    task automatic run_plant_witness;
        logic [135:0] record_a;
        logic [135:0] record_b;
        logic [127:0] mask;
        logic observed_raw;
        logic [4:0] observed_length;
        logic [135:0] observed_payload;
        logic [135:0] corrupted_payload;
        logic [7:0] temporary_byte;
        logic retained_raw;
        logic [4:0] retained_length;
        logic [135:0] retained_payload;
        logic observed_sticky;
        logic [31:0] observed_retired;
        integer waits;
        integer byte_index;
        begin
            if (plant == "half_order_swap") begin
                hard_reset();
                mask = 128'd0;
                mask[0] = 1'b1;
                mask[9] = 1'b1;
                mask[18] = 1'b1;
                mask[27] = 1'b1;
                mask[36] = 1'b1;
                mask[45] = 1'b1;
                mask[54] = 1'b1;
                mask[63] = 1'b1;
                mask[65] = 1'b1;
                mask[74] = 1'b1;
                mask[83] = 1'b1;
                mask[92] = 1'b1;
                mask[101] = 1'b1;
                mask[110] = 1'b1;
                mask[119] = 1'b1;
                mask[127] = 1'b1;
                record_a = make_record(2'b10, 6'd31, mask);
                pulse_record(1'b0, record_a);
                settle_accept_pulse();
                waits = 0;
                while (!top_fragment_valid_o) begin
                    @(posedge clk_i); #1; waits = waits + 1;
                    if (waits > MAX_WAIT_CYCLES)
                        semantic_fail("half_order_swap", "plant witness timed out");
                end
                capture_fragment(1'b0, observed_raw, observed_length,
                                 observed_payload);
                corrupted_payload = observed_payload;
                for (byte_index = 0; byte_index < 8;
                     byte_index = byte_index + 1) begin
                    temporary_byte = corrupted_payload[8*byte_index +: 8];
                    corrupted_payload[8*byte_index +: 8] =
                        corrupted_payload[8*(byte_index+8) +: 8];
                    corrupted_payload[8*(byte_index+8) +: 8] = temporary_byte;
                end
                check_fragment_values(1'b0, record_a, observed_raw,
                                      observed_length, corrupted_payload,
                                      "half_order_swap");
            end else if (plant == "ascending_sparse_positions") begin
                hard_reset();
                mask = 128'd0;
                mask[2] = 1'b1; mask[39] = 1'b1; mask[117] = 1'b1;
                record_a = make_record(2'b01, 6'd7, mask);
                pulse_record(1'b1, record_a);
                settle_accept_pulse();
                waits = 0;
                while (!bottom_fragment_valid_o) begin
                    @(posedge clk_i); #1; waits = waits + 1;
                    if (waits > MAX_WAIT_CYCLES)
                        semantic_fail("ascending_sparse_positions",
                                      "plant witness timed out");
                end
                capture_fragment(1'b1, observed_raw, observed_length,
                                 observed_payload);
                corrupted_payload = observed_payload;
                temporary_byte = corrupted_payload[23:16];
                corrupted_payload[23:16] = corrupted_payload[39:32];
                corrupted_payload[39:32] = temporary_byte;
                corrupted_payload[23] = 1'b0;
                corrupted_payload[39] = 1'b1;
                check_fragment_values(1'b1, record_a, observed_raw,
                                      observed_length, corrupted_payload,
                                      "ascending_sparse_positions");
            end else if (plant == "launch_population_16") begin
                hard_reset();
                record_a = make_record(2'b10, 6'd8, patterned_mask(16, 2));
                pulse_record(1'b0, record_a);
                settle_accept_pulse();
                waits = 0;
                while (!top_fragment_valid_o) begin
                    @(posedge clk_i); #1; waits = waits + 1;
                    if (waits > MAX_WAIT_CYCLES)
                        semantic_fail("launch_population_16",
                                      "plant witness timed out");
                end
                capture_fragment(1'b0, observed_raw, observed_length,
                                 observed_payload);
                check_fragment_values(1'b0, record_a, 1'b0,
                                      observed_length, observed_payload,
                                      "launch_population_16");
            end else if (plant == "nonzero_delta_time") begin
                hard_reset();
                record_a = make_record(2'b01, 6'd9, patterned_mask(4, 1));
                pulse_record(1'b1, record_a);
                settle_accept_pulse();
                waits = 0;
                while (!bottom_fragment_valid_o) begin
                    @(posedge clk_i); #1; waits = waits + 1;
                    if (waits > MAX_WAIT_CYCLES)
                        semantic_fail("nonzero_delta_time", "plant witness timed out");
                end
                capture_fragment(1'b1, observed_raw, observed_length,
                                 observed_payload);
                corrupted_payload = observed_payload;
                corrupted_payload[0] = 1'b1;
                check_fragment_values(1'b1, record_a, observed_raw,
                                      observed_length, corrupted_payload,
                                      "nonzero_delta_time");
            end else if (plant == "raw_byte_reversal") begin
                hard_reset();
                mask = 128'h0123456789abcdef_fedcba9876543210;
                record_a = make_record(2'b10, 6'd10, mask);
                pulse_record(1'b0, record_a);
                settle_accept_pulse();
                waits = 0;
                while (!top_fragment_valid_o) begin
                    @(posedge clk_i); #1; waits = waits + 1;
                    if (waits > MAX_WAIT_CYCLES)
                        semantic_fail("raw_byte_reversal", "plant witness timed out");
                end
                capture_fragment(1'b0, observed_raw, observed_length,
                                 observed_payload);
                corrupted_payload = observed_payload;
                for (byte_index = 0; byte_index < 4;
                     byte_index = byte_index + 1) begin
                    temporary_byte = corrupted_payload[8*byte_index +: 8];
                    corrupted_payload[8*byte_index +: 8] =
                        corrupted_payload[8*(7-byte_index) +: 8];
                    corrupted_payload[8*(7-byte_index) +: 8] = temporary_byte;
                    temporary_byte = corrupted_payload[8*(byte_index+8) +: 8];
                    corrupted_payload[8*(byte_index+8) +: 8] =
                        corrupted_payload[8*(15-byte_index) +: 8];
                    corrupted_payload[8*(15-byte_index) +: 8] = temporary_byte;
                end
                check_fragment_values(1'b0, record_a, observed_raw,
                                      observed_length, corrupted_payload,
                                      "raw_byte_reversal");
            end else if (plant == "retained_fragment_overwrite") begin
                hard_reset();
                record_a = make_record(2'b10, 6'd11, patterned_mask(5, 2));
                record_b = make_record(2'b01, 6'd12, patterned_mask(6, 1));
                pulse_record(1'b0, record_a);
                settle_accept_pulse();
                waits = 0;
                while (!top_fragment_valid_o) begin
                    @(posedge clk_i); #1; waits = waits + 1;
                    if (waits > MAX_WAIT_CYCLES)
                        semantic_fail("retained_fragment_overwrite",
                                      "plant witness timed out");
                end
                capture_fragment(1'b0, observed_raw, observed_length,
                                 observed_payload);
                pulse_record(1'b0, record_b);
                settle_accept_pulse();
                corrupted_payload = top_fragment_payload_o;
                corrupted_payload[8] = ~corrupted_payload[8];
                check_fragment_values(1'b0, record_a, top_fragment_raw_o,
                                      top_fragment_length_o, corrupted_payload,
                                      "retained_fragment_overwrite");
            end else if ((plant == "duplicate_retirement") ||
                         (plant == "lost_retirement")) begin
                hard_reset();
                record_a = make_record(2'b10, 6'd13, patterned_mask(3, 0));
                pulse_record(1'b1, record_a);
                settle_accept_pulse();
                wait_for_fragment(1'b1, record_a, 1, "retirement_plant_fixture");
                observed_retired = retired_count_o;
                if (plant == "duplicate_retirement") begin
                    observed_retired = observed_retired + 32'd1;
                    if (observed_retired !== accepted_count_o)
                        semantic_fail("duplicate_retirement",
                                      "observed retirement duplicated");
                end else begin
                    observed_retired = observed_retired - 32'd1;
                    if (observed_retired !== accepted_count_o)
                        semantic_fail("lost_retirement",
                                      "observed retirement was lost");
                end
            end else if (plant == "overflow_without_sticky_fault") begin
                hard_reset();
                fill_top_queue_and_overflow(retained_raw, retained_length,
                                            retained_payload);
                pulse_record(1'b0,
                             make_record(2'b10, 6'd55,
                                         patterned_mask(8, 1)));
                observed_sticky = sticky_fault_o & 1'b0;
                if ((overflow_count_o == 32'd1) && !observed_sticky)
                    semantic_fail("overflow_without_sticky_fault",
                                  "overflow observation lacked sticky fault");
            end else begin
                semantic_fail("plant_name", "unknown semantic plant");
            end
            semantic_fail("plant_escaped", "semantic plant escaped detection");
        end
    endtask

    // Global X/Z guard.  This is observational only and does not inspect DUT
    // hierarchy or implementation state.
    always @(posedge clk_i) begin
        #1;
        if (arst_ni && $isunknown({top_record_accepted_o,
                                   bottom_record_accepted_o,
                                   top_fragment_valid_o, top_fragment_raw_o,
                                   top_fragment_length_o,
                                   top_fragment_payload_o,
                                   bottom_fragment_valid_o,
                                   bottom_fragment_raw_o,
                                   bottom_fragment_length_o,
                                   bottom_fragment_payload_o, quiescent_o,
                                   accepted_count_o,
                                   empty_suppressed_count_o,
                                   illegal_label_count_o,
                                   disabled_suppressed_count_o,
                                   overflow_count_o, sparse_count_o,
                                   raw_count_o, retired_count_o,
                                   sticky_fault_o}))
            semantic_fail("unknown_output", "DUT exposed X/Z on a public output");
    end

    initial begin
        plant = "none";
        void'($value$plusargs("PLANT=%s", plant));
        clear_inputs();
        if (plant != "none") begin
            run_plant_witness();
        end else begin
            run_mapping_corpus();
            run_accounting_priority();
            run_simultaneous_and_backpressure();
            run_queue_overflow();
            run_reset_state_witnesses();
            run_saturating_counters();
            $display("%s", PASS_MARKER);
            $finish_and_return(0);
        end
    end

endmodule

`default_nettype wire
