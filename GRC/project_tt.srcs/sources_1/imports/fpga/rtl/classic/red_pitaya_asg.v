/**
 * $Id: red_pitaya_asg.v 961 2014-01-21 11:40:39Z matej.oblak $
 *
 * @brief Red Pitaya arbitrary signal generator (ASG).
 *
 * @Author Matej Oblak
 *
 * (c) Red Pitaya  http://www.redpitaya.com
 *
 * This part of code is written in Verilog hardware description language (HDL).
 * Please visit http://en.wikipedia.org/wiki/Verilog
 * for more details on the language used herein.
 */

/**
 * GENERAL DESCRIPTION:
 *
 * Arbitrary signal generator takes data stored in buffer and sends them to DAC.
 *
 *
 *                /-----\         /--------\
 *   SW --------> | BUF | ------> | kx + o | ---> DAC CHA
 *                \-----/         \--------/
 *                   ^
 *                   |
 *                /-----\
 *   SW --------> |     |
 *                | FSM | ------> trigger notification
 *   trigger ---> |     |
 *                \-----/
 *                   |
 *                   ??
 *                /-----\         /--------\
 *   SW --------> | BUF | ------> | kx + o | ---> DAC CHB
 *                \-----/         \--------/ 
 *
 *
 * Buffers are filed with SW. It also sets finite state machine which take control
 * over read pointer. All registers regarding reading from buffer has additional 
 * 16 bits used as decimal points. In this way we can make better ratio betwen 
 * clock cycle and frequency of output signal. 
 *
 * Finite state machine can be set for one time sequence or continously wrapping.
 * Starting trigger can come from outside, notification trigger used to synchronize
 * with other applications (scope) is also available. Both channels are independant.
 *
 * Output data is scaled with linear transmormation.
 * 
 */

module red_pitaya_asg (
    //zero phase trig  input
  input                 dac_pos_edge_trig,
  output reg    [1:0]         integrator_ctrl,
  output DG418,
  input [13:0] adc_ch1_in,
  input [13:0] adc_ch2_in,
  // DAC
  output     [ 14-1: 0] dac_a_o   ,  // DAC data CHA
  output     [ 14-1: 0] dac_b_o   ,  // DAC data CHB
  input                 dac_clk_i ,  // DAC clock
  input                 dac_rstn_i,  // DAC reset - active low
  input                 trig_a_i  ,  // starting trigger CHA
  input                 trig_b_i  ,  // starting trigger CHB
  output                trig_out_o,  // notification trigger
  // System bus
  input      [ 32-1: 0] sys_addr  ,  // bus address
  input      [ 32-1: 0] sys_wdata ,  // bus write data
  input                 sys_wen   ,  // bus write enable
  input                 sys_ren   ,  // bus read enable
  output reg [ 32-1: 0] sys_rdata ,  // bus read data
  output reg            sys_err   ,  // bus error indicator
  output reg            sys_ack,      // bus acknowledge signal
  output integrator_measure_strobe
);

assign DG418 = ~integrator_ctrl[1];

//---------------------------------------------------------------------------------
//
// generating signal from DAC table 

