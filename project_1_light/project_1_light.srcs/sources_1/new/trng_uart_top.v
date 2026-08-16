`timescale 1ns / 1ps

module trng_uart_top (
    input        sys_clk_p,
    input        sys_clk_n,
    input        sys_rst_n,
    output       uart_txd,
    output [1:0] led
);

    localparam integer RAW_BYTES = 128;
    localparam integer HASH_BYTES = 32;

    localparam integer FRAME_BYTES = 2 + 2 + RAW_BYTES + HASH_BYTES;

    localparam [3:0] ST_COLLECT      = 4'd0,
                     ST_HASH_SEND    = 4'd1,
                     ST_HASH_WAIT    = 4'd2,
                     ST_TX_LOAD      = 4'd3,
                     ST_TX_WAIT_BUSY = 4'd4,
                     ST_TX_WAIT_DONE = 4'd5;

    wire sys_clk;

    IBUFDS IBUFDS_inst (
        .O(sys_clk),
        .I(sys_clk_p),
        .IB(sys_clk_n)
    );

    wire       trng_valid;
    wire [7:0] trng_data;

    trng_core u_trng_core (
        .clk_i(sys_clk),
        .rstn_i(sys_rst_n),
        .enable_i(1'b1),
        .valid_o(trng_valid),
        .data_o(trng_data)
    );

    reg         sha_tvalid;
    reg         sha_tlast;
    reg  [7:0]  sha_tdata;
    wire        sha_tready;
    wire        sha_ovalid;
    wire [255:0] sha_osha;

    sha256 u_sha256 (
        .rstn(sys_rst_n),
        .clk(sys_clk),
        .tready(sha_tready),
        .tvalid(sha_tvalid),
        .tlast(sha_tlast),
        .tid(32'd0),
        .tdata(sha_tdata),
        .ovalid(sha_ovalid),
        .oid(),
        .olen(),
        .osha(sha_osha)
    );

    reg  [7:0] uart_data;
    reg        uart_en;
    wire       uart_busy;

    uart_tx #(
        .CLK_FREQ(100_000_000),
        .BAUD_RATE(115_200)
    ) u_uart_tx (
        .clk(sys_clk),
        .rst_n(sys_rst_n),
        .tx_data(uart_data),
        .tx_en(uart_en),
        .txd(uart_txd),
        .tx_busy(uart_busy)
    );

    reg [3:0] state;
    reg [7:0] raw_mem [0:RAW_BYTES-1];
    reg [7:0] hash_mem [0:HASH_BYTES-1];
    reg [6:0] raw_count;
    reg [6:0] send_index;
    reg [5:0] hash_index;
    reg [7:0] tx_index;
    reg [15:0] frame_count;

    integer i;

    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            state <= ST_COLLECT;
            raw_count <= 7'd0;
            send_index <= 7'd0;
            hash_index <= 6'd0;
            tx_index <= 8'd0;
            frame_count <= 16'd0;
            sha_tvalid <= 1'b0;
            sha_tlast <= 1'b0;
            sha_tdata <= 8'd0;
            uart_data <= 8'd0;
            uart_en <= 1'b0;

            for (i = 0; i < RAW_BYTES; i = i + 1) begin
                raw_mem[i] <= 8'd0;
            end
            for (i = 0; i < HASH_BYTES; i = i + 1) begin
                hash_mem[i] <= 8'd0;
            end
        end else begin
            sha_tvalid <= 1'b0;
            sha_tlast <= 1'b0;
            uart_en <= 1'b0;

            case (state)
                ST_COLLECT: begin
                    if (trng_valid) begin
                        raw_mem[raw_count] <= trng_data;

                        if (raw_count == RAW_BYTES - 1) begin
                            raw_count <= 7'd0;
                            send_index <= 7'd0;
                            state <= ST_HASH_SEND;
                        end else begin
                            raw_count <= raw_count + 1'b1;
                        end
                    end
                end

                ST_HASH_SEND: begin
                    if (sha_tready) begin
                        sha_tvalid <= 1'b1;
                        sha_tdata <= raw_mem[send_index];
                        sha_tlast <= (send_index == RAW_BYTES - 1);

                        if (send_index == RAW_BYTES - 1) begin
                            send_index <= 7'd0;
                            state <= ST_HASH_WAIT;
                        end else begin
                            send_index <= send_index + 1'b1;
                        end
                    end
                end

                ST_HASH_WAIT: begin
                    if (sha_ovalid) begin
                        for (i = 0; i < HASH_BYTES; i = i + 1) begin
                            hash_mem[i] <= sha_osha[255 - 8*i -: 8];
                        end
                        tx_index <= 8'd0;
                        state <= ST_TX_LOAD;
                    end
                end

                ST_TX_LOAD: begin
                    if (!uart_busy) begin
                        if (tx_index == 8'd0) begin
                            uart_data <= 8'hAA;
                        end else if (tx_index == 8'd1) begin
                            uart_data <= 8'h55;
                        end else if (tx_index == 8'd2) begin
                            uart_data <= 8'h00;
                        end else if (tx_index == 8'd3) begin
                            uart_data <= 8'd128;
                        end else if (tx_index < 8'd132) begin
                            uart_data <= raw_mem[tx_index - 8'd4];
                        end else begin
                            uart_data <= hash_mem[tx_index - 8'd132];
                        end

                        uart_en <= 1'b1;
                        state <= ST_TX_WAIT_BUSY;
                    end
                end

                ST_TX_WAIT_BUSY: begin
                    if (uart_busy) begin
                        state <= ST_TX_WAIT_DONE;
                    end
                end

                ST_TX_WAIT_DONE: begin
                    if (!uart_busy) begin
                        if (tx_index == FRAME_BYTES - 1) begin
                            tx_index <= 8'd0;
                            frame_count <= frame_count + 1'b1;
                            state <= ST_COLLECT;
                        end else begin
                            tx_index <= tx_index + 1'b1;
                            state <= ST_TX_LOAD;
                        end
                    end
                end

                default: begin
                    state <= ST_COLLECT;
                end
            endcase
        end
    end

    assign led[0] = frame_count[6];
    assign led[1] = (state != ST_COLLECT);

endmodule
