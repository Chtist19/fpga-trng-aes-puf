`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/07/09 15:49:58
// Design Name: 
// Module Name: led_twinkle
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module breath_led (
    input  sys_clk_p,   // 差分时钟正端
    input  sys_clk_n,   // 差分时钟负端
    input  sys_rst_n,   // 复位（低有效）
    output [1:0] led    // 两个 LED，只用一个做呼吸
);

    // ---------- IBUFDS：差分转单端 ----------
    wire sys_clk;
    IBUFDS IBUFDS_inst (
        .O(sys_clk),
        .I(sys_clk_p),
        .IB(sys_clk_n)
    );

    // ---------- 1. PWM 周期计数器 ----------
    // 10位，0~1023，频率 ≈ 97.6kHz
    reg [9:0] pwm_cnt;
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n)
            pwm_cnt <= 10'd0;
        else
            pwm_cnt <= pwm_cnt + 1'b1;
    end

    // ---------- 2. 慢速计时器 ----------
    // 每 1ms 触发一次（100MHz 下数 100000 个时钟）
    reg [16:0] slow_cnt;
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n)
            slow_cnt <= 17'd0;
        else if (slow_cnt == 17'd99_999)
            slow_cnt <= 17'd0;
        else
            slow_cnt <= slow_cnt + 1'b1;
    end

    // ---------- 3. 占空比阈值和方向 ----------
    reg [9:0] threshold;
    reg dir;  // 0=渐亮，1=渐暗
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            threshold <= 10'd0;
            dir <= 1'b0;
        end else if (slow_cnt == 17'd99_999) begin
            if (!dir) begin
                if (threshold == 10'd1023)
                    dir <= 1'b1;
                else
                    threshold <= threshold + 1'b1;
            end else begin
                if (threshold == 10'd0)
                    dir <= 1'b0;
                else
                    threshold <= threshold - 1'b1;
            end
        end
    end

    // ---------- 4. PWM 输出 ----------
    // led[0] 做呼吸，led[1] 熄灭
    assign led[0] = (pwm_cnt < threshold) ? 1'b1 : 1'b0;
    assign led[1] = 1'b0;

endmodule
