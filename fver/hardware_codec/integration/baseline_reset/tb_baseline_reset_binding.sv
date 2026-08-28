`timescale 1ns/1ps
`default_nettype none

module tb_baseline_reset_binding;
    logic sys_clk;
    logic rst_n;
    logic fifo_rst_n;
    logic fsm_rst_n;
    integer checks_completed;

    fifo_rows_cols_macro2 dut (
        .sys_clk    (sys_clk),
        .rst_n      (rst_n),
        .fifo_rst_n (fifo_rst_n),
        .fsm_rst_n  (fsm_rst_n)
    );

    task automatic check_effective_resets(
        input string check_name,
        input logic expected_row_top,
        input logic expected_row_bottom,
        input logic expected_column_top,
        input logic expected_column_bottom
    );
        begin
            #1;
            if ((dut.fsm_row_rst_n_top !== expected_row_top) ||
                (dut.fsm_row_rst_n_bot !== expected_row_bottom) ||
                (dut.col_rst_n_top !== expected_column_top) ||
                (dut.col_rst_n_bot !== expected_column_bottom)) begin
                $display("@@NO_ENCODER_BASELINE_RESET_FAIL@@ check=%s expected=%b%b%b%b actual=%b%b%b%b",
                         check_name,
                         expected_row_top,
                         expected_row_bottom,
                         expected_column_top,
                         expected_column_bottom,
                         dut.fsm_row_rst_n_top,
                         dut.fsm_row_rst_n_bot,
                         dut.col_rst_n_top,
                         dut.col_rst_n_bot);
                $fatal(1, "The no-encoder baseline reset binding failed");
            end
            checks_completed = checks_completed + 1;
        end
    endtask

    initial begin
        sys_clk = 1'b0;
        checks_completed = 0;

        rst_n = 1'b0;
        fifo_rst_n = 1'b0;
        fsm_rst_n = 1'b0;
        check_effective_resets("global-reset-with-software-pulses-released",
                               1'b0, 1'b0, 1'b0, 1'b0);

        fifo_rst_n = 1'b1;
        fsm_rst_n = 1'b1;
        check_effective_resets("global-reset-with-software-pulses-asserted",
                               1'b0, 1'b0, 1'b0, 1'b0);

        rst_n = 1'b1;
        fifo_rst_n = 1'b0;
        fsm_rst_n = 1'b0;
        check_effective_resets("released-software-pulses",
                               1'b1, 1'b1, 1'b1, 1'b1);

        fsm_rst_n = 1'b1;
        check_effective_resets("isolated-row-state-machine-pulse",
                               1'b0, 1'b0, 1'b1, 1'b1);

        fsm_rst_n = 1'b0;
        check_effective_resets("row-state-machine-pulse-release",
                               1'b1, 1'b1, 1'b1, 1'b1);

        fifo_rst_n = 1'b1;
        check_effective_resets("isolated-first-in-first-out-pulse",
                               1'b1, 1'b1, 1'b0, 1'b0);

        fifo_rst_n = 1'b0;
        check_effective_resets("first-in-first-out-pulse-release",
                               1'b1, 1'b1, 1'b1, 1'b1);

        fifo_rst_n = 1'b1;
        fsm_rst_n = 1'b1;
        check_effective_resets("simultaneous-software-reset-pulses",
                               1'b0, 1'b0, 1'b0, 1'b0);

        fsm_rst_n = 1'b0;
        check_effective_resets("row-state-machine-release-with-first-in-first-out-held",
                               1'b1, 1'b1, 1'b0, 1'b0);

        fsm_rst_n = 1'b1;
        fifo_rst_n = 1'b0;
        check_effective_resets("first-in-first-out-release-with-row-state-machine-held",
                               1'b0, 1'b0, 1'b1, 1'b1);

        fsm_rst_n = 1'b0;
        check_effective_resets("final-software-reset-release",
                               1'b1, 1'b1, 1'b1, 1'b1);

        if (checks_completed != 11) begin
            $display("@@NO_ENCODER_BASELINE_RESET_FAIL@@ check=check-count expected=11 actual=%0d",
                     checks_completed);
            $fatal(1, "The no-encoder baseline reset check count was wrong");
        end

        $display("@@NO_ENCODER_BASELINE_RESET_ACCEPTANCE_PASS@@ checks=11 reset_equations=4");
        $finish;
    end
endmodule

`default_nettype wire
