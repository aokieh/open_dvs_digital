`timescale 1ns/1ps
`default_nettype none

module opendvs_self_delimiting_packet_path (
    input  logic         clk_i,
    input  logic         arst_ni,
    input  logic         sync_mode_active_i,
    input  logic         sync_mode_entry_i,
    input  logic         drain_i,

    input  logic         top_fragment_valid_i,
    output logic         top_fragment_ready_o,
    input  logic         top_fragment_raw_i,
    input  logic [4:0]   top_fragment_length_i,
    input  logic [135:0] top_fragment_payload_i,

    input  logic         bottom_fragment_valid_i,
    output logic         bottom_fragment_ready_o,
    input  logic         bottom_fragment_raw_i,
    input  logic [4:0]   bottom_fragment_length_i,
    input  logic [135:0] bottom_fragment_payload_i,

    input  logic         encoder_quiescent_i,
    input  logic         serial_boundary_quiescent_i,
    input  logic [1:0]   serial_consume_i,
    input  logic         serial_beat_complete_i,
    input  logic         stream_abort_i,

    output logic         core_admit_enable_o,
    output logic         packet_ready_o,
    output logic [15:0]  serial_data_0_o,
    output logic [15:0]  serial_data_1_o,
    output logic         quiescent_o,
    output logic         sticky_fault_o,
    output logic [7:0]   sequence_o,
    output logic [1:0]   mode_epoch_o,
    output logic [5:0]   packet_bytes_o,
    output logic [3:0]   beat_index_o,
    output logic         completion_pending_o
);
    // The complete immutable packet is the only retained payload storage.
    // Byte zero occupies bits [7:0], matching the serializer's lane-zero word.
    (* keep = "true" *) logic [319:0] packet_bank_q;
    logic         bank_valid_q;
    logic         prefer_top_q;

    logic         top_legal;
    logic         bottom_legal;
    logic         malformed_present;
    logic         commit_packet;
    logic         first_is_top;
    logic [5:0]   first_record_bytes;
    logic [5:0]   second_record_bytes;
    logic [5:0]   body_bytes_d;
    logic [5:0]   wire_bytes_d;
    logic [319:0] commit_image_d;
    logic [7:0]   effective_sequence;
    logic [1:0]   effective_epoch;
    logic [7:0]   build_crc;
    integer       body_index;

    function automatic [7:0] crc8_step(
        input [7:0] accumulator,
        input [7:0] data_byte
    );
        reg [7:0] value;
        integer step;
        begin
            value = accumulator ^ data_byte;
            for (step = 0; step < 8; step = step + 1) begin
                if (value[7])
                    value = {value[6:0], 1'b0} ^ 8'h07;
                else
                    value = {value[6:0], 1'b0};
            end
            crc8_step = value;
        end
    endfunction

    function automatic [7:0] count_mask_bits(input [127:0] mask);
        integer column;
        reg [7:0] count;
        begin
            count = 8'd0;
            for (column = 0; column < 128; column = column + 1)
                count = count + mask[column];
            count_mask_bits = count;
        end
    endfunction

    function automatic legal_fragment(
        input         tier,
        input         raw_format,
        input [4:0]   fragment_length,
        input [135:0] fragment_payload
    );
        integer item;
        integer prior_column;
        reg valid;
        reg [7:0] item_byte;
        begin
            valid = 1'b1;
            if (raw_format) begin
                if (fragment_length != 5'd17)
                    valid = 1'b0;
                if ((fragment_payload[135:134] != 2'b01) &&
                    (fragment_payload[135:134] != 2'b10))
                    valid = 1'b0;
                if (count_mask_bits(fragment_payload[127:0]) < 8'd16)
                    valid = 1'b0;
            end else begin
                if ((fragment_length < 5'd3) || (fragment_length > 5'd17))
                    valid = 1'b0;
                if (!fragment_payload[7] ||
                    (fragment_payload[5:0] != 6'b000000))
                    valid = 1'b0;
                if (fragment_payload[15] ||
                    (fragment_payload[14] != tier))
                    valid = 1'b0;
                prior_column = 128;
                for (item = 2; item < 17; item = item + 1) begin
                    item_byte = fragment_payload[8*item +: 8];
                    if (item < fragment_length) begin
                        if (item_byte[6:0] >= prior_column)
                            valid = 1'b0;
                        if (item_byte[7] != (item == fragment_length - 1))
                            valid = 1'b0;
                        prior_column = item_byte[6:0];
                    end else if (item_byte != 8'h00) begin
                        valid = 1'b0;
                    end
                end
            end
            legal_fragment = valid;
        end
    endfunction

    function automatic [5:0] record_size(
        input       raw_format,
        input [4:0] fragment_length
    );
        begin
            record_size = raw_format ? 6'd18 : {1'b0, fragment_length};
        end
    endfunction

    function automatic [7:0] record_byte(
        input         tier,
        input         raw_format,
        input [135:0] fragment_payload,
        input integer byte_offset
    );
        begin
            if (!raw_format) begin
                record_byte = fragment_payload[8*byte_offset +: 8];
            end else if (byte_offset == 0) begin
                record_byte = {1'b0, fragment_payload[135], 6'b000000};
            end else if (byte_offset == 1) begin
                record_byte = {1'b0, tier, fragment_payload[133:128]};
            end else begin
                record_byte = fragment_payload[8*(byte_offset-2) +: 8];
            end
        end
    endfunction

    always @* begin
        top_legal = legal_fragment(
            1'b0, top_fragment_raw_i, top_fragment_length_i,
            top_fragment_payload_i
        );
        bottom_legal = legal_fragment(
            1'b1, bottom_fragment_raw_i, bottom_fragment_length_i,
            bottom_fragment_payload_i
        );
        malformed_present =
            (top_fragment_valid_i && !top_legal) ||
            (bottom_fragment_valid_i && !bottom_legal);

        commit_packet = !bank_valid_q && !sticky_fault_o &&
                        (sync_mode_active_i || drain_i) &&
                        (top_fragment_valid_i || bottom_fragment_valid_i) &&
                        !malformed_present;
        first_is_top = top_fragment_valid_i &&
                       (!bottom_fragment_valid_i || prefer_top_q);

        if (first_is_top)
            first_record_bytes = record_size(
                top_fragment_raw_i, top_fragment_length_i
            );
        else
            first_record_bytes = record_size(
                bottom_fragment_raw_i, bottom_fragment_length_i
            );

        if (top_fragment_valid_i && bottom_fragment_valid_i) begin
            if (first_is_top)
                second_record_bytes = record_size(
                    bottom_fragment_raw_i, bottom_fragment_length_i
                );
            else
                second_record_bytes = record_size(
                    top_fragment_raw_i, top_fragment_length_i
                );
        end else begin
            second_record_bytes = 6'd0;
        end

        body_bytes_d = first_record_bytes + second_record_bytes;
        wire_bytes_d = 6'd4 + ((body_bytes_d + 6'd3) & 6'h3c);
        effective_epoch = sync_mode_entry_i ?
                          (mode_epoch_o + 2'd1) : mode_epoch_o;
        effective_sequence = sync_mode_entry_i ? 8'h00 : sequence_o;

        commit_image_d = 320'd0;
        commit_image_d[7:0] = {4'h2, 2'b01, effective_epoch};
        commit_image_d[15:8] = effective_sequence;
        commit_image_d[23:16] = body_bytes_d;
        build_crc = 8'h00;
        build_crc = crc8_step(build_crc, commit_image_d[7:0]);
        build_crc = crc8_step(build_crc, commit_image_d[15:8]);
        build_crc = crc8_step(build_crc, commit_image_d[23:16]);

        for (body_index = 0; body_index < 36;
             body_index = body_index + 1) begin
            if (body_index < first_record_bytes) begin
                if (first_is_top)
                    commit_image_d[8*(body_index+4) +: 8] = record_byte(
                        1'b0, top_fragment_raw_i,
                        top_fragment_payload_i, body_index
                    );
                else
                    commit_image_d[8*(body_index+4) +: 8] = record_byte(
                        1'b1, bottom_fragment_raw_i,
                        bottom_fragment_payload_i, body_index
                    );
            end else if (body_index < body_bytes_d) begin
                if (first_is_top)
                    commit_image_d[8*(body_index+4) +: 8] = record_byte(
                        1'b1, bottom_fragment_raw_i,
                        bottom_fragment_payload_i,
                        body_index - first_record_bytes
                    );
                else
                    commit_image_d[8*(body_index+4) +: 8] = record_byte(
                        1'b0, top_fragment_raw_i,
                        top_fragment_payload_i,
                        body_index - first_record_bytes
                    );
            end
            if (body_index < body_bytes_d)
                build_crc = crc8_step(
                    build_crc, commit_image_d[8*(body_index+4) +: 8]
                );
        end
        commit_image_d[31:24] = build_crc;
    end

    always @* begin
        packet_ready_o = bank_valid_q;
        core_admit_enable_o = sync_mode_active_i && !drain_i &&
                              !sticky_fault_o;
        serial_data_0_o = 16'h0000;
        serial_data_1_o = 16'h0000;
        if (bank_valid_q) begin
            serial_data_0_o = packet_bank_q[32*beat_index_o +: 16];
            serial_data_1_o = packet_bank_q[32*beat_index_o+16 +: 16];
        end
        quiescent_o = !bank_valid_q && !completion_pending_o &&
                      !top_fragment_valid_i && !bottom_fragment_valid_i &&
                      encoder_quiescent_i && serial_boundary_quiescent_i;
    end

    always_ff @(posedge clk_i or negedge arst_ni) begin
        if (!arst_ni) begin
            top_fragment_ready_o <= 1'b0;
            bottom_fragment_ready_o <= 1'b0;
            sticky_fault_o <= 1'b0;
            sequence_o <= 8'h00;
            mode_epoch_o <= 2'b11;
            packet_bytes_o <= 6'd0;
            beat_index_o <= 4'd0;
            completion_pending_o <= 1'b0;
            packet_bank_q <= 320'd0;
            bank_valid_q <= 1'b0;
            prefer_top_q <= 1'b1;
        end else begin
            top_fragment_ready_o <= 1'b0;
            bottom_fragment_ready_o <= 1'b0;

            if (sync_mode_entry_i) begin
                mode_epoch_o <= mode_epoch_o + 2'd1;
                sequence_o <= 8'h00;
            end

            if (malformed_present)
                sticky_fault_o <= 1'b1;

            if (bank_valid_q) begin
                if (stream_abort_i) begin
                    beat_index_o <= 4'd0;
                    completion_pending_o <= 1'b0;
                end else if (completion_pending_o &&
                             serial_beat_complete_i) begin
                    if (beat_index_o == ((packet_bytes_o >> 2) - 1'b1)) begin
                        bank_valid_q <= 1'b0;
                        packet_bytes_o <= 6'd0;
                        beat_index_o <= 4'd0;
                        completion_pending_o <= 1'b0;
                        // Mode entry owns sequence zero even when it collides
                        // with the completion of the previous epoch's packet.
                        if (!sync_mode_entry_i)
                            sequence_o <= sequence_o + 8'd1;
                    end else begin
                        beat_index_o <= beat_index_o + 4'd1;
                        completion_pending_o <= 1'b0;
                    end
                end else if (!completion_pending_o &&
                             (serial_consume_i == 2'b11)) begin
                    completion_pending_o <= 1'b1;
                end
            end else if (commit_packet) begin
                packet_bank_q <= commit_image_d;
                packet_bytes_o <= wire_bytes_d;
                beat_index_o <= 4'd0;
                completion_pending_o <= 1'b0;
                bank_valid_q <= 1'b1;
                top_fragment_ready_o <= top_fragment_valid_i;
                bottom_fragment_ready_o <= bottom_fragment_valid_i;
                if (top_fragment_valid_i && bottom_fragment_valid_i)
                    prefer_top_q <= !prefer_top_q;
            end
        end
    end
endmodule

`default_nettype wire
