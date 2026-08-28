`timescale 1ns/1ps
`default_nettype none

module tb_sync_mode_ownership_product;
    localparam logic [4:0] MODE_WORD = 5'd31;

    logic clk;
    logic rst_n;
    logic CS_N;
    logic [3:0] COPI;
    logic [3:0] CIPO;
    logic [63:0] array_col_top_left;
    logic [63:0] array_col_top_right;
    logic [63:0] array_col_bot_left;
    logic [63:0] array_col_bot_right;
    logic sm_enable;
    logic pix_rst_global_in;

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
        .sm_enable           (sm_enable),
        .pix_rst_global_in   (pix_rst_global_in)
    );

    always #10 clk = ~clk;

    task automatic fail(
        input string check_name,
        input logic [31:0] expected,
        input logic [31:0] actual
    );
        begin
            $display("@@SYNC_MODE_OWNERSHIP_RED@@ check=%s expected=%08h actual=%08h",
                     check_name, expected, actual);
            $fatal(1, "Synchronous mode ownership product check failed");
        end
    endtask

    task automatic reset_design;
        begin
            CS_N = 1'b1;
            COPI = 4'd0;
            rst_n = 1'b0;
            repeat (3) @(posedge clk);
            @(negedge clk);
            rst_n = 1'b1;
            repeat (4) @(posedge clk);
            #1;
        end
    endtask

    task automatic qspi_write_word(
        input logic [7:0] byte_address,
        input logic [31:0] data
    );
        integer bit_index;
        begin
            @(negedge clk);
            CS_N = 1'b0;
            for (bit_index = 7; bit_index >= 0; bit_index = bit_index - 1) begin
                COPI[0] = (8'h06 >> bit_index) & 1'b1;
                COPI[1] = (byte_address >> bit_index) & 1'b1;
                COPI[3:2] = 2'b00;
                @(negedge clk);
            end
            for (bit_index = 7; bit_index >= 0; bit_index = bit_index - 1) begin
                COPI[3] = (data >> (24 + bit_index)) & 1'b1;
                COPI[2] = (data >> (16 + bit_index)) & 1'b1;
                COPI[1] = (data >> (8 + bit_index)) & 1'b1;
                COPI[0] = (data >> bit_index) & 1'b1;
                @(negedge clk);
            end
            repeat (2) @(negedge clk);
            CS_N = 1'b1;
            COPI = 4'd0;
            @(negedge clk);
        end
    endtask

    task automatic qspi_write_byte(
        input logic [7:0] byte_address,
        input logic [7:0] data
    );
        integer bit_index;
        begin
            @(negedge clk);
            CS_N = 1'b0;
            for (bit_index = 7; bit_index >= 0; bit_index = bit_index - 1) begin
                COPI[0] = (8'h04 >> bit_index) & 1'b1;
                COPI[1] = (byte_address >> bit_index) & 1'b1;
                COPI[3:2] = 2'b00;
                @(negedge clk);
            end
            for (bit_index = 7; bit_index >= 0; bit_index = bit_index - 1) begin
                COPI[0] = (data >> bit_index) & 1'b1;
                COPI[3:1] = 3'b000;
                @(negedge clk);
            end
            repeat (2) @(negedge clk);
            CS_N = 1'b1;
            COPI = 4'd0;
            @(negedge clk);
        end
    endtask

    task automatic qspi_read_word(
        input logic [7:0] byte_address,
        output logic [31:0] data
    );
        integer bit_index;
        begin
            data = 32'd0;
            @(negedge clk);
            CS_N = 1'b0;
            for (bit_index = 7; bit_index >= 0; bit_index = bit_index - 1) begin
                COPI[0] = (8'h02 >> bit_index) & 1'b1;
                COPI[1] = (byte_address >> bit_index) & 1'b1;
                COPI[3:2] = 2'b00;
                @(negedge clk);
            end
            COPI = 4'd0;
            for (bit_index = 7; bit_index >= 0; bit_index = bit_index - 1) begin
                @(posedge clk);
                #1;
                data[24 + bit_index] = CIPO[3];
                data[16 + bit_index] = CIPO[2];
                data[8 + bit_index] = CIPO[1];
                data[bit_index] = CIPO[0];
                @(negedge clk);
            end
            CS_N = 1'b1;
            @(negedge clk);
        end
    endtask

    task automatic expect_word31_status(
        input string check_name,
        input logic [31:0] expected
    );
        logic [31:0] actual;
        begin
            qspi_read_word(8'd124, actual);
            if (actual !== expected)
                fail(check_name, expected, actual);
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

        reset_design();
        expect_word31_status("reset-default-raw-owner", 32'h0000_0010);

        qspi_write_word(8'd124, 32'h0000_0001);
        if (dut.i_regfile.mem_in[MODE_WORD][1:0] !== 2'b01)
            fail("mode-request-preserved-in-regfile", 32'h0000_0001,
                 {30'd0, dut.i_regfile.mem_in[MODE_WORD][1:0]});
        expect_word31_status("synchronous-request-pending-unavailable", 32'h0000_0051);

        reset_design();
        qspi_write_word(8'd124, 32'h0000_0002);
        expect_word31_status("unavailable-request-falls-back-raw", 32'h0000_0112);

        reset_design();
        qspi_write_word(8'd124, 32'h0000_0003);
        expect_word31_status("illegal-request-falls-back-raw", 32'h0000_0213);

        reset_design();
        qspi_write_byte(8'd125, 8'hab);
        if (dut.i_regfile.mem_in[MODE_WORD][15:8] !== 8'hab)
            fail("high-byte-write-preserved", 32'h0000_00ab,
                 {24'd0, dut.i_regfile.mem_in[MODE_WORD][15:8]});
        expect_word31_status("high-byte-write-does-not-request-mode", 32'h0000_0010);

        qspi_write_byte(8'd108, 8'ha5);
        if (dut.event_rate_reg !== 8'ha5)
            fail("non-mode-address-cycle-identity", 32'h0000_00a5,
                 {24'd0, dut.event_rate_reg});

        $display("@@SYNC_MODE_OWNERSHIP_ACCEPTANCE_PASS@@ default_raw=1 pending_raw=1 unavailable_raw=1 illegal_raw=1 word31_storage=1 non_mode_identity=1");
        $finish;
    end
endmodule

`default_nettype wire