localparam RSZ = 14 ;  // RAM size 2^RSZ
//localparam CYC1 = 1000;
//localparam CYC2 = 1000;
//localparam CYC3 = 1000;
//localparam CYC4 = 1000;
reg   [RSZ+15: 0] set_a_size   , set_b_size   ;
reg   [RSZ+15: 0] set_a_step   , set_b_step   ;
reg   [RSZ+15: 0] set_a_ofs    , set_b_ofs    ;
reg               set_a_rst    , set_b_rst    ;
reg               set_a_once   , set_b_once   ;
reg               set_a_wrap   , set_b_wrap   ;
reg   [  14-1: 0] set_a_amp    , set_b_amp   , set_a_amp_temp ;
reg   [  14-1: 0] set_a_dc     , set_b_dc     ;
reg               set_a_zero   , set_b_zero   ;
reg   [  16-1: 0] set_a_ncyc   , set_b_ncyc   ;
reg   [  16-1: 0] set_a_rnum   , set_b_rnum   ;
reg   [  32-1: 0] set_a_rdly   , set_b_rdly   ;
reg               set_a_rgate  , set_b_rgate  ;
reg               buf_a_we     , buf_b_we     ;
reg   [ RSZ-1: 0] buf_a_addr   , buf_b_addr   ;
wire  [  14-1: 0] buf_a_rdata  , buf_b_rdata  ;
wire  [ RSZ-1: 0] buf_a_rpnt   , buf_b_rpnt   ;
reg   [  32-1: 0] buf_a_rpnt_rd, buf_b_rpnt_rd;
reg               trig_a_sw    , trig_b_sw    ;
reg   [   3-1: 0] trig_a_src   , trig_b_src   ;
wire              trig_a_done  , trig_b_done  ;
//for MS1
integer i;
reg signed [31:0] adc_sum=32'd0, adc_sum_2=32'd0;
reg [13:0] adc_mem [16383:0],  adc_mem_2 [16383:0]; 
reg [13:0] adc_counter = 14'd0, adc_idx = 14'd0, adc_rd_data, adc_rd_data_2, test = 14'd0;

always @(posedge dac_clk_i)
begin
  adc_rd_data <= adc_mem[adc_idx]; 
  adc_rd_data_2 <= adc_mem_2[adc_idx];
end

initial begin
    for(i=0; i<16384; i=i+1) begin
        adc_mem[i] = 14'd0;
        adc_mem_2[i] = 14'd0;
    end
    integrator_ctrl = {1'b0, 1'b0};
end 

red_pitaya_asg_ch  #(.RSZ (RSZ)) ch0 (
  /* DAC */
  .dac_o           ({           dac_a_o          }),  // dac data output
  .dac_clk_i       ({         dac_clk_i        }),  // dac clock
  .dac_rstn_i      ({        dac_rstn_i       }),  // dac reset - active low
  /* trigger*/
  .trig_sw_i       ({         trig_a_sw        }),  // software trigger
  .trig_ext_i      ({          trig_a_i         }),  // external trigger
  .trig_src_i      ({        trig_a_src       }),  // trigger source selector
  .trig_done_o     ({       trig_a_done      }),  // trigger event
  /* buffer ctrl*/
  .buf_we_i        ({          buf_a_we         }),  // buffer buffer write
  .buf_addr_i      ({        buf_a_addr       }),  // buffer address
  .buf_wdata_i     ({ sys_wdata[14-1:0]}),  // buffer write data
  .buf_rdata_o     ({       buf_a_rdata      }),  // buffer read data
  .buf_rpnt_o      ({        buf_a_rpnt       }),  // buffer current read pointer
  /* configuration */
  .set_size_i      ({        set_a_size       }),  // set table data size
  .set_step_i      ({        set_a_step       }),  // set pointer step
  .set_ofs_i       ({         set_a_ofs        }),  // set reset offset
  .set_rst_i       ({         set_a_rst        }),  // set FMS to reset
  .set_once_i      ({        set_a_once       }),  // set only once
  .set_wrap_i      ({        set_a_wrap       }),  // set wrap pointer
  .set_amp_i       ({         set_a_amp        }),  // set amplitude scale
  .set_dc_i        ({          set_a_dc         }),  // set output offset
  .set_zero_i      ({        set_a_zero       }),  // set output to zero
  .set_ncyc_i      ({        set_a_ncyc       }),  // set number of cycle
  .set_rnum_i      ({        set_a_rnum       }),  // set number of repetitions
  .set_rdly_i      ({        set_a_rdly       }),  // set delay between repetitions
  .set_rgate_i     ({       set_a_rgate      })   // set external gated repetition
);

