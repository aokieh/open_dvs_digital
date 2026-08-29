`timescale 1ns/1ps
`default_nettype none

// Test-only executable reference fixture.  This module has the exact frozen
// product interface, but it is never part of the product or synthesis list.
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
    logic [7:0] packet_bank_q [0:39];
    logic [7:0] work_body [0:35];
    logic       bank_valid_q;
    logic       prefer_top_q;
    integer     work_length;
    integer     byte_index;
    integer     work_packet_bytes;
    logic [7:0] work_crc;
    logic [7:0] work_sequence;
    logic [1:0] work_epoch;

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

    function automatic integer mask_population(input [127:0] mask);
        integer column;
        begin
            mask_population = 0;
            for (column = 0; column < 128; column = column + 1)
                mask_population = mask_population + mask[column];
        end
    endfunction

    function automatic integer fragment_well_formed(
        input         tier,
        input         is_raw,
        input [4:0]   length,
        input [135:0] payload
    );
        integer index;
        integer previous;
        integer column;
        integer good;
        reg [7:0] code;
        reg [7:0] row_code;
        reg [7:0] position;
        reg [7:0] label_row;
        reg [127:0] mask;
        begin
            good = 1;
            code = payload[7:0];
            row_code = payload[15:8];
            if (is_raw) begin
                label_row = payload[135:128];
                mask = payload[127:0];
                if (length != 5'd17)
                    good = 0;
                if ((label_row[7:6] != 2'b01) &&
                    (label_row[7:6] != 2'b10))
                    good = 0;
                if (mask_population(mask) < 16)
                    good = 0;
            end else begin
                if ((length < 5'd3) || (length > 5'd17))
                    good = 0;
                if (!code[7] || (code[5:0] != 6'd0))
                    good = 0;
                if (row_code[7] || (row_code[6] != tier))
                    good = 0;
                previous = 128;
                for (index = 2; index < 17; index = index + 1) begin
                    if (index < length) begin
                        position = payload[8*index +: 8];
                        column = position[6:0];
                        if (column >= previous)
                            good = 0;
                        if (position[7] != (index == (length - 1)))
                            good = 0;
                        previous = column;
                    end else if (payload[8*index +: 8] != 8'h00) begin
                        good = 0;
                    end
                end
            end
            fragment_well_formed = good;
        end
    endfunction

    task automatic clear_work_body;
        integer index;
        begin
            work_length = 0;
            for (index = 0; index < 36; index = index + 1)
                work_body[index] = 8'h00;
        end
    endtask

    task automatic append_fragment(
        input         tier,
        input         is_raw,
        input [4:0]   length,
        input [135:0] payload
    );
        integer index;
        reg [7:0] label_row;
        begin
            if (is_raw) begin
                label_row = payload[135:128];
                work_body[work_length] = {1'b0, label_row[7], 6'b000000};
                work_body[work_length + 1] = {1'b0, tier, label_row[5:0]};
                for (index = 0; index < 16; index = index + 1)
                    work_body[work_length + 2 + index] =
                        payload[8*index +: 8];
                work_length = work_length + 18;
            end else begin
                for (index = 0; index < length; index = index + 1)
                    work_body[work_length + index] = payload[8*index +: 8];
                work_length = work_length + length;
            end
        end
    endtask

    always_comb begin
        packet_ready_o = bank_valid_q;
        core_admit_enable_o = sync_mode_active_i && !drain_i &&
                              !sticky_fault_o;
        serial_data_0_o = 16'h0000;
        serial_data_1_o = 16'h0000;
        if (bank_valid_q) begin
            serial_data_0_o = {
                packet_bank_q[(beat_index_o * 4) + 1],
                packet_bank_q[(beat_index_o * 4) + 0]
            };
            serial_data_1_o = {
                packet_bank_q[(beat_index_o * 4) + 3],
                packet_bank_q[(beat_index_o * 4) + 2]
            };
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
            bank_valid_q <= 1'b0;
            prefer_top_q <= 1'b1;
            for (byte_index = 0; byte_index < 40; byte_index = byte_index + 1)
                packet_bank_q[byte_index] <= 8'h00;
        end else begin
            top_fragment_ready_o <= 1'b0;
            bottom_fragment_ready_o <= 1'b0;

            if (sync_mode_entry_i) begin
                mode_epoch_o <= mode_epoch_o + 2'd1;
                sequence_o <= 8'h00;
            end

            if ((top_fragment_valid_i &&
                 !fragment_well_formed(1'b0, top_fragment_raw_i,
                                       top_fragment_length_i,
                                       top_fragment_payload_i)) ||
                (bottom_fragment_valid_i &&
                 !fragment_well_formed(1'b1, bottom_fragment_raw_i,
                                       bottom_fragment_length_i,
                                       bottom_fragment_payload_i))) begin
                sticky_fault_o <= 1'b1;
            end

            if (bank_valid_q) begin
                if (stream_abort_i) begin
                    beat_index_o <= 4'd0;
                    completion_pending_o <= 1'b0;
                end else if (completion_pending_o && serial_beat_complete_i) begin
                    if (beat_index_o == ((packet_bytes_o >> 2) - 1)) begin
                        bank_valid_q <= 1'b0;
                        packet_bytes_o <= 6'd0;
                        beat_index_o <= 4'd0;
                        completion_pending_o <= 1'b0;
                        sequence_o <= sequence_o + 8'd1;
                    end else begin
                        beat_index_o <= beat_index_o + 4'd1;
                        completion_pending_o <= 1'b0;
                    end
                end else if (!completion_pending_o &&
                             (serial_consume_i == 2'b11)) begin
                    completion_pending_o <= 1'b1;
                end
            end else if (!sticky_fault_o &&
                         (sync_mode_active_i || drain_i) &&
                         (top_fragment_valid_i || bottom_fragment_valid_i) &&
                         (!top_fragment_valid_i ||
                          fragment_well_formed(1'b0, top_fragment_raw_i,
                                               top_fragment_length_i,
                                               top_fragment_payload_i)) &&
                         (!bottom_fragment_valid_i ||
                          fragment_well_formed(1'b1, bottom_fragment_raw_i,
                                               bottom_fragment_length_i,
                                               bottom_fragment_payload_i))) begin
                clear_work_body();
                if (top_fragment_valid_i && bottom_fragment_valid_i) begin
                    if (prefer_top_q) begin
                        append_fragment(1'b0, top_fragment_raw_i,
                                        top_fragment_length_i,
                                        top_fragment_payload_i);
                        append_fragment(1'b1, bottom_fragment_raw_i,
                                        bottom_fragment_length_i,
                                        bottom_fragment_payload_i);
                    end else begin
                        append_fragment(1'b1, bottom_fragment_raw_i,
                                        bottom_fragment_length_i,
                                        bottom_fragment_payload_i);
                        append_fragment(1'b0, top_fragment_raw_i,
                                        top_fragment_length_i,
                                        top_fragment_payload_i);
                    end
                    top_fragment_ready_o <= 1'b1;
                    bottom_fragment_ready_o <= 1'b1;
                    prefer_top_q <= !prefer_top_q;
                end else if (top_fragment_valid_i) begin
                    append_fragment(1'b0, top_fragment_raw_i,
                                    top_fragment_length_i,
                                    top_fragment_payload_i);
                    top_fragment_ready_o <= 1'b1;
                end else begin
                    append_fragment(1'b1, bottom_fragment_raw_i,
                                    bottom_fragment_length_i,
                                    bottom_fragment_payload_i);
                    bottom_fragment_ready_o <= 1'b1;
                end

                work_epoch = sync_mode_entry_i ?
                             (mode_epoch_o + 2'd1) : mode_epoch_o;
                work_sequence = sync_mode_entry_i ? 8'h00 : sequence_o;
                work_crc = 8'h00;
                work_crc = crc8_byte(work_crc, {4'h2, 2'b01, work_epoch});
                work_crc = crc8_byte(work_crc, work_sequence);
                work_crc = crc8_byte(work_crc, work_length[7:0]);
                for (byte_index = 0; byte_index < work_length;
                     byte_index = byte_index + 1)
                    work_crc = crc8_byte(work_crc, work_body[byte_index]);

                for (byte_index = 0; byte_index < 40; byte_index = byte_index + 1)
                    packet_bank_q[byte_index] <= 8'h00;
                packet_bank_q[0] <= {4'h2, 2'b01, work_epoch};
                packet_bank_q[1] <= work_sequence;
                packet_bank_q[2] <= work_length[7:0];
                packet_bank_q[3] <= work_crc;
                for (byte_index = 0; byte_index < work_length;
                     byte_index = byte_index + 1)
                    packet_bank_q[4 + byte_index] <= work_body[byte_index];
                work_packet_bytes = 4 + (((work_length + 3) / 4) * 4);
                packet_bytes_o <= work_packet_bytes[5:0];
                beat_index_o <= 4'd0;
                completion_pending_o <= 1'b0;
                bank_valid_q <= 1'b1;
            end
        end
    end
endmodule

`default_nettype wire
