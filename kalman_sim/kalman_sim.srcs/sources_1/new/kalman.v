`timescale 1ns / 1ps

module kalman(
//input CLK,
input rst_n,
input [14-1:0] adc_dat_i,
input [ 2-1:0] adc_clk_i,  // ADC clock {p,n}
output reg ladder_start_strobe,
output [ 2-1:0] adc_clk_o,  // optional ADC clock source (unused)
output adc_cdcs_o, // ADC clock duty cycle stabilizer
output reg [14-1:0] measure,
output reg diverder_clken, diverder2_clken,
output reg [14-1:0] x_apo_est, P_apo_est,
output reg [13:0] x_apo_est_r,
output [15-1:0] P_apri_est,
//output [16-1:0] out_adder_P_apri_est_R,
// output [48-1:0] K,
//output [31:0] Q, Q2, Q3,
output divider_valid, divider2_valid, divider3_valid,
// output [32-1:0] out_subtractor_1_K,
//output [46-1:0] out_multiplier_P_apo_est,
output [15-1:0] post_error
// output [47-1:0] out_multiplier_K_post_error,
// output [64-1:0] out_divider_K_post_error,
//output [31:0] out_adder_x_apri_est_divided_K_post_error,
// output [64-1:0] out_divider_P_apo_est,
    );
	
localparam mod_stat_H = 1'b1;
localparam mod_stat_L = 1'b0;
reg mod_stat = mod_stat_H;
reg [2:0] SM_diff = 3'd0;
reg [31:0] mod_cnt = 32'd0, reg_mod_freq_cnt = 32'd125, initial_cnt = 32'd30;

reg [9:0] x_apo_cnt = 10'd0;
wire [31:0] Q, Q2, Q3;
wire [64-1:0] out_divider_P_apo_est;
wire [64-1:0] out_divider_K_post_error;
wire [47-1:0] out_multiplier_K_post_error;
wire [48-1:0] K;
wire [32-1:0] out_subtractor_1_K;
wire [31:0] out_adder_x_apri_est_divided_K_post_error;
wire [46-1:0] out_multiplier_P_apo_est;
wire  [16-1:0] out_adder_P_apri_est_R;

// PLL signals
wire                 adc_clk_in;
wire                 pll_adc_clk;
wire                 pll_dac_clk_1x;
wire                 pll_dac_clk_2x;
wire                 pll_dac_clk_2p;
wire                 pll_ser_clk;
wire                 pll_pwm_clk;
wire                 pll_locked;

wire adc_clk;
wire dac_clk_1x;
wire dac_clk_2x;
wire dac_clk_2p;
wire ser_clk;
wire pwm_clk;

// ADC clock/reset
// wire                 adc_clk;
// wire                 adc_rstn;

// generating ADC clock is disabled
assign adc_clk_o = 2'b10;
// ADC clock duty cycle stabilizer is enabled
assign adc_cdcs_o = 1'b1 ;

reg [14-1:0] adc_dat_raw;

always @(posedge dac_clk_1x) //MOD
begin
    if(mod_cnt == 0)
    begin
        mod_cnt <= reg_mod_freq_cnt;
        if(mod_stat == mod_stat_L)
            mod_stat <= mod_stat_H;
        else if(mod_stat == mod_stat_H)
            mod_stat <= mod_stat_L;
    end
    else
        mod_cnt <= mod_cnt - 1'b1;
end

always @(posedge dac_clk_1x) //demodulation, MV
begin
	case (SM_diff)
		3'd0: begin
			if(mod_stat == mod_stat_H)
				SM_diff <= 3'd1;
			else 
				SM_diff <= 3'd0;
		end
		3'd1: begin
            if(initial_cnt != 32'd0) initial_cnt <= initial_cnt - 1'b1;
            else begin
                if(mod_stat == mod_stat_L) begin
                    SM_diff <= 3'd2;
                    initial_cnt <= 32'd30;
                end
                else 
                    SM_diff <= 3'd1;         
            end  
        end
		3'd2: begin
            if(initial_cnt != 32'd0) initial_cnt <= initial_cnt - 1'b1;
            else begin
				SM_diff <= 3'd3;
				initial_cnt <= 32'd30;
            end
        end
		3'd3: begin
            measure <= adc_dat_i;
            SM_diff <= 3'd4;
        end
		3'd4: begin
            ladder_start_strobe <= 1'b1;
            SM_diff <= 3'd5;
        end
		3'd5: begin
            ladder_start_strobe <= 1'b0;
            SM_diff <= 3'd0;
        end
	endcase
end

// diferential clock input
IBUFDS i_clk (.I (adc_clk_i[1]), .IB (adc_clk_i[0]), .O (adc_clk_in));  // differential clock input

red_pitaya_pll pll (
  // inputs
  .clk         (adc_clk_in),  // clock
  .rstn        (1'b1),  // reset - active low
  // output clocks
  .clk_adc     (pll_adc_clk   ),  // ADC clock
  .clk_dac_1x  (pll_dac_clk_1x),  // DAC clock 125MHz
  .clk_dac_2x  (pll_dac_clk_2x),  // DAC clock 250MHz
  .clk_dac_2p  (pll_dac_clk_2p),  // DAC clock 250MHz -45DGR
  .clk_ser     (pll_ser_clk   ),  // fast serial clock
  .clk_pdm     (pll_pwm_clk   ),  // PWM clock
  // status outputs
  .pll_locked  (pll_locked)
);



BUFG bufg_adc_clk    (.O (adc_clk   ), .I (pll_adc_clk   ));
BUFG bufg_dac_clk_1x (.O (dac_clk_1x), .I (pll_dac_clk_1x));
BUFG bufg_dac_clk_2x (.O (dac_clk_2x), .I (pll_dac_clk_2x));
BUFG bufg_dac_clk_2p (.O (dac_clk_2p), .I (pll_dac_clk_2p));
BUFG bufg_ser_clk    (.O (ser_clk   ), .I (pll_ser_clk   ));
BUFG bufg_pwm_clk    (.O (pwm_clk   ), .I (pll_pwm_clk   ));
always @(posedge adc_clk)
begin
  adc_dat_raw <= adc_dat_i[14-1:0];
end

// transform into 2's complement (negative slope)
wire [14-1:0] adc_dat = {adc_dat_raw[14-1], ~adc_dat_raw[14-2:0]};

//Kalman filter
initial begin
    diverder_clken = 1'b1;
    diverder2_clken = 1'b1;
end
//P_apo_est + Q
adder p_apo_est_shifted_Q ( 
  .A(P_apo_est),      // input wire [13 : 0] A
  .B(14'd819),      // input wire [13 : 0] B
  .CLK(pll_dac_clk_1x),  // input wire CLK
  .CE(1'b1),    // input wire CE
  .S(P_apri_est)      // output wire [14 : 0] S
);
//R + P_apri_est
adder2 P_apri_est_R ( 
  .A(P_apri_est),      // input wire [14 : 0] A
  .B(14'd8191),      // input wire [13 : 0] B
  .CLK(pll_dac_clk_1x),  // input wire CLK
  .CE(1'b1),    // input wire CE
  .S(out_adder_P_apri_est_R)      // output wire [15 : 0] S
);
//P_apri_est * 2^13/(R+P_apri_est)
divider P_apri_est_R_P_apri_est (
  .aclk(pll_dac_clk_1x),                                      // input wire aclk
  .aclken(diverder_clken),                                  // input wire aclken
  .s_axis_divisor_tvalid(1'b1),    // input wire s_axis_divisor_tvalid
  .s_axis_divisor_tdata(out_adder_P_apri_est_R),      // input wire [15 : 0] s_axis_divisor_tdata
  .s_axis_dividend_tvalid(1'b1),  // input wire s_axis_dividend_tvalid
  .s_axis_dividend_tdata(P_apri_est <<< 13),    // input wire [31 : 0] s_axis_dividend_tdata
  .m_axis_dout_tvalid(divider_valid),          // output wire m_axis_dout_tvalid
  .m_axis_dout_tdata(K)            // output wire [47 : 0] m_axis_dout_tdata
);
assign Q = K[47:16];
//1-K
subtractor _1_K (
  .A(32'd8191),      // input wire [31 : 0] A
  .B(K[47:16]),      // input wire [31 : 0] B
  .CLK(pll_dac_clk_1x),  // input wire CLK
  .CE(1'b1),    // input wire CE
  .S(out_subtractor_1_K)      // output wire [31 : 0] S
);
//P_apri_est * (1-K) 
 multipler P_apri_est_1_K (
  .CLK(pll_dac_clk_1x),  // input wire CLK
  .A(P_apri_est),      // input wire [14 : 0] A
  .B(out_subtractor_1_K),      // input wire [31 : 0] B
  .CE(1'b1),    // input wire CE
  .P(out_multiplier_P_apo_est)      // output wire [46 : 0] P
);
//Divide by 2^14
divider2 your_instance_name (
  .aclk(pll_dac_clk_1x),                                      // input wire aclk
  .aclken(diverder2_clken),
  .s_axis_divisor_tvalid(1'b1),    // input wire s_axis_divisor_tvalid
  .s_axis_divisor_tdata(32'd8192),      // input wire [31 : 0] s_axis_divisor_tdata
  .s_axis_dividend_tvalid(1'b1),  // input wire s_axis_dividend_tvalid
  .s_axis_dividend_tdata(out_multiplier_P_apo_est),    // input wire [31 : 0] s_axis_dividend_tdata
  .m_axis_dout_tvalid(divider2_valid),          // output wire m_axis_dout_tvalid
  .m_axis_dout_tdata(out_divider_P_apo_est)            // output wire [63 : 0] m_axis_dout_tdata
);
assign Q2 = out_divider_P_apo_est[63:32];
//z_measure - x_apri_est
subtractor2 z_measured_x_apri_est (
  .A(measure),      // input wire [13 : 0] A
  .B(x_apo_est),      // input wire [13 : 0] B
  .CLK(pll_dac_clk_1x),  // input wire CLK
  .CE(1'b1),    // input wire CE
  .S(post_error)      // output wire [14 : 0] S
);
//K * (z_measure-x_apri_est)
multiplier2 K_post_error (
  .CLK(pll_dac_clk_1x),  // input wire CLK
  .A(K[47:16]),      // input wire [31 : 0] A
  .B(post_error),      // input wire [14 : 0] B
  .CE(1'b1),    // input wire CE
  .P(out_multiplier_K_post_error)      // output wire [46 : 0] P
);
//K*(z_measure-x_apri_est) / 2^13
divider3 shifted_K_post_error (
  .aclk(pll_dac_clk_1x),                                      // input wire aclk
  .aclken(1'b1),                                  // input wire aclken
  .s_axis_divisor_tvalid(1'b1),    // input wire s_axis_divisor_tvalid
  .s_axis_divisor_tdata(32'd8192),      // input wire [31 : 0] s_axis_divisor_tdata
  .s_axis_dividend_tvalid(1'b1),  // input wire s_axis_dividend_tvalid
  .s_axis_dividend_tdata(out_multiplier_K_post_error),    // input wire [31 : 0] s_axis_dividend_tdata
  .m_axis_dout_tvalid(divider3_valid),          // output wire m_axis_dout_tvalid
  .m_axis_dout_tdata(out_divider_K_post_error)            // output wire [63 : 0] m_axis_dout_tdata
);
assign Q3 = out_divider_K_post_error[63:32];

//x_apri_est + K*(z_measure-x_apri_est)/2^13
adder3 x_apri_est_shifted_K_post_error (
  .A(x_apo_est),      // input wire [13 : 0] A
  .B(out_divider_K_post_error[63:32]),      // input wire [31 : 0] B
  .CLK(pll_dac_clk_1x),  // input wire CLK
  .CE(1'b1),    // input wire CE
  .S(out_adder_x_apri_est_divided_K_post_error)      // output wire [31 : 0] S
);

always @ (negedge rst_n or posedge ladder_start_strobe)
begin
	// Reset whenever the reset signal goes low, regardless of the busy
	if (!rst_n)
	begin
		P_apo_est <= 14'd8191;		//covariance starting value set at 1
		x_apo_est <= 14'd0;			//estimate starting value set at 0
	end
	// If not resetting, update the register output on the busy's falling edge
	else
	begin
		P_apo_est <= out_divider_P_apo_est[45:32];
		x_apo_est <= out_adder_x_apri_est_divided_K_post_error[13:0];
	end
end


localparam delay_cnt = 10'd20;
always @(posedge pll_dac_clk_1x) // dac_clk_1x
begin
    // if(ladder_start_strobe) x_apo_cnt <= 10'd0;
    if(x_apo_cnt != delay_cnt) x_apo_cnt <= x_apo_cnt + 1'b1;
	else if(x_apo_cnt == delay_cnt && ladder_start_strobe) begin
		x_apo_cnt <= 10'd0;
	end
    else begin
        x_apo_cnt <= x_apo_cnt;
        x_apo_est_r <= x_apo_est;
    end
end
endmodule
