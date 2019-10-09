`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/10/09 16:26:39
// Design Name: 
// Module Name: pll_test_tb
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


module pll_test_tb;
reg [ 2-1:0] adc_clk_i;
wire adc_clk_in;
wire pll_adc_clk;
wire pll_dac_clk_1x;
wire pll_dac_clk_2x;
wire pll_dac_clk_2p;
wire pll_locked;
wire adc_clk;
wire dac_clk_1x;

pll_test p(
.adc_clk_i(adc_clk_i),
.adc_clk_in(adc_clk_in),
.pll_adc_clk(pll_adc_clk),
.pll_dac_clk_1x(pll_dac_clk_1x),
.pll_locked(pll_locked),
.pll_dac_clk_2x(pll_dac_clk_2x),
.pll_dac_clk_2p(pll_dac_clk_2p),
.adc_clk(adc_clk),
.dac_clk_1x(dac_clk_1x)
);

initial begin
    adc_clk_i[0] = 1'b1;
    adc_clk_i[1] = 1'b1;
    #1000
    $stop;
end

always begin
    #4 adc_clk_i[1] = ~adc_clk_i[1];
    #4 adc_clk_i[0] = ~adc_clk_i[0];
end
endmodule
