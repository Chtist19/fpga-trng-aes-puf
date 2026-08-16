`timescale 1ns / 1ps

module trng_key_provider (
    input          clk_i,
    input          rstn_i,
    input          enable_i,

    output         trng_valid_o,
    output [7:0]   trng_data_o,

    output reg         key_valid_o,
    input              key_ready_i,
    output reg [255:0] key_data_o,
    output reg [15:0]  key_index_o,
    output             busy_o
);

    localparam integer RAW_BYTES = 128;

    localparam [2:0] ST_COLLECT   = 3'd0,
                     ST_HASH_SEND = 3'd1,
                     ST_HASH_WAIT = 3'd2,
                     ST_KEY_HOLD  = 3'd3;

    wire       trng_valid;
    wire [7:0] trng_data;

    trng_core u_trng_core (
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .enable_i(enable_i),
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
        .rstn(rstn_i),
        .clk(clk_i),
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

    reg [2:0] state;
    reg [7:0] raw_mem [0:RAW_BYTES-1];
    reg [6:0] raw_count;
    reg [6:0] send_index;

    integer i;

    assign trng_valid_o = trng_valid;
    assign trng_data_o = trng_data;
    assign busy_o = (state != ST_COLLECT);

    always @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) begin
            state <= ST_COLLECT;
            raw_count <= 7'd0;
            send_index <= 7'd0;
            sha_tvalid <= 1'b0;
            sha_tlast <= 1'b0;
            sha_tdata <= 8'd0;
            key_valid_o <= 1'b0;
            key_data_o <= 256'd0;
            key_index_o <= 16'd0;

            for (i = 0; i < RAW_BYTES; i = i + 1) begin
                raw_mem[i] <= 8'd0;
            end
        end else begin
            sha_tvalid <= 1'b0;
            sha_tlast <= 1'b0;

            case (state)
                ST_COLLECT: begin
                    key_valid_o <= 1'b0;
                    if (enable_i && trng_valid) begin
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
                        key_data_o <= sha_osha;
                        key_valid_o <= 1'b1;
                        state <= ST_KEY_HOLD;
                    end
                end

                ST_KEY_HOLD: begin
                    if (key_ready_i) begin
                        key_valid_o <= 1'b0;
                        key_index_o <= key_index_o + 1'b1;
                        state <= ST_COLLECT;
                    end
                end

                default: begin
                    state <= ST_COLLECT;
                end
            endcase
        end
    end

endmodule
