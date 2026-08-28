`timescale 1ns/1ps
`default_nettype none

module tb_sync_mode_ownership_safety;
    localparam logic [4:0] MODE_WORD = 5'd31;

    logic clk;
    logic rst_n;

    logic        we_reg;
    logic [4:0]  addr_reg;
    logic [31:0] wdata_reg;
    logic [3:0]  wmask_reg;
    logic [31:0] regfile_rdata;
    logic [31:0] selected_regfile_rdata;
    logic [1:0]  serial_consume;
    logic [1:0]  raw_consume;
    logic [1:0]  sync_consume;
    logic        raw_ready;
    logic        sync_ready;
    logic        selected_ready;
    logic [15:0] raw_data_0;
    logic [15:0] raw_data_1;
    logic [15:0] sync_data_0;
    logic [15:0] sync_data_1;
    logic [15:0] selected_data_0;
    logic [15:0] selected_data_1;
    logic        sync_available;
    logic        quiescent;

    logic        integrated_cs_n;
    logic [3:0]  integrated_copi;
    logic [3:0]  integrated_cipo;
    logic [63:0] integrated_array_col_top_left;
    logic [63:0] integrated_array_col_top_right;
    logic [63:0] integrated_array_col_bot_left;
    logic [63:0] integrated_array_col_bot_right;
    logic        integrated_sm_enable;
    logic        integrated_pix_rst_global_in;

    opendvs_sync_mode_ownership_shell shell_dut (
        .clk_i             (clk),
        .rst_ni            (rst_n),
        .we_reg_i          (we_reg),
        .addr_reg_i        (addr_reg),
        .wdata_reg_i       (wdata_reg),
        .wmask_reg_i       (wmask_reg),
        .regfile_rdata_i   (regfile_rdata),
        .regfile_rdata_o   (selected_regfile_rdata),
        .serial_consume_i  (serial_consume),
        .raw_consume_o     (raw_consume),
        .sync_consume_o    (sync_consume),
        .raw_ready_i       (raw_ready),
        .sync_ready_i      (sync_ready),
        .selected_ready_o  (selected_ready),
        .raw_data_0_i      (raw_data_0),
        .raw_data_1_i      (raw_data_1),
        .sync_data_0_i     (sync_data_0),
        .sync_data_1_i     (sync_data_1),
        .selected_data_0_o (selected_data_0),
        .selected_data_1_o (selected_data_1),
        .sync_available_i  (sync_available),
        .quiescent_i       (quiescent)
    );

    final_top3 integrated_dut (
        .clk                 (clk),
        .rst_n               (rst_n),
        .CS_N                (integrated_cs_n),
        .COPI                (integrated_copi),
        .CIPO                (integrated_cipo),
        .array_col_top_left  (integrated_array_col_top_left),
        .array_col_top_right (integrated_array_col_top_right),
        .array_col_bot_left  (integrated_array_col_bot_left),
        .array_col_bot_right (integrated_array_col_bot_right),
        .sm_enable           (integrated_sm_enable),
        .pix_rst_global_in   (integrated_pix_rst_global_in)
    );

    always #5 clk = ~clk;

    task automatic fail(input string check_name);
        begin
            $display("@@SYNC_MODE_OWNERSHIP_SAFETY_FAIL@@ check=%s", check_name);
            $fatal(1, "Synchronous ownership safety check failed");
        end
    endtask

    task automatic tick;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    task automatic write_mode(input logic [1:0] mode);
        begin
            @(negedge clk);
            addr_reg  = MODE_WORD;
            wdata_reg = {30'd0, mode};
            wmask_reg = 4'b0001;
            we_reg    = 1'b1;
            tick();
            @(negedge clk);
            we_reg    = 1'b0;
            wmask_reg = 4'b0000;
        end
    endtask

    task automatic expect_status(
        input string check_name,
        input logic [31:0] expected
    );
        begin
            addr_reg = MODE_WORD;
            #1;
            if (selected_regfile_rdata !== expected)
                fail(check_name);
        end
    endtask

    task automatic expect_raw_path(input string check_name);
        begin
            #1;
            if (selected_data_0 !== raw_data_0 ||
                selected_data_1 !== raw_data_1 ||
                selected_ready !== raw_ready ||
                raw_consume !== serial_consume ||
                sync_consume !== 2'b00)
                fail(check_name);
        end
    endtask

    task automatic expect_sync_path(input string check_name);
        begin
            #1;
            if (selected_data_0 !== sync_data_0 ||
                selected_data_1 !== sync_data_1 ||
                selected_ready !== sync_ready ||
                raw_consume !== 2'b00 ||
                sync_consume !== serial_consume)
                fail(check_name);
        end
    endtask

    integer address_index;
    initial begin
        clk = 1'b0;
        rst_n = 1'b0;

        we_reg = 1'b0;
        addr_reg = 5'd0;
        wdata_reg = 32'd0;
        wmask_reg = 4'd0;
        regfile_rdata = 32'd0;
        serial_consume = 2'b10;
        raw_ready = 1'b1;
        sync_ready = 1'b0;
        raw_data_0 = 16'h1234;
        raw_data_1 = 16'h5678;
        sync_data_0 = 16'habcd;
        sync_data_1 = 16'hef01;
        sync_available = 1'b1;
        quiescent = 1'b0;

        integrated_cs_n = 1'b0;
        integrated_copi = 4'd0;
        integrated_array_col_top_left = 64'd0;
        integrated_array_col_top_right = 64'd0;
        integrated_array_col_bot_left = 64'd0;
        integrated_array_col_bot_right = 64'd0;
        integrated_sm_enable = 1'b0;
        integrated_pix_rst_global_in = 1'b0;

        repeat (3) tick();
        @(negedge clk);
        rst_n = 1'b1;
        repeat (4) tick();

        if (integrated_dut.i_sync_mode_ownership.sync_available_i !== 1'b0)
            fail("integrated-availability-not-tied-low-after-elaboration");
        if (integrated_dut.i_sync_mode_ownership.sync_owner_q !== 1'b0)
            fail("integrated-default-owner-not-raw");
        if (integrated_dut.i_sync_mode_ownership.quiescent_i !== 1'b0)
            fail("integrated-active-transaction-reported-quiescent");

        write_mode(2'b01);
        expect_status("mode-01-not-pending-before-quiescence", 32'h0000_0051);
        expect_raw_path("mode-01-did-not-retain-raw-path-before-quiescence");

        @(negedge clk);
        quiescent = 1'b1;
        tick();
        expect_status("mode-01-did-not-commit-at-quiescence", 32'h0000_0021);
        expect_sync_path("synchronous-path-not-selected-after-safe-commit");

        @(negedge clk);
        quiescent = 1'b0;
        sync_available = 1'b0;
        tick();
        expect_status("availability-drop-changed-live-owner", 32'h0000_0021);
        expect_sync_path("availability-drop-changed-live-consume-path");

        write_mode(2'b00);
        expect_status("raw-request-changed-live-owner", 32'h0000_0020);
        expect_sync_path("raw-request-changed-live-consume-path");

        write_mode(2'b11);
        expect_status("illegal-request-changed-live-owner", 32'h0000_0223);
        expect_sync_path("illegal-request-changed-live-consume-path");

        write_mode(2'b10);
        expect_status("unavailable-request-changed-live-owner", 32'h0000_0322);
        expect_sync_path("unavailable-request-changed-live-consume-path");

        @(negedge clk);
        quiescent = 1'b1;
        tick();
        expect_status("invalid-request-did-not-return-raw-at-boundary", 32'h0000_0312);
        expect_raw_path("raw-path-not-restored-at-safe-boundary");

        write_mode(2'b00);
        expect_status("sticky-status-cleared-by-mode-00-write", 32'h0000_0310);
        expect_raw_path("mode-00-disturbed-restored-raw-path");

        for (address_index = 0; address_index < 31; address_index = address_index + 1) begin
            addr_reg = address_index[4:0];
            regfile_rdata = 32'ha500_0000 ^ (32'h0101_0101 * address_index);
            #1;
            if (selected_regfile_rdata !== regfile_rdata)
                fail("non-word-31-readback-not-bit-exact");
        end

        @(negedge clk);
        rst_n = 1'b0;
        #1;
        expect_status("sticky-status-not-cleared-by-reset", 32'h0000_0010);
        @(negedge clk);
        rst_n = 1'b1;
        repeat (2) tick();

        integrated_cs_n = 1'b1;
        tick();
        if (integrated_dut.i_sync_mode_ownership.quiescent_i !== 1'b0)
            fail("integrated-quiescence-rose-before-abort");
        tick();
        if (integrated_dut.stream_abort !== 1'b1 ||
            integrated_dut.i_sync_mode_ownership.quiescent_i !== 1'b0)
            fail("integrated-abort-boundary-not-separated-from-quiescence");
        tick();
        if (integrated_dut.stream_abort !== 1'b0 ||
            integrated_dut.i_sync_mode_ownership.quiescent_i !== 1'b1)
            fail("integrated-quiescence-not-derived-from-settled-stages");
        if (integrated_dut.i_sync_mode_ownership.sync_available_i !== 1'b0 ||
            integrated_dut.i_sync_mode_ownership.sync_owner_q !== 1'b0)
            fail("integrated-default-off-contract-not-retained");

        $display("@@SYNC_MODE_OWNERSHIP_SAFETY_PASS@@ raw_pending=1 sync_commit=1 midburst_holds=4 safe_return=1 inactive_isolation=1 sticky_reset=1 readback_addresses=31 integrated_availability_low=1");
        $finish;
    end
endmodule

`default_nettype wire