red_pitaya_asg_ch  #(.RSZ (RSZ+1)) ch1 (
  /* DAC */
  .dac_o           ({           dac_b_o          }),  // dac data output
  .dac_clk_i       ({         dac_clk_i        }),  // dac clock
  .dac_rstn_i      ({        dac_rstn_i       }),  // dac reset - active low
  /* trigger*/
  .trig_sw_i       ({         trig_b_sw        }),  // software trigger
  .trig_ext_i      ({          trig_b_i         }),  // external trigger
  .trig_src_i      ({        trig_b_src       }),  // trigger source selector
  .trig_done_o     ({       trig_b_done      }),  // trigger event
  /* buffer ctrl*/
  .buf_we_i        ({          buf_b_we         }),  // buffer buffer write
  .buf_addr_i      ({        buf_b_addr       }),  // buffer address
  .buf_wdata_i     ({ sys_wdata[14-1:0]}),  // buffer write data
  .buf_rdata_o     ({       buf_b_rdata      }),  // buffer read data
  .buf_rpnt_o      ({        buf_b_rpnt       }),  // buffer current read pointer
  /* configuration */
  .set_size_i      ({        set_b_size       }),  // set table data size
  .set_step_i      ({        set_b_step       }),  // set pointer step
  .set_ofs_i       ({         set_b_ofs        }),  // set reset offset
  .set_rst_i       ({         set_b_rst        }),  // set FMS to reset
  .set_once_i      ({        set_b_once       }),  // set only once
  .set_wrap_i      ({        set_b_wrap       }),  // set wrap pointer
  .set_amp_i       ({         set_b_amp        }),  // set amplitude scale
  .set_dc_i        ({          set_b_dc         }),  // set output offset
  .set_zero_i      ({        set_b_zero       }),  // set output to zero
  .set_ncyc_i      ({        set_b_ncyc       }),  // set number of cycle
  .set_rnum_i      ({        set_b_rnum       }),  // set number of repetitions
  .set_rdly_i      ({        set_b_rdly       }),  // set delay between repetitions
  .set_rgate_i     ({       set_b_rgate      })   // set external gated repetition
);

