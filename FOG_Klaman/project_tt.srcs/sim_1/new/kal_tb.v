`timescale 1ns / 1ps

module kal_tb;
reg CLK;
reg [13:0] measure;
reg rst_n;
reg ladder_start_strobe;
wire [31:0] Q, Q2, Q3;
wire [14-1:0] x_apo_est, P_apo_est; 


    red_pitaya_top(
    .clk(clk),
	.measure(measure),
    .adc_rstn(rst_n),
	.ladder_start_strobe(ladder_start_strobe),
	.Q(Q),
	.Q2(Q2),
	.Q3(Q3),
	.x_apo_est(x_apo_est),
	.P_apo_est(P_apo_est)	
    ); 
	
initial begin
measure = 14'd0;
CLK = 1'b1;
ladder_start_strobe = 1'b0;
rst_n = 1'b1;
#5
ladder_start_strobe = 1'b1;
rst_n = 1'b0;
#5
rst_n = 1'b1;
#5
ladder_start_strobe = 1'b0;
#2000
ladder_start_strobe = 1'b1;
measure = 14'd150;
#10
ladder_start_strobe = 1'b0;
#2000
ladder_start_strobe = 1'b1;
measure = 14'd500;
#10
ladder_start_strobe = 1'b0;
#2000
$stop;
end

always
    #4 CLK = ~CLK;
	
endmodule
