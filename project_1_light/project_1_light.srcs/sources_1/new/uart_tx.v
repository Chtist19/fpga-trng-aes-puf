`timescale 1ns / 1ps

module uart_tx #(
    parameter integer CLK_FREQ = 100_000_000,
    parameter integer BAUD_RATE = 115_200
) (
    input        clk,
    input        rst_n,
    input  [7:0] tx_data,
    input        tx_en,
    output reg   txd,
    output reg   tx_busy
);

    localparam integer BAUD_CNT_MAX = CLK_FREQ / BAUD_RATE;

    reg [15:0] baud_cnt;
    reg [3:0]  bit_cnt;
    reg [9:0]  tx_shift;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            txd <= 1'b1;
            tx_busy <= 1'b0;
            baud_cnt <= 16'd0;
            bit_cnt <= 4'd0;
            tx_shift <= 10'h3ff;
        end else begin
            if (!tx_busy) begin
                txd <= 1'b1;
                baud_cnt <= 16'd0;
                bit_cnt <= 4'd0;

                if (tx_en) begin
                    tx_busy <= 1'b1;
                    tx_shift <= {1'b1, tx_data, 1'b0};
                    txd <= 1'b0;
                end
            end else begin
                if (baud_cnt == BAUD_CNT_MAX - 1) begin
                    baud_cnt <= 16'd0;
                    tx_shift <= {1'b1, tx_shift[9:1]};

                    if (bit_cnt == 4'd9) begin
                        tx_busy <= 1'b0;
                        bit_cnt <= 4'd0;
                        txd <= 1'b1;
                    end else begin
                        bit_cnt <= bit_cnt + 1'b1;
                        txd <= tx_shift[1];
                    end
                end else begin
                    baud_cnt <= baud_cnt + 1'b1;
                end
            end
        end
    end

endmodule
