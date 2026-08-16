`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/07/15 13:49:13
// Design Name: 
// Module Name: tb_twinkle
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


`timescale 1ns/1ps
module tb_breath_led;

    reg  sys_clk_p;
    wire  sys_clk_n;
    reg  sys_rst_n;
    wire [1:0] led;

    initial sys_clk_p = 0;
    always #5 sys_clk_p = ~sys_clk_p;
    assign sys_clk_n = ~sys_clk_p;

    initial begin
        sys_rst_n = 0;
        #100;
        sys_rst_n = 1;
    end

    initial begin
        #10_000_000;   // 10ms
        $finish;
    end

    breath_led uut (
        .sys_clk_p(sys_clk_p),
        .sys_clk_n(sys_clk_n),
        .sys_rst_n(sys_rst_n),
        .led(led)
    );

endmodule