always @(posedge dac_clk_i)
begin
   buf_a_we   <= sys_wen && (sys_addr[19:RSZ+2] == 'h1);
   buf_b_we   <= sys_wen && ((sys_addr[19:RSZ+2] == 'h2) || (sys_addr[19:RSZ+2] == 'h3));
   buf_a_addr <= sys_addr[RSZ+1:2] ;  // address timing violation
   buf_b_addr <= sys_addr[RSZ+1:2] ;  // can change only synchronous to write clock
end

assign trig_out_o = trig_a_done ;

//---------------------------------------------------------------------------------
//
//  System bus connection
reg start_scan=1'b0, end_write=1'b0, end_read=1'b0;
reg [31:0]    cyc1, cyc2, cyc3;
reg signed [31:0] cyc4;
reg force_int = 1'b0;
reg  [3-1: 0] ren_dly ;
reg           ack_dly ;
reg [1:0] SM = 2'd0;
reg [2:0] SM2 = 2'd0;
reg [31:0] counter1, counter2, counter3, counter4;
reg [2:0] integrator_measure_reg;
wire integrator_measure_strobe;
reg [31:0] set_b_step_temp;

always @(posedge dac_clk_i)
if (dac_rstn_i == 1'b0) begin
   trig_a_sw   <=  1'b0    ;
   trig_a_src  <=  3'h0    ;
   set_a_amp   <= 14'h2000 ;
   set_a_amp_temp <= 14'h2000 ;

   set_a_dc    <= 14'h0    ;
   set_a_zero  <=  1'b0    ;
   set_a_rst   <=  1'b0    ;
   set_a_once  <=  1'b0    ;
   set_a_wrap  <=  1'b0    ;
   set_a_size  <= {RSZ+16{1'b1}} ;
   set_a_ofs   <= {RSZ+16{1'b0}} ;
   set_a_step  <={{RSZ+15{1'b0}},1'b0} ;
   set_a_ncyc  <= 16'h0    ;
   set_a_rnum  <= 16'h0    ;
   set_a_rdly  <= 32'h0    ;
   set_a_rgate <=  1'b0    ;
   trig_b_sw   <=  1'b0    ;
   trig_b_src  <=  3'h0    ;
   set_b_amp   <= 14'h2000 ;
   set_b_dc    <= 14'h0    ;
   set_b_zero  <=  1'b0    ;
   set_b_rst   <=  1'b0    ;
   set_b_once  <=  1'b0    ;
   set_b_wrap  <=  1'b0    ;
   set_b_size  <= {RSZ+16{1'b1}} ;
   set_b_ofs   <= {RSZ+16{1'b0}} ;
   set_b_step  <={{RSZ+15{1'b0}},1'b0} ;
   set_b_ncyc  <= 16'h0    ;
   set_b_rnum  <= 16'h0    ;
   set_b_rdly  <= 32'h0    ;
   set_b_rgate <=  1'b0    ;
   ren_dly     <=  3'h0    ;
   ack_dly     <=  1'b0    ;
   cyc1 <= 32'd500;
   cyc2 <= 32'd500;
   cyc3 <= 32'd500;
   cyc4 <= 32'd0;
   counter1 <= 32'd500;
   counter2 <= 32'd500;
   counter3 <= 32'd500;
   counter4 <= 32'd500;
   force_int <= 1'b0;
   SM <= 2'd0;
   SM2 <= 3'd0;
   integrator_measure_reg <= {3{1'b0}};
   set_b_step_temp <= 32'd0;
end else begin
   trig_a_sw  <= sys_wen && (sys_addr[19:0]==20'h0) && sys_wdata[0]  ;
   if (sys_wen && (sys_addr[19:0]==20'h0))
      trig_a_src <= sys_wdata[2:0] ;

   trig_b_sw  <= sys_wen && (sys_addr[19:0]==20'h0) && sys_wdata[16]  ;
   if (sys_wen && (sys_addr[19:0]==20'h0))
      trig_b_src <= sys_wdata[19:16] ;

   if (sys_wen) begin
      if (sys_addr[19:0]==20'h0)   {set_a_rgate, set_a_zero, set_a_rst, set_a_once, set_a_wrap} <= sys_wdata[ 8: 4] ;
      if (sys_addr[19:0]==20'h0)   {set_b_rgate, set_b_zero, set_b_rst, set_b_once, set_b_wrap} <= sys_wdata[24:20] ;
      
      if (sys_addr[19:0]==20'h4)   set_a_amp  <= sys_wdata[  0+13: 0] ;    
      if (sys_addr[19:0]==20'h4)   set_a_dc   <= sys_wdata[ 16+13:16] ;
      if (sys_addr[19:0]==20'h8)   set_a_size <= sys_wdata[RSZ+15: 0] ;
      if (sys_addr[19:0]==20'hC)   set_a_ofs  <= sys_wdata[RSZ+15: 0] ;
      if (sys_addr[19:0]==20'h10)  set_a_step <= sys_wdata[RSZ+15: 0] ;
      if (sys_addr[19:0]==20'h18)  set_a_ncyc <= sys_wdata[  16-1: 0] ;
      if (sys_addr[19:0]==20'h1C)  set_a_rnum <= sys_wdata[  16-1: 0] ;
      if (sys_addr[19:0]==20'h20)  set_a_rdly <= sys_wdata[  32-1: 0] ;

      if (sys_addr[19:0]==20'h24)  set_b_amp  <= sys_wdata[  0+13: 0] ;
      if (sys_addr[19:0]==20'h24)  set_b_dc   <= sys_wdata[ 16+13:16] ;
      if (sys_addr[19:0]==20'h28)  set_b_size <= sys_wdata[RSZ+15: 0] ;
      if (sys_addr[19:0]==20'h2C)  set_b_ofs  <= sys_wdata[RSZ+15: 0] ;
      if (sys_addr[19:0]==20'h30)  set_b_step_temp <= sys_wdata[RSZ+15: 0] ;
      if (sys_addr[19:0]==20'h38)  set_b_ncyc <= sys_wdata[  16-1: 0] ;
      if (sys_addr[19:0]==20'h3C)  set_b_rnum <= sys_wdata[  16-1: 0] ;
      if (sys_addr[19:0]==20'h40)  set_b_rdly <= sys_wdata[  32-1: 0] ;
      if (sys_addr[19:0]==20'h44)   start_scan  <= sys_wdata[0] ; // start trigger for scan amplitude
      if (sys_addr[19:0]==20'h48)  cyc1 <= sys_wdata[  32-1: 0] ;
      if (sys_addr[19:0]==20'h4C)  cyc2 <= sys_wdata[  32-1: 0] ;
      if (sys_addr[19:0]==20'h50)  cyc3 <= sys_wdata[  32-1: 0] ;
      if (sys_addr[19:0]==20'h54)  cyc4 <= sys_wdata[  32-1: 0] ; 
      if (sys_addr[19:0]==20'h58)  end_write <= sys_wdata[0] ; 
      if (sys_addr[19:0]==20'h5C)  end_read <= sys_wdata[0] ; 
      if (sys_addr[19:0]==20'h64)  adc_idx <= sys_wdata[13:0] ; 
      if (sys_addr[19:0]==20'h78)  force_int <= sys_wdata[0] ;
   end

    set_a_amp_temp <= set_a_amp;
	set_b_step <= set_b_step_temp + set_b_step_temp;
    
    case(SM2)
        3'd0 : //RST
            begin
                integrator_ctrl[0] <= 1'b1;
                integrator_ctrl[1] <= 1'b0;
                counter1 <= cyc1;
                counter2 <= cyc2;
                counter3 <= cyc3;
                counter4 <= cyc4;
//                integrator_measure_reg <= {3{1'b0}};
                if(start_scan==1'b1 && amp_change_strobe==1'b1)
                    SM2 <= 3'd1;
                else if(force_int == 1'b1)
                    SM2 <= 3'd1;
                else    
                    SM2 <= 3'd0;
                    
                if(end_read==1'b1) begin
                    adc_counter <= 14'd0;
                    end_read <= 1'b0;
                end
           end
        3'd1 : //rst
            begin
                counter1 <= counter1 - 1'b1;
                integrator_ctrl[0] <= 1'b1;
                integrator_ctrl[1] <= 1'b0;
                integrator_measure_reg <= {3{1'b0}};
                if(counter1 == 32'd0)
                    begin
                        SM2 <= 3'd2;
                    end
               else 
                    SM2 <= 3'd1;       
            end
        3'd2 : //hold
            begin
                counter2 <= counter2 - 1'b1;
                integrator_ctrl[0] <= 1'b1;
                integrator_ctrl[1] <= 1'b1;
                integrator_measure_reg <= {3{1'b0}};
                if(counter2 == 32'd0)
                    begin
                        SM2 <= 3'd3;
                        counter2 <= cyc2;
                    end
               else 
                    SM2 <= 3'd2;       
            end
        3'd3 : //int
            begin
                counter3 <= counter3 - 1'b1;
                integrator_ctrl[0] <= 1'b0;
                integrator_ctrl[1] <= 1'b1;
                integrator_measure_reg[0] <= 1'b1;
                integrator_measure_reg[1] <= 1'b0;
                integrator_measure_reg[2] <= 1'b0;
                if(counter3 == 32'd0)
                    begin
                        SM2 <= 3'd4;
                    end
               else 
                    SM2 <= 3'd3;       
            end
        3'd4 : //hold
            begin
//                counter4 <= counter4 - 1'b1;
                counter2 <= counter2 - 1'b1;
                integrator_ctrl[0] <= 1'b1;
                integrator_ctrl[1] <= 1'b1;
                if(counter2 < 32'd64) begin
                    adc_sum <= adc_sum + adc_ch1_in;
                    adc_sum_2 <= adc_sum_2 + adc_ch2_in; 
//                    adc_sum <= adc_sum + cyc4;
//                    adc_sum_2 <= adc_sum_2 + cyc4; 
                end
                if(counter2 == 32'd0) begin              
                    SM2 <= 3'd5;
                   adc_mem[adc_counter] <= adc_ch1_in; 
                   adc_mem_2[adc_counter] <= adc_ch2_in; 
                    // adc_mem[adc_counter] <= (adc_sum >>> 6); 
                    // adc_mem_2[adc_counter] <= (adc_sum_2 >>> 6); 
                end
               else 
                    SM2 <= 3'd4;            
//                adc_mem[adc_counter] <= test;
//                integrator_measure_reg <= {3{1'b0}};
//                if(counter4 == 32'd0)
//                    begin
//                        SM2 <= 3'd0;
//                    end
//               else 
//                    SM2 <= 3'd4;       
            end
        3'd5 : begin
            adc_sum <= 32'd0;
            adc_sum_2 <= 32'd0;
            adc_counter <= adc_counter + 1'b1;
            test <= test + 1'b1;
            SM2 <= 3'd0;
        end
        default:
            begin
                SM2 <= 3'd0;
                integrator_measure_reg <= {3{1'b0}};
            end
       endcase
                    
    
//    case(SM)
//        2'd0 :
//            begin
//                set_a_amp <= set_a_amp_temp_2;
//                if(amp_change_strobe) // per 30us
//                    begin
//                        SM <= 2'd1;
//                        amp_temp <= set_a_amp_temp;
//                    end
//               else 
//                    SM <= 2'd0;
//            end
//        2'd1 :
//            begin
//                set_a_amp <=  amp_temp;
//                if(dac_pos_edge_trig) // per period, <30us
//                    begin
//                        set_a_amp <=  set_a_amp_temp;
//                        SM <= 2'd0;
//                    end
//                else
//                    SM <= 2'd1;
//            end
//       2'd2 :
//        begin
//            set_a_amp <=  set_a_amp_temp;
//            if(!amp_change_strobe)  
//                begin              
//                    SM <= 2'd3;
//                    set_a_amp <=14'h2000;// set_a_amp_temp_3;
//                end
//            else
//                SM <= 2'd2;
//        end
//        2'd3 :
//            begin
            
//            end
//       default:
//        begin
//            SM <= 2'd0;
//        end
//    endcase
   if (sys_ren) begin
      buf_a_rpnt_rd <= {{32-RSZ-2{1'b0}},buf_a_rpnt,2'h0};
      buf_b_rpnt_rd <= {{32-RSZ-2{1'b0}},buf_b_rpnt,2'h0};
   end

   ren_dly <= {ren_dly[3-2:0], sys_ren};
   ack_dly <=  ren_dly[3-1] || sys_wen ;
end

//assign integrator_measure_strobe = integrator_measure_reg[0];// & ~integrator_measure_reg[2];
wire amp_change_strobe = (set_a_amp == set_a_amp_temp)? 1'b0 : 1'b1;
wire [32-1: 0] r0_rd = {7'h0,set_b_rgate, set_b_zero,set_b_rst,set_b_once,set_b_wrap, 1'b0,trig_b_src,
                        7'h0,set_a_rgate, set_a_zero,set_a_rst,set_a_once,set_a_wrap, 1'b0,trig_a_src };

wire sys_en;
assign sys_en = sys_wen | sys_ren;

always @(posedge dac_clk_i)
if (dac_rstn_i == 1'b0) begin
   sys_err <= 1'b0 ;
   sys_ack <= 1'b0 ;
end else begin
   sys_err <= 1'b0 ;

   casez (sys_addr[19:0])
     20'h00000 : begin sys_ack <= sys_en;          sys_rdata <= r0_rd                              ; end

     20'h00004 : begin sys_ack <= sys_en;          sys_rdata <= {2'h0, set_a_dc, 2'h0, set_a_amp}  ; end
     20'h00008 : begin sys_ack <= sys_en;          sys_rdata <= {{32-RSZ-16{1'b0}},set_a_size}     ; end
     20'h0000C : begin sys_ack <= sys_en;          sys_rdata <= {{32-RSZ-16{1'b0}},set_a_ofs}      ; end
     20'h00010 : begin sys_ack <= sys_en;          sys_rdata <= {{32-RSZ-16{1'b0}},set_a_step}     ; end
     20'h00014 : begin sys_ack <= sys_en;          sys_rdata <= buf_a_rpnt_rd                      ; end
     20'h00018 : begin sys_ack <= sys_en;          sys_rdata <= {{32-16{1'b0}},set_a_ncyc}         ; end
     20'h0001C : begin sys_ack <= sys_en;          sys_rdata <= {{32-16{1'b0}},set_a_rnum}         ; end
     20'h00020 : begin sys_ack <= sys_en;          sys_rdata <= set_a_rdly                         ; end

     20'h00024 : begin sys_ack <= sys_en;          sys_rdata <= {2'h0, set_b_dc, 2'h0, set_b_amp}  ; end
     20'h00028 : begin sys_ack <= sys_en;          sys_rdata <= {{32-RSZ-16{1'b0}},set_b_size}     ; end
     20'h0002C : begin sys_ack <= sys_en;          sys_rdata <= {{32-RSZ-16{1'b0}},set_b_ofs}      ; end
     20'h00030 : begin sys_ack <= sys_en;          sys_rdata <= {{32-RSZ-16{1'b0}},set_b_step}     ; end
     20'h00034 : begin sys_ack <= sys_en;          sys_rdata <= buf_b_rpnt_rd                      ; end
     20'h00038 : begin sys_ack <= sys_en;          sys_rdata <= {{32-16{1'b0}},set_b_ncyc}         ; end
     20'h0003C : begin sys_ack <= sys_en;          sys_rdata <= {{32-16{1'b0}},set_b_rnum}         ; end
     20'h00040 : begin sys_ack <= sys_en;          sys_rdata <= set_b_rdly                         ; end
     20'h00048 : begin sys_ack <= sys_en;          sys_rdata <= cyc1                               ; end
     20'h0004C : begin sys_ack <= sys_en;          sys_rdata <= cyc2                               ; end
     20'h00050 : begin sys_ack <= sys_en;          sys_rdata <= cyc3                               ; end
     20'h00054 : begin sys_ack <= sys_en;          sys_rdata <= cyc4                               ; end 
     20'h00058 : begin sys_ack <= sys_en;          sys_rdata <= end_write                           ; end   
     20'h0005C : begin sys_ack <= sys_en;          sys_rdata <= end_read                           ; end
     20'h00060 : begin sys_ack <= sys_en;          sys_rdata <= adc_counter                        ; end 
     20'h00064 : begin sys_ack <= sys_en;          sys_rdata <= adc_idx                            ; end 
     20'h00068 : begin sys_ack <= sys_en;          sys_rdata <= adc_rd_data                        ; end 
     20'h0006C : begin sys_ack <= sys_en;          sys_rdata <= adc_ch1_in                         ; end
     20'h00070 : begin sys_ack <= sys_en;          sys_rdata <= adc_rd_data_2                      ; end 
     20'h00074 : begin sys_ack <= sys_en;          sys_rdata <= adc_ch2_in                         ; end 
     20'h00078 : begin sys_ack <= sys_en;          sys_rdata <= force_int                         ; end
     20'h0007C : begin sys_ack <= sys_en;          sys_rdata <= adc_sum_2                         ; end

     20'h1zzzz : begin sys_ack <= ack_dly;         sys_rdata <= {{32-14{1'b0}},buf_a_rdata}        ; end
     20'h2zzzz : begin sys_ack <= ack_dly;         sys_rdata <= {{32-14{1'b0}},buf_b_rdata}        ; end 

       default : begin sys_ack <= sys_en;          sys_rdata <=  32'h0                             ; end
   endcase
end

endmodule
