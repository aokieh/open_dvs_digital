module opendvs_sync_mode_ownership_shell (
    input  logic        clk_i,
    input  logic        rst_ni,

    input  logic        we_reg_i,
    input  logic [4:0]  addr_reg_i,
    input  logic [31:0] wdata_reg_i,
    input  logic [3:0]  wmask_reg_i,
    input  logic [31:0] regfile_rdata_i,
    output logic [31:0] regfile_rdata_o,

    input  logic [1:0]  serial_consume_i,
    output logic [1:0]  raw_consume_o,
    output logic [1:0]  sync_consume_o,

    input  logic        raw_ready_i,
    input  logic        sync_ready_i,
    output logic        selected_ready_o,
    input  logic [15:0] raw_data_0_i,
    input  logic [15:0] raw_data_1_i,
    input  logic [15:0] sync_data_0_i,
    input  logic [15:0] sync_data_1_i,
    output logic [15:0] selected_data_0_o,
    output logic [15:0] selected_data_1_o,

    input  logic        sync_available_i,
    input  logic        quiescent_i
);
    localparam logic [4:0] MODE_WORD = 5'd31;

    logic [1:0] mode_request_q;
    logic       sticky_unavailable_q;
    logic       sticky_illegal_q;
    logic       sync_owner_q;
    logic [31:0] mode_status;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            mode_request_q       <= 2'b00;
            sticky_unavailable_q <= 1'b0;
            sticky_illegal_q     <= 1'b0;
        end else if (we_reg_i && (addr_reg_i == MODE_WORD) && wmask_reg_i[0]) begin
            mode_request_q <= wdata_reg_i[1:0];
            if (wdata_reg_i[1:0] == 2'b10)
                sticky_unavailable_q <= 1'b1;
            if (wdata_reg_i[1:0] == 2'b11)
                sticky_illegal_q <= 1'b1;
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            sync_owner_q <= 1'b0;
        end else if (quiescent_i) begin
            sync_owner_q <= sync_available_i && (mode_request_q == 2'b01);
        end
    end

    always_comb begin
        mode_status = 32'd0;
        mode_status[1:0] = mode_request_q;
        mode_status[4]   = !sync_owner_q;
        mode_status[5]   = sync_owner_q;
        mode_status[6]   = (mode_request_q == 2'b01) && !sync_owner_q;
        mode_status[8]   = sticky_unavailable_q;
        mode_status[9]   = sticky_illegal_q;

        if (addr_reg_i == MODE_WORD)
            regfile_rdata_o = mode_status;
        else
            regfile_rdata_o = regfile_rdata_i;

        raw_consume_o  = serial_consume_i & {2{!sync_owner_q}};
        sync_consume_o = serial_consume_i & {2{sync_owner_q}};

        if (sync_owner_q) begin
            selected_ready_o  = sync_ready_i;
            selected_data_0_o = sync_data_0_i;
            selected_data_1_o = sync_data_1_i;
        end else begin
            selected_ready_o  = raw_ready_i;
            selected_data_0_o = raw_data_0_i;
            selected_data_1_o = raw_data_1_i;
        end
    end
endmodule : opendvs_sync_mode_ownership_shell
