`timescale 1ns/1ps
`default_nettype none

module opendvs_sync_product_encoder_core #(
    parameter integer QUEUE_DEPTH = 16
) (
    input  logic         clk_i,
    input  logic         arst_ni,
    input  logic         admit_enable_i,

    input  logic         top_record_valid_i,
    input  logic [135:0] top_record_i,
    output logic         top_record_accepted_o,

    input  logic         bottom_record_valid_i,
    input  logic [135:0] bottom_record_i,
    output logic         bottom_record_accepted_o,

    output logic         top_fragment_valid_o,
    input  logic         top_fragment_ready_i,
    output logic         top_fragment_raw_o,
    output logic [4:0]   top_fragment_length_o,
    output logic [135:0] top_fragment_payload_o,

    output logic         bottom_fragment_valid_o,
    input  logic         bottom_fragment_ready_i,
    output logic         bottom_fragment_raw_o,
    output logic [4:0]   bottom_fragment_length_o,
    output logic [135:0] bottom_fragment_payload_o,

    output logic         quiescent_o,
    output logic [31:0]  accepted_count_o,
    output logic [31:0]  empty_suppressed_count_o,
    output logic [31:0]  illegal_label_count_o,
    output logic [31:0]  disabled_suppressed_count_o,
    output logic [31:0]  overflow_count_o,
    output logic [31:0]  sparse_count_o,
    output logic [31:0]  raw_count_o,
    output logic [31:0]  retired_count_o,
    output logic         sticky_fault_o
);

    localparam integer POINTER_WIDTH = $clog2(QUEUE_DEPTH);
    localparam integer COUNT_WIDTH = $clog2(QUEUE_DEPTH + 1);

    localparam logic [1:0] BUILDER_IDLE    = 2'd0;
    localparam logic [1:0] BUILDER_LAUNCH  = 2'd1;
    localparam logic [1:0] BUILDER_COLLECT = 2'd2;

    generate
        if ((QUEUE_DEPTH < 2) ||
            ((QUEUE_DEPTH & (QUEUE_DEPTH - 1)) != 0)) begin : g_bad_queue_depth
            initial begin
                $error("QUEUE_DEPTH must be a power of two and at least two");
                $finish;
            end
        end
    endgenerate

    function automatic logic [7:0] population128(
        input logic [127:0] mask
    );
        integer column;
        logic [7:0] total;
        begin
            total = 8'd0;
            for (column = 0; column < 128; column = column + 1)
                total = total + mask[column];
            population128 = total;
        end
    endfunction

    function automatic logic legal_label(
        input logic [1:0] event_mode
    );
        begin
            legal_label = (event_mode == 2'b01) ||
                          (event_mode == 2'b10);
        end
    endfunction

    function automatic logic [31:0] saturating_add(
        input logic [31:0] value,
        input logic [1:0]  amount
    );
        logic [32:0] extended;
        begin
            extended = {1'b0, value} + {{31{1'b0}}, amount};
            if (extended[32])
                saturating_add = 32'hffff_ffff;
            else
                saturating_add = extended[31:0];
        end
    endfunction

    logic [135:0] top_queue_mem [0:QUEUE_DEPTH-1];
    logic [135:0] bottom_queue_mem [0:QUEUE_DEPTH-1];
    logic [POINTER_WIDTH-1:0] top_write_pointer_q;
    logic [POINTER_WIDTH-1:0] top_read_pointer_q;
    logic [POINTER_WIDTH-1:0] bottom_write_pointer_q;
    logic [POINTER_WIDTH-1:0] bottom_read_pointer_q;
    logic [COUNT_WIDTH-1:0] top_queue_count_q;
    logic [COUNT_WIDTH-1:0] bottom_queue_count_q;

    logic [1:0] top_builder_state_q;
    logic [1:0] bottom_builder_state_q;
    logic [135:0] top_active_record_q;
    logic [135:0] bottom_active_record_q;
    logic [4:0] top_expected_length_q;
    logic [4:0] bottom_expected_length_q;
    logic [4:0] top_collect_index_q;
    logic [4:0] bottom_collect_index_q;

    logic top_leaf_in_valid;
    logic bottom_leaf_in_valid;
    logic top_leaf_in_ready;
    logic bottom_leaf_in_ready;
    logic top_leaf_out_valid;
    logic bottom_leaf_out_valid;
    logic top_leaf_out_ready;
    logic bottom_leaf_out_ready;
    logic [7:0] top_leaf_out_data;
    logic [7:0] bottom_leaf_out_data;

    wire top_queue_full_w = (top_queue_count_q == QUEUE_DEPTH);
    wire bottom_queue_full_w = (bottom_queue_count_q == QUEUE_DEPTH);

    wire top_disabled_w = top_record_valid_i && !admit_enable_i;
    wire bottom_disabled_w = bottom_record_valid_i && !admit_enable_i;
    wire top_illegal_w = top_record_valid_i && admit_enable_i &&
                         !legal_label(top_record_i[135:134]);
    wire bottom_illegal_w = bottom_record_valid_i && admit_enable_i &&
                            !legal_label(bottom_record_i[135:134]);
    wire top_empty_w = top_record_valid_i && admit_enable_i &&
                       legal_label(top_record_i[135:134]) &&
                       (top_record_i[127:0] == 128'd0);
    wire bottom_empty_w = bottom_record_valid_i && admit_enable_i &&
                          legal_label(bottom_record_i[135:134]) &&
                          (bottom_record_i[127:0] == 128'd0);
    wire top_overflow_w = top_record_valid_i && admit_enable_i &&
                          legal_label(top_record_i[135:134]) &&
                          (top_record_i[127:0] != 128'd0) &&
                          top_queue_full_w;
    wire bottom_overflow_w = bottom_record_valid_i && admit_enable_i &&
                             legal_label(bottom_record_i[135:134]) &&
                             (bottom_record_i[127:0] != 128'd0) &&
                             bottom_queue_full_w;
    wire top_accept_w = top_record_valid_i && admit_enable_i &&
                        legal_label(top_record_i[135:134]) &&
                        (top_record_i[127:0] != 128'd0) &&
                        !top_queue_full_w;
    wire bottom_accept_w = bottom_record_valid_i && admit_enable_i &&
                           legal_label(bottom_record_i[135:134]) &&
                           (bottom_record_i[127:0] != 128'd0) &&
                           !bottom_queue_full_w;

    wire [135:0] top_front_record_w =
        top_queue_mem[top_read_pointer_q];
    wire [135:0] bottom_front_record_w =
        bottom_queue_mem[bottom_read_pointer_q];
    wire [7:0] top_front_population_w =
        population128(top_front_record_w[127:0]);
    wire [7:0] bottom_front_population_w =
        population128(bottom_front_record_w[127:0]);

    wire top_dequeue_w = (top_builder_state_q == BUILDER_IDLE) &&
                         !top_fragment_valid_o &&
                         (top_queue_count_q != 0);
    wire bottom_dequeue_w = (bottom_builder_state_q == BUILDER_IDLE) &&
                            !bottom_fragment_valid_o &&
                            (bottom_queue_count_q != 0);

    wire top_raw_create_w = top_dequeue_w &&
                            (top_front_population_w >= 8'd16);
    wire bottom_raw_create_w = bottom_dequeue_w &&
                               (bottom_front_population_w >= 8'd16);
    wire top_sparse_create_w =
        (top_builder_state_q == BUILDER_COLLECT) &&
        top_leaf_out_valid && top_leaf_out_ready &&
        ((top_collect_index_q + 5'd1) == top_expected_length_q);
    wire bottom_sparse_create_w =
        (bottom_builder_state_q == BUILDER_COLLECT) &&
        bottom_leaf_out_valid && bottom_leaf_out_ready &&
        ((bottom_collect_index_q + 5'd1) == bottom_expected_length_q);
    wire top_retire_w = top_fragment_valid_o && top_fragment_ready_i;
    wire bottom_retire_w = bottom_fragment_valid_o &&
                           bottom_fragment_ready_i;

    wire [1:0] accepted_events_w =
        {1'b0, top_accept_w} + {1'b0, bottom_accept_w};
    wire [1:0] empty_events_w =
        {1'b0, top_empty_w} + {1'b0, bottom_empty_w};
    wire [1:0] illegal_events_w =
        {1'b0, top_illegal_w} + {1'b0, bottom_illegal_w};
    wire [1:0] disabled_events_w =
        {1'b0, top_disabled_w} + {1'b0, bottom_disabled_w};
    wire [1:0] overflow_events_w =
        {1'b0, top_overflow_w} + {1'b0, bottom_overflow_w};
    wire [1:0] sparse_events_w =
        {1'b0, top_sparse_create_w} + {1'b0, bottom_sparse_create_w};
    wire [1:0] raw_events_w =
        {1'b0, top_raw_create_w} + {1'b0, bottom_raw_create_w};
    wire [1:0] retired_events_w =
        {1'b0, top_retire_w} + {1'b0, bottom_retire_w};

    always_ff @(posedge clk_i or negedge arst_ni) begin
        if (!arst_ni) begin
            top_write_pointer_q <= '0;
            top_read_pointer_q <= '0;
            bottom_write_pointer_q <= '0;
            bottom_read_pointer_q <= '0;
            top_queue_count_q <= '0;
            bottom_queue_count_q <= '0;
        end else begin
            if (top_accept_w) begin
                top_queue_mem[top_write_pointer_q] <= top_record_i;
                top_write_pointer_q <= top_write_pointer_q + 1'b1;
            end
            if (top_dequeue_w)
                top_read_pointer_q <= top_read_pointer_q + 1'b1;
            case ({top_accept_w, top_dequeue_w})
                2'b10: top_queue_count_q <= top_queue_count_q + 1'b1;
                2'b01: top_queue_count_q <= top_queue_count_q - 1'b1;
                default: top_queue_count_q <= top_queue_count_q;
            endcase

            if (bottom_accept_w) begin
                bottom_queue_mem[bottom_write_pointer_q] <= bottom_record_i;
                bottom_write_pointer_q <= bottom_write_pointer_q + 1'b1;
            end
            if (bottom_dequeue_w)
                bottom_read_pointer_q <= bottom_read_pointer_q + 1'b1;
            case ({bottom_accept_w, bottom_dequeue_w})
                2'b10: bottom_queue_count_q <= bottom_queue_count_q + 1'b1;
                2'b01: bottom_queue_count_q <= bottom_queue_count_q - 1'b1;
                default: bottom_queue_count_q <= bottom_queue_count_q;
            endcase
        end
    end

    always_comb begin
        top_leaf_in_valid = arst_ni &&
                            (top_builder_state_q == BUILDER_LAUNCH);
        top_leaf_out_ready = arst_ni &&
                             (top_builder_state_q == BUILDER_COLLECT);
        bottom_leaf_in_valid = arst_ni &&
                               (bottom_builder_state_q == BUILDER_LAUNCH);
        bottom_leaf_out_ready = arst_ni &&
                                (bottom_builder_state_q == BUILDER_COLLECT);
    end

    enc128 #(.NCOL(128), .ROWW(7), .THRESH(15)) u_top_enc128 (
        .clk(clk_i),
        .rst_n(arst_ni),
        .in_val(top_leaf_in_valid),
        .in_rdy(top_leaf_in_ready),
        .in_row({1'b0, top_active_record_q[133:128]}),
        .in_pol(top_active_record_q[135:134] == 2'b10),
        .in_mask(top_active_record_q[127:0]),
        .in_dt(32'd0),
        .out_val(top_leaf_out_valid),
        .out_rdy(top_leaf_out_ready),
        .out_data(top_leaf_out_data)
    );

    enc128 #(.NCOL(128), .ROWW(7), .THRESH(15)) u_bottom_enc128 (
        .clk(clk_i),
        .rst_n(arst_ni),
        .in_val(bottom_leaf_in_valid),
        .in_rdy(bottom_leaf_in_ready),
        .in_row({1'b1, bottom_active_record_q[133:128]}),
        .in_pol(bottom_active_record_q[135:134] == 2'b10),
        .in_mask(bottom_active_record_q[127:0]),
        .in_dt(32'd0),
        .out_val(bottom_leaf_out_valid),
        .out_rdy(bottom_leaf_out_ready),
        .out_data(bottom_leaf_out_data)
    );

    always_ff @(posedge clk_i or negedge arst_ni) begin
        if (!arst_ni) begin
            top_builder_state_q <= BUILDER_IDLE;
            top_active_record_q <= 136'd0;
            top_expected_length_q <= 5'd0;
            top_collect_index_q <= 5'd0;
            top_fragment_valid_o <= 1'b0;
            top_fragment_raw_o <= 1'b0;
            top_fragment_length_o <= 5'd0;
            top_fragment_payload_o <= 136'd0;
        end else begin
            if (top_retire_w) begin
                top_fragment_valid_o <= 1'b0;
                top_fragment_raw_o <= 1'b0;
                top_fragment_length_o <= 5'd0;
                top_fragment_payload_o <= 136'd0;
            end

            case (top_builder_state_q)
                BUILDER_IDLE: begin
                    if (top_dequeue_w) begin
                        if (top_front_population_w >= 8'd16) begin
                            top_fragment_valid_o <= 1'b1;
                            top_fragment_raw_o <= 1'b1;
                            top_fragment_length_o <= 5'd17;
                            top_fragment_payload_o <= top_front_record_w;
                        end else begin
                            top_active_record_q <= top_front_record_w;
                            top_expected_length_q <=
                                top_front_population_w[4:0] + 5'd2;
                            top_collect_index_q <= 5'd0;
                            top_fragment_raw_o <= 1'b0;
                            top_fragment_length_o <= 5'd0;
                            top_fragment_payload_o <= 136'd0;
                            top_builder_state_q <= BUILDER_LAUNCH;
                        end
                    end
                end

                BUILDER_LAUNCH: begin
                    if (top_leaf_in_ready)
                        top_builder_state_q <= BUILDER_COLLECT;
                end

                BUILDER_COLLECT: begin
                    if (top_leaf_out_valid && top_leaf_out_ready) begin
                        top_fragment_payload_o[
                            8*top_collect_index_q +: 8
                        ] <= top_leaf_out_data;
                        if ((top_collect_index_q + 5'd1) ==
                            top_expected_length_q) begin
                            top_fragment_valid_o <= 1'b1;
                            top_fragment_raw_o <= 1'b0;
                            top_fragment_length_o <= top_expected_length_q;
                            top_builder_state_q <= BUILDER_IDLE;
                        end else begin
                            top_collect_index_q <= top_collect_index_q + 5'd1;
                        end
                    end
                end

                default: top_builder_state_q <= BUILDER_IDLE;
            endcase
        end
    end

    always_ff @(posedge clk_i or negedge arst_ni) begin
        if (!arst_ni) begin
            bottom_builder_state_q <= BUILDER_IDLE;
            bottom_active_record_q <= 136'd0;
            bottom_expected_length_q <= 5'd0;
            bottom_collect_index_q <= 5'd0;
            bottom_fragment_valid_o <= 1'b0;
            bottom_fragment_raw_o <= 1'b0;
            bottom_fragment_length_o <= 5'd0;
            bottom_fragment_payload_o <= 136'd0;
        end else begin
            if (bottom_retire_w) begin
                bottom_fragment_valid_o <= 1'b0;
                bottom_fragment_raw_o <= 1'b0;
                bottom_fragment_length_o <= 5'd0;
                bottom_fragment_payload_o <= 136'd0;
            end

            case (bottom_builder_state_q)
                BUILDER_IDLE: begin
                    if (bottom_dequeue_w) begin
                        if (bottom_front_population_w >= 8'd16) begin
                            bottom_fragment_valid_o <= 1'b1;
                            bottom_fragment_raw_o <= 1'b1;
                            bottom_fragment_length_o <= 5'd17;
                            bottom_fragment_payload_o <= bottom_front_record_w;
                        end else begin
                            bottom_active_record_q <= bottom_front_record_w;
                            bottom_expected_length_q <=
                                bottom_front_population_w[4:0] + 5'd2;
                            bottom_collect_index_q <= 5'd0;
                            bottom_fragment_raw_o <= 1'b0;
                            bottom_fragment_length_o <= 5'd0;
                            bottom_fragment_payload_o <= 136'd0;
                            bottom_builder_state_q <= BUILDER_LAUNCH;
                        end
                    end
                end

                BUILDER_LAUNCH: begin
                    if (bottom_leaf_in_ready)
                        bottom_builder_state_q <= BUILDER_COLLECT;
                end

                BUILDER_COLLECT: begin
                    if (bottom_leaf_out_valid && bottom_leaf_out_ready) begin
                        bottom_fragment_payload_o[
                            8*bottom_collect_index_q +: 8
                        ] <= bottom_leaf_out_data;
                        if ((bottom_collect_index_q + 5'd1) ==
                            bottom_expected_length_q) begin
                            bottom_fragment_valid_o <= 1'b1;
                            bottom_fragment_raw_o <= 1'b0;
                            bottom_fragment_length_o <=
                                bottom_expected_length_q;
                            bottom_builder_state_q <= BUILDER_IDLE;
                        end else begin
                            bottom_collect_index_q <=
                                bottom_collect_index_q + 5'd1;
                        end
                    end
                end

                default: bottom_builder_state_q <= BUILDER_IDLE;
            endcase
        end
    end

    always_ff @(posedge clk_i or negedge arst_ni) begin
        if (!arst_ni) begin
            top_record_accepted_o <= 1'b0;
            bottom_record_accepted_o <= 1'b0;
            accepted_count_o <= 32'd0;
            empty_suppressed_count_o <= 32'd0;
            illegal_label_count_o <= 32'd0;
            disabled_suppressed_count_o <= 32'd0;
            overflow_count_o <= 32'd0;
            sparse_count_o <= 32'd0;
            raw_count_o <= 32'd0;
            retired_count_o <= 32'd0;
            sticky_fault_o <= 1'b0;
        end else begin
            top_record_accepted_o <= top_accept_w;
            bottom_record_accepted_o <= bottom_accept_w;
            accepted_count_o <=
                saturating_add(accepted_count_o, accepted_events_w);
            empty_suppressed_count_o <= saturating_add(
                empty_suppressed_count_o, empty_events_w
            );
            illegal_label_count_o <=
                saturating_add(illegal_label_count_o, illegal_events_w);
            disabled_suppressed_count_o <= saturating_add(
                disabled_suppressed_count_o, disabled_events_w
            );
            overflow_count_o <=
                saturating_add(overflow_count_o, overflow_events_w);
            sparse_count_o <=
                saturating_add(sparse_count_o, sparse_events_w);
            raw_count_o <= saturating_add(raw_count_o, raw_events_w);
            retired_count_o <=
                saturating_add(retired_count_o, retired_events_w);
            if ((illegal_events_w != 0) || (overflow_events_w != 0))
                sticky_fault_o <= 1'b1;
        end
    end

    always_comb begin
        quiescent_o = arst_ni &&
                      (top_queue_count_q == 0) &&
                      (bottom_queue_count_q == 0) &&
                      (top_builder_state_q == BUILDER_IDLE) &&
                      (bottom_builder_state_q == BUILDER_IDLE) &&
                      top_leaf_in_ready && bottom_leaf_in_ready &&
                      !top_fragment_valid_o &&
                      !bottom_fragment_valid_o;
    end

endmodule

`default_nettype wire
