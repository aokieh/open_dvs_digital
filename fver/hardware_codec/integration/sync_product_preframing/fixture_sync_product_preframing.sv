`timescale 1ns/1ps
`default_nettype none

// This fixture implements only the frozen pre-framing contracts. It is used to
// prove that the testbench and every semantic plant elaborate and execute before
// the live product has the required interfaces.

module fixture_sync_fifo (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         wr_en,
    input  logic [135:0] wdata,
    output logic         empty,
    output logic         full,
    output logic [3:0]   numel,
    output logic [135:0] rdata
);
    logic [4:0] counter;
    logic [3:0] wr_ptr;
    logic [3:0] rd_ptr;
    logic [135:0] fifo [0:15];
    logic write;
    logic read;

    assign write = wr_en && !full;
    assign read = 1'b0;
    assign empty = (counter == 0);
    assign full = (counter == 16);
    assign numel = counter[3:0];
    assign rdata = fifo[rd_ptr];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 5'd0;
            wr_ptr <= 4'd0;
            rd_ptr <= 4'd0;
        end else if (write) begin
            fifo[wr_ptr] <= wdata;
            wr_ptr <= wr_ptr + 1'b1;
            counter <= counter + 1'b1;
        end
    end
endmodule

module fixture_sync_fifo_top (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         wr_en_fifo,
    input  logic [135:0] wdata_fifo,
    output logic         empty_fifo,
    output logic         full_fifo,
    output logic [3:0]   numel_fifo,
    output logic [15:0]  rdata_spi
);
    logic [135:0] rdata_fifo;

    fixture_sync_fifo i_sync_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(wr_en_fifo),
        .wdata(wdata_fifo),
        .empty(empty_fifo),
        .full(full_fifo),
        .numel(numel_fifo),
        .rdata(rdata_fifo)
    );

    assign rdata_spi = empty_fifo ? 16'd0 : rdata_fifo[15:0];
endmodule

module fixture_col_readout (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         fifo_wr_en,
    input  logic [5:0]   row_addr,
    input  logic [1:0]   event_mode,
    output logic         source_record_valid_o,
    output logic [135:0] source_record_o,
    output logic         empty_fifo,
    output logic         full_fifo,
    output logic [3:0]   numel_fifo,
    output logic [15:0]  rdata_spi
);
    logic [63:0] col_left_m2;
    logic [63:0] col_right_m2;
    logic [135:0] internal_wdata_fifo;

    assign internal_wdata_fifo = {
        event_mode, row_addr, col_left_m2, col_right_m2
    };
    assign source_record_valid_o = fifo_wr_en;
    assign source_record_o = {
        event_mode, row_addr, col_left_m2, col_right_m2
    };

    fixture_sync_fifo_top i_sync_fifo_top (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en_fifo(fifo_wr_en),
        .wdata_fifo(internal_wdata_fifo),
        .empty_fifo(empty_fifo),
        .full_fifo(full_fifo),
        .numel_fifo(numel_fifo),
        .rdata_spi(rdata_spi)
    );
endmodule

