`timescale 1ns / 1ps
module kalman_tb;
reg [ 2-1:0] adc_clk_i;
reg rst_n;
reg [14-1:0] adc_dat_i;
wire [13:0] measure;
wire ladder_start_strobe;
wire [14-1:0] x_apo_est;
wire [13:0] x_apo_est_r;
wire [15-1:0] post_error;
// wire [46-1:0] out_multiplier_K_post_error;
// wire [64-1:0] out_divider_K_post_error;
// wire [31:0] Q3;

wire [14-1:0] P_apo_est;
wire [15-1:0] P_apri_est;
// wire [16-1:0] out_adder_P_apri_est_R;
// wire [48-1:0] K;
// wire [31:0] Q;
wire diverder_clken;
wire divider_valid;
// wire [32-1:0] out_subtractor_1_K;
// wire [46-1:0] out_multiplier_P_apo_est;



// wire [31:0] out_adder_x_apri_est_divided_K_post_error;
// wire [64-1:0] out_divider_P_apo_est;
// wire [31:0] Q2;
wire diverder2_clken;
wire divider2_valid;

kalman k(
.rst_n(rst_n), 
.adc_dat_i(adc_dat_i),
.adc_clk_i(adc_clk_i),
.ladder_start_strobe(ladder_start_strobe),
.measure(measure),
.diverder_clken(diverder_clken),
.diverder2_clken(diverder2_clken),

.x_apo_est_r(x_apo_est_r),
.x_apo_est(x_apo_est), 
.P_apo_est(P_apo_est),
.P_apri_est(P_apri_est),
// .out_adder_P_apri_est_R(out_adder_P_apri_est_R),
// .K(K),
// .Q(Q),
.divider_valid(divider_valid),
// .out_subtractor_1_K(out_subtractor_1_K),
// .out_multiplier_P_apo_est(out_multiplier_P_apo_est),
.post_error(post_error),
// .out_multiplier_K_post_error(out_multiplier_K_post_error),
// .out_divider_K_post_error(out_divider_K_post_error),
// .out_adder_x_apri_est_divided_K_post_error(out_adder_x_apri_est_divided_K_post_error),
// .out_divider_P_apo_est(out_divider_P_apo_est),
.divider2_valid(divider2_valid)
// .Q2(Q2),
// .Q3(Q3),


// .x_apo_cnt(x_apo_cnt)
);
initial begin
adc_dat_i = 14'd0;
adc_clk_i[0] = 1'b1;
adc_clk_i[1] = 1'b1;
rst_n = 1'b1;
#5
rst_n = 1'b0;
#5
rst_n = 1'b1;
#5
#2000
adc_dat_i = 14'd150;
#10
#2000
adc_dat_i = 14'd500;
#10
#2000
$stop;
end

always begin
    #4 adc_clk_i[1] = ~adc_clk_i[1];
    #4 adc_clk_i[0] = ~adc_clk_i[0];
end
endmodule
