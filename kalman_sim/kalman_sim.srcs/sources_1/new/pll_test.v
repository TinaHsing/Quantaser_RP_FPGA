`timescale 1ns / 1ps


module pll_test(

input [ 2-1:0] adc_clk_i,  // ADC clock {p,n}
output adc_clk_in,
output pll_adc_clk,
output pll_dac_clk_1x,
output pll_dac_clk_2x,
output pll_dac_clk_2p,
output pll_locked,
output dac_clk_1x,
output adc_clk 
    );
    
    
// PLL signals
//    wire                 adc_clk_in;
//    wire                 pll_adc_clk;
//    wire                 pll_dac_clk_1x;
//    wire                 pll_dac_clk_2x;
//    wire                 pll_dac_clk_2p;
    wire                 pll_ser_clk;
    wire                 pll_pwm_clk;
//    wire                 pll_locked;
    
        
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

//wire adc_clk;
//wire dac_clk_1x;
wire dac_clk_2x;
wire dac_clk_2p;
wire ser_clk;
wire pwm_clk;

BUFG bufg_adc_clk    (.O (adc_clk   ), .I (pll_adc_clk   ));
BUFG bufg_dac_clk_1x (.O (dac_clk_1x), .I (pll_dac_clk_1x));
BUFG bufg_dac_clk_2x (.O (dac_clk_2x), .I (pll_dac_clk_2x));
BUFG bufg_dac_clk_2p (.O (dac_clk_2p), .I (pll_dac_clk_2p));
BUFG bufg_ser_clk    (.O (ser_clk   ), .I (pll_ser_clk   ));
BUFG bufg_pwm_clk    (.O (pwm_clk   ), .I (pll_pwm_clk   ));

endmodule