module fixture_dvs_core (
    input  logic         sys_clk,
    input  logic         rst_n,
    output logic         top_record_valid_o,
    output logic [135:0] top_record_o,
    output logic         bottom_record_valid_o,
    output logic [135:0] bottom_record_o,
    output logic         empty_fifo_top,
    output logic         full_fifo_top,
    output logic [3:0]   numel_fifo_top,
    output logic [15:0]  rdata_spi_top,
    output logic         empty_fifo_bot,
    output logic         full_fifo_bot,
    output logic [3:0]   numel_fifo_bot,
    output logic [15:0]  rdata_spi_bot
);
    fixture_col_readout i_col_readout_top (
        .clk(sys_clk),
        .rst_n(rst_n),
        .fifo_wr_en(1'b0),
        .row_addr(6'd0),
        .event_mode(2'd0),
        .source_record_valid_o(top_record_valid_o),
        .source_record_o(top_record_o),
        .empty_fifo(empty_fifo_top),
        .full_fifo(full_fifo_top),
        .numel_fifo(numel_fifo_top),
        .rdata_spi(rdata_spi_top)
    );

    fixture_col_readout i_col_readout_bot (
        .clk(sys_clk),
        .rst_n(rst_n),
        .fifo_wr_en(1'b0),
        .row_addr(6'd0),
        .event_mode(2'd0),
        .source_record_valid_o(bottom_record_valid_o),
        .source_record_o(bottom_record_o),
        .empty_fifo(empty_fifo_bot),
        .full_fifo(full_fifo_bot),
        .numel_fifo(numel_fifo_bot),
        .rdata_spi(rdata_spi_bot)
    );
endmodule

module spi_peripheral_re (
    input  logic        CS_N,
    input  logic        SCK,
    input  logic [3:0]  COPI,
    output logic [3:0]  CIPO,
    output logic [4:0]  addr_reg,
    output logic        we_reg,
    output logic        we_out,
    output logic [31:0] wdata_reg,
    output logic [3:0]  wmask_reg,
    input  logic [31:0] rdata_reg,
    input  logic [15:0] rdata_spi_0,
    input  logic [15:0] rdata_spi_1,
    output logic [1:0]  shift_en_fifo,
    input  logic        data_ready_spi,
    output logic [31:0] spi_last_read_data_reg,
    output logic [7:0]  opcode_0_reg,
    output logic [7:0]  addr_0_reg,
    output logic        serial_beat_complete_o
);
    logic [7:0] opcode_0;
    logic [2:0] opcode_valid;
    logic [3:0] cycle_count;
    logic [3:0] fifo_shift_count;
    logic [7:0] tx_data_3;
    logic [7:0] tx_data_2;
    logic [7:0] tx_data_1;
    logic [7:0] tx_data_0;

    assign opcode_valid = opcode_0[2:0];
    assign addr_reg = 5'd0;
    assign we_reg = 1'b0;
    assign we_out = 1'b0;
    assign wdata_reg = 32'd0;
    assign wmask_reg = 4'd0;
    assign opcode_0_reg = {5'd0, opcode_valid};
    assign addr_0_reg = 8'd0;
    assign spi_last_read_data_reg = {rdata_spi_1, rdata_spi_0};
    assign tx_data_3 = rdata_spi_1[15:8];
    assign tx_data_2 = rdata_spi_1[7:0];
    assign tx_data_1 = rdata_spi_0[15:8];
    assign tx_data_0 = rdata_spi_0[7:0];

    wire _unused = &{1'b0, rdata_reg, COPI[3:1]};

    always_ff @(posedge SCK or posedge CS_N) begin
        if (CS_N) begin
            opcode_0 <= 8'd0;
        end else if (cycle_count <= 7) begin
            opcode_0 <= {opcode_0[6:0], COPI[0]};
        end
    end

    always_ff @(posedge SCK or posedge CS_N) begin
        if (CS_N) begin
            cycle_count <= 4'd0;
            fifo_shift_count <= 4'd0;
            shift_en_fifo <= 2'b00;
            serial_beat_complete_o <= 1'b0;
        end else begin
            serial_beat_complete_o <= 1'b0;
            if (opcode_valid == 3'b111) begin
                if (cycle_count < 4'd13) begin
                    cycle_count <= cycle_count + 1'b1;
                    shift_en_fifo <= 2'b00;
                end else if (cycle_count == 4'd13) begin
                    shift_en_fifo <= data_ready_spi ? 2'b11 : 2'b00;
                    cycle_count <= 4'd14;
                end else if (cycle_count == 4'd14) begin
                    shift_en_fifo <= 2'b00;
                    cycle_count <= 4'd15;
                end else begin
                    shift_en_fifo <= 2'b00;
                    cycle_count <= 4'd8;
                    fifo_shift_count <= fifo_shift_count + 1'b1;
                    serial_beat_complete_o <= 1'b1;
                end
            end else begin
                shift_en_fifo <= 2'b00;
                cycle_count <= cycle_count + 1'b1;
            end
        end
    end

    always_ff @(posedge SCK or posedge CS_N) begin
        if (CS_N) begin
            CIPO <= 4'd0;
        end else if (opcode_valid == 3'b111 && cycle_count >= 8) begin
            CIPO[3] <= tx_data_3[15-cycle_count];
            CIPO[2] <= tx_data_2[15-cycle_count];
            CIPO[1] <= tx_data_1[15-cycle_count];
            CIPO[0] <= tx_data_0[15-cycle_count];
        end
    end
endmodule

module final_top3 (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        CS_N,
    input  logic [3:0]  COPI,
    output logic [3:0]  CIPO,
    input  logic [63:0] array_col_top_left,
    input  logic [63:0] array_col_top_right,
    input  logic [63:0] array_col_bot_left,
    input  logic [63:0] array_col_bot_right,
    output logic        data_ready_top,
    input  logic        sm_enable,
    input  logic        pix_rst_global_in
);
    logic top_record_valid;
    logic [135:0] top_record;
    logic bottom_record_valid;
    logic [135:0] bottom_record;
    logic empty_fifo_top;
    logic full_fifo_top;
    logic [3:0] numel_fifo_top;
    logic [15:0] raw_rdata_spi_0;
    logic empty_fifo_bot;
    logic full_fifo_bot;
    logic [3:0] numel_fifo_bot;
    logic [15:0] raw_rdata_spi_1;
    logic raw_data_ready_fifo;
    logic [1:0] shift_en_fifo;
    logic [1:0] raw_shift_en_fifo;
    logic [1:0] sync_shift_en_fifo;
    logic [15:0] rdata_spi_0;
    logic [15:0] rdata_spi_1;
    logic data_ready_fifo;
    logic serial_beat_complete;
    logic sync_product_rst_n;

    logic sync_top_record_accepted;
    logic sync_bottom_record_accepted;
    logic sync_top_fragment_valid;
    logic sync_top_fragment_raw;
    logic [4:0] sync_top_fragment_length;
    logic [135:0] sync_top_fragment_payload;
    logic sync_bottom_fragment_valid;
    logic sync_bottom_fragment_raw;
    logic [4:0] sync_bottom_fragment_length;
    logic [135:0] sync_bottom_fragment_payload;
    logic sync_product_quiescent;
    logic [31:0] sync_accepted_count;
    logic [31:0] sync_empty_suppressed_count;
    logic [31:0] sync_illegal_label_count;
    logic [31:0] sync_disabled_suppressed_count;
    logic [31:0] sync_overflow_count;
    logic [31:0] sync_sparse_count;
    logic [31:0] sync_raw_count;
    logic [31:0] sync_retired_count;
    logic sync_sticky_fault;

    logic [4:0] addr_reg;
    logic we_reg;
    logic we_out;
    logic [31:0] wdata_reg;
    logic [3:0] wmask_reg;
    logic [31:0] rdata_reg;
    logic [31:0] spi_last_read_data_reg;
    logic [7:0] opcode_0_reg;
    logic [7:0] addr_0_reg;

    wire _unused = &{
        1'b0, array_col_top_left, array_col_top_right,
        array_col_bot_left, array_col_bot_right, sm_enable,
        pix_rst_global_in, full_fifo_top, full_fifo_bot,
        numel_fifo_top, numel_fifo_bot, raw_shift_en_fifo,
        sync_product_quiescent, sync_empty_suppressed_count,
        sync_illegal_label_count, sync_disabled_suppressed_count,
        sync_overflow_count, sync_sparse_count, sync_raw_count,
        sync_retired_count, sync_sticky_fault, we_out,
        spi_last_read_data_reg, opcode_0_reg, addr_0_reg
    };

    assign raw_data_ready_fifo = !empty_fifo_top && !empty_fifo_bot;
    assign data_ready_top = data_ready_fifo;

    fixture_dvs_core i_dvs_core (
        .sys_clk(clk),
        .rst_n(rst_n),
        .top_record_valid_o(top_record_valid),
        .top_record_o(top_record),
        .bottom_record_valid_o(bottom_record_valid),
        .bottom_record_o(bottom_record),
        .empty_fifo_top(empty_fifo_top),
        .full_fifo_top(full_fifo_top),
        .numel_fifo_top(numel_fifo_top),
        .rdata_spi_top(raw_rdata_spi_0),
        .empty_fifo_bot(empty_fifo_bot),
        .full_fifo_bot(full_fifo_bot),
        .numel_fifo_bot(numel_fifo_bot),
        .rdata_spi_bot(raw_rdata_spi_1)
    );

    rst_sync i_sync_product_reset (
        .clk(clk),
        .rst_n(rst_n),
        .rst_sync_n(sync_product_rst_n)
    );

    opendvs_sync_product_encoder_core i_sync_product_encoder_core (
        .clk_i(clk),
        .arst_ni(sync_product_rst_n),
        .admit_enable_i(1'b0),
        .top_record_valid_i(top_record_valid),
        .top_record_i(top_record),
        .top_record_accepted_o(sync_top_record_accepted),
        .bottom_record_valid_i(bottom_record_valid),
        .bottom_record_i(bottom_record),
        .bottom_record_accepted_o(sync_bottom_record_accepted),
        .top_fragment_valid_o(sync_top_fragment_valid),
        .top_fragment_ready_i(1'b0),
        .top_fragment_raw_o(sync_top_fragment_raw),
        .top_fragment_length_o(sync_top_fragment_length),
        .top_fragment_payload_o(sync_top_fragment_payload),
        .bottom_fragment_valid_o(sync_bottom_fragment_valid),
        .bottom_fragment_ready_i(1'b0),
        .bottom_fragment_raw_o(sync_bottom_fragment_raw),
        .bottom_fragment_length_o(sync_bottom_fragment_length),
        .bottom_fragment_payload_o(sync_bottom_fragment_payload),
        .quiescent_o(sync_product_quiescent),
        .accepted_count_o(sync_accepted_count),
        .empty_suppressed_count_o(sync_empty_suppressed_count),
        .illegal_label_count_o(sync_illegal_label_count),
        .disabled_suppressed_count_o(sync_disabled_suppressed_count),
        .overflow_count_o(sync_overflow_count),
        .sparse_count_o(sync_sparse_count),
        .raw_count_o(sync_raw_count),
        .retired_count_o(sync_retired_count),
        .sticky_fault_o(sync_sticky_fault)
    );

    opendvs_sync_mode_ownership_shell i_sync_mode_ownership (
        .clk_i(clk),
        .rst_ni(rst_n),
        .we_reg_i(we_reg),
        .addr_reg_i(addr_reg),
        .wdata_reg_i(wdata_reg),
        .wmask_reg_i(wmask_reg),
        .regfile_rdata_i(32'd0),
        .regfile_rdata_o(rdata_reg),
        .serial_consume_i(shift_en_fifo),
        .raw_consume_o(raw_shift_en_fifo),
        .sync_consume_o(sync_shift_en_fifo),
        .raw_ready_i(raw_data_ready_fifo),
        .sync_ready_i(1'b0),
        .selected_ready_o(data_ready_fifo),
        .raw_data_0_i(raw_rdata_spi_0),
        .raw_data_1_i(raw_rdata_spi_1),
        .sync_data_0_i(16'b0),
        .sync_data_1_i(16'b0),
        .selected_data_0_o(rdata_spi_0),
        .selected_data_1_o(rdata_spi_1),
        .sync_available_i(1'b0),
        .quiescent_i(CS_N)
    );

    spi_peripheral_re i_spi_peripheral (
        .CS_N(CS_N),
        .SCK(clk),
        .COPI(COPI),
        .CIPO(CIPO),
        .addr_reg(addr_reg),
        .we_reg(we_reg),
        .we_out(we_out),
        .wdata_reg(wdata_reg),
        .wmask_reg(wmask_reg),
        .rdata_reg(rdata_reg),
        .rdata_spi_0(rdata_spi_0),
        .rdata_spi_1(rdata_spi_1),
        .shift_en_fifo(shift_en_fifo),
        .data_ready_spi(data_ready_fifo),
        .spi_last_read_data_reg(spi_last_read_data_reg),
        .opcode_0_reg(opcode_0_reg),
        .addr_0_reg(addr_0_reg),
        .serial_beat_complete_o(serial_beat_complete)
    );
endmodule

`default_nettype wire
