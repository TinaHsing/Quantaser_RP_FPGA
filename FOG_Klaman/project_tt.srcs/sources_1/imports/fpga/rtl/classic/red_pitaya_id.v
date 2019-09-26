/**
 * $Id: red_pitaya_id.v 961 2014-01-21 11:40:39Z matej.oblak $
 *
 * @brief Red Pitaya house keeping.
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
 * House keeping module takes care of system identification.
 *
 * This module takes care of system identification via DNA readout at startup and
 * ID register which user can define at compile time.
 */

module red_pitaya_id #(
  parameter DWL = 8, // data width for LED
  parameter DWE = 8, // data width for extension
  parameter [57-1:0] DNA = 57'h0823456789ABCDE
)(
  // system signals
  input                clk_i      ,  // clock
  input                rstn_i     ,  // reset - active low
  // global configuration
  output reg           digital_loop,
  // System bus
  input      [ 32-1:0] sys_addr   ,  // bus address
  input      [ 32-1:0] sys_wdata  ,  // bus write data
  input                sys_wen    ,  // bus write enable
  input                sys_ren    ,  // bus read enable
  output reg [ 32-1:0] sys_rdata  ,  // bus read data
  output reg           sys_err    ,  // bus error indicator
  output reg           sys_ack       // bus acknowledge signal
  , output reg  [31:0] reg_mod_H
  , output reg [31:0] reg_mod_L
  , output reg [31:0] reg_mod_freq_cnt
  , output reg [31:0] Init_stable_cnt
  , output reg [16:0] reg_err_gain
  , output reg [13:0] reg_vth
  , output reg [13:0] reg_vth_1st_int
  , output reg [14:0] Diff_vth
  , output reg err_polarity
  , output reg mod_off
  , output reg [31:0] ADC_reg_H_offset
  , output reg [2:0] mv_mode
  , output reg [31:0] test_add
  , output reg ladder_rst
  , output reg [4:0] err_shift_idx 
  , output reg [4:0] err_shift_idx_pre
  , input [31:0] dac_ladder
  , input [31:0] dac_ladder_pre 
  , input [31:0] dac_ladder_pre_vth
  , input [13:0] ADC_reg_H
  , input [13:0] ADC_reg_L
  , input [14:0] ADC_reg_Diff
  , input [31:0] err_signal 
  , input [31:0] ADC_reg_H_sum
  , input [6:0] deMOD_mv_cnt 
  , input [31:0] test
  , input [19:0] err_signal_shift
  , input [31:0] step_MV_sum
  , input [14:0] ADC_reg_Diff_MV
  , input [31:0] step_MV_sum_out
  , input [31:0] err_signal_pre
);

//---------------------------------------------------------------------------------
//
//  Read device DNA

wire           dna_dout ;
reg            dna_clk  ;
reg            dna_read ;
reg            dna_shift;
reg  [ 9-1: 0] dna_cnt  ;
reg  [57-1: 0] dna_value;
reg            dna_done ;

always @(posedge clk_i)
if (rstn_i == 1'b0) begin
  dna_clk   <=  1'b0;
  dna_read  <=  1'b0;
  dna_shift <=  1'b0;
  dna_cnt   <=  9'd0;
  dna_value <= 57'd0;
  dna_done  <=  1'b0;
end else begin
  if (!dna_done)
    dna_cnt <= dna_cnt + 1'd1;

  dna_clk <= dna_cnt[2] ;
  dna_read  <= (dna_cnt < 9'd10);
  dna_shift <= (dna_cnt > 9'd18);

  if ((dna_cnt[2:0]==3'h0) && !dna_done)
    dna_value <= {dna_value[57-2:0], dna_dout};

  if (dna_cnt > 9'd465)
    dna_done <= 1'b1;
end

// parameter specifies a sample 57-bit DNA value for simulation
DNA_PORT #(.SIM_DNA_VALUE (DNA)) i_DNA (
  .DOUT  ( dna_dout   ), // 1-bit output: DNA output data.
  .CLK   ( dna_clk    ), // 1-bit input: Clock input.
  .DIN   ( 1'b0       ), // 1-bit input: User data input pin.
  .READ  ( dna_read   ), // 1-bit input: Active high load DNA, active low read input.
  .SHIFT ( dna_shift  )  // 1-bit input: Active high shift enable input.
);

//---------------------------------------------------------------------------------
//
//  Desing identification

wire [32-1: 0] id_value;

assign id_value[31: 4] = 28'h0; // reserved
assign id_value[ 3: 0] =  4'h1; // board type   1 - release 1

//---------------------------------------------------------------------------------
//
//  System bus connection

always @(posedge clk_i)
if (rstn_i == 1'b0) begin
  digital_loop <= 1'b0;
  reg_mod_H <= 32'd0 | {1'b0, 13'd4890};
  reg_mod_L <= 32'd0 | {1'b0, 13'd3276};
  reg_mod_freq_cnt <= 32'd125; // 1KHz
  Init_stable_cnt <= 32'd30; //for 500KH
  reg_err_gain <= 17'd1;
  reg_vth <= 14'd4915; //8191 = 1V
  reg_vth_1st_int <= 14'd8191;
  Diff_vth <= 15'd0;
  err_polarity <= 1'b0;
  mod_off <= 0;
  ADC_reg_H_offset <= 32'd0;
  mv_mode <= 3'd7;
  test_add <= 32'd10;
  ladder_rst <= 1'b0;
  err_shift_idx <= 5'd0;
  err_shift_idx_pre <= 5'd0;
  
end else if (sys_wen) begin
  if (sys_addr[19:0]==20'h0c)   digital_loop <= sys_wdata[0];
  if (sys_addr[19:0]==20'h100) reg_mod_H <= sys_wdata[31:0];
  if (sys_addr[19:0]==20'h104) reg_mod_L <= sys_wdata[31:0]; 
  if (sys_addr[19:0]==20'h108) reg_mod_freq_cnt <= sys_wdata[31:0];
  if (sys_addr[19:0]==20'h110) reg_err_gain <= sys_wdata[31:0]; //0011_1111 & sys_wdata[31:0]
  if (sys_addr[19:0]==20'h114) reg_vth <= 32'h3fff & sys_wdata[31:0]; //0011_1111_1111_1111 & sys_wdata[31:0]
  if (sys_addr[19:0]==20'h11C) err_polarity <= 32'h1 & sys_wdata[31:0];
  if (sys_addr[19:0]==20'h120) mod_off <= 32'h1 & sys_wdata[31:0];
  if (sys_addr[19:0]==20'h138) Init_stable_cnt <= sys_wdata[31:0]; 
  if (sys_addr[19:0]==20'h13C) ADC_reg_H_offset <= sys_wdata[31:0];
  if (sys_addr[19:0]==20'h140) mv_mode <= sys_wdata[31:0]; 
  if (sys_addr[19:0]==20'h144) test_add <= sys_wdata[31:0];
  if (sys_addr[19:0]==20'h14C) ladder_rst <= sys_wdata[31:0]; 
  if (sys_addr[19:0]==20'h150) err_shift_idx <= sys_wdata[31:0]; 
  if (sys_addr[19:0]==20'h160) Diff_vth <= sys_wdata[31:0];
  if (sys_addr[19:0]==20'h168) reg_vth_1st_int <= 32'h3fff & sys_wdata[31:0]; //0011_1111_1111_1111 & sys_wdata[31:0]
  if (sys_addr[19:0]==20'h170) err_shift_idx_pre <= sys_wdata[31:0]; 
end

wire sys_en;
assign sys_en = sys_wen | sys_ren;

always @(posedge clk_i)
if (rstn_i == 1'b0) begin
  sys_err <= 1'b0;
  sys_ack <= 1'b0;
end else begin
  sys_err <= 1'b0;

  casez (sys_addr[19:0])
    20'h00000: begin sys_ack <= sys_en;  sys_rdata <= {                id_value          }; end
    20'h00004: begin sys_ack <= sys_en;  sys_rdata <= {                dna_value[32-1: 0]}; end
    20'h00008: begin sys_ack <= sys_en;  sys_rdata <= {{64- 57{1'b0}}, dna_value[57-1:32]}; end
    20'h0000c: begin sys_ack <= sys_en;  sys_rdata <= {{32-  1{1'b0}}, digital_loop      }; end
    20'h00100: begin sys_ack <= sys_en;  sys_rdata <= {reg_mod_H      }; end
    20'h00104: begin sys_ack <= sys_en;  sys_rdata <= {reg_mod_L      }; end
    20'h00108: begin sys_ack <= sys_en;  sys_rdata <= {reg_mod_freq_cnt      }; end
    20'h0010C: begin sys_ack <= sys_en;  sys_rdata <= {deMOD_mv_cnt      }; end
    20'h00110: begin sys_ack <= sys_en;  sys_rdata <= {reg_err_gain      }; end
    20'h00114: begin sys_ack <= sys_en;  sys_rdata <= {reg_vth      }; end
    20'h00118: begin sys_ack <= sys_en;  sys_rdata <= {dac_ladder      }; end
    20'h0011C: begin sys_ack <= sys_en;  sys_rdata <= {err_polarity      }; end
    20'h00120: begin sys_ack <= sys_en;  sys_rdata <= {mod_off      }; end 
    20'h00124: begin sys_ack <= sys_en;  sys_rdata <= {ADC_reg_H      }; end
    20'h00128: begin sys_ack <= sys_en;  sys_rdata <= {ADC_reg_L      }; end
    20'h0012c: begin sys_ack <= sys_en;  sys_rdata <= {ADC_reg_Diff      }; end 
    20'h00130: begin sys_ack <= sys_en;  sys_rdata <= {err_signal      }; end 
    20'h00134: begin sys_ack <= sys_en;  sys_rdata <= {ADC_reg_H_sum      }; end  
    20'h00138: begin sys_ack <= sys_en;  sys_rdata <= {Init_stable_cnt      }; end 
    20'h0013C: begin sys_ack <= sys_en;  sys_rdata <= {ADC_reg_H_offset      }; end 
    20'h00140: begin sys_ack <= sys_en;  sys_rdata <= {mv_mode      }; end 
    20'h00144: begin sys_ack <= sys_en;  sys_rdata <= {test_add      }; end
    20'h00148: begin sys_ack <= sys_en;  sys_rdata <= {test      }; end 
    20'h0014C: begin sys_ack <= sys_en;  sys_rdata <= {ladder_rst      }; end 
    20'h00150: begin sys_ack <= sys_en;  sys_rdata <= {err_shift_idx      }; end 
    20'h00154: begin sys_ack <= sys_en;  sys_rdata <= {err_signal_shift      };  end
    20'h00158: begin sys_ack <= sys_en;  sys_rdata <= {step_MV_sum      }; end
    20'h0015C: begin sys_ack <= sys_en;  sys_rdata <= {ADC_reg_Diff_MV      }; end 
    20'h00160: begin sys_ack <= sys_en;  sys_rdata <= {Diff_vth      }; end 
    20'h00164: begin sys_ack <= sys_en;  sys_rdata <= {step_MV_sum_out      }; end
    20'h00168: begin sys_ack <= sys_en;  sys_rdata <= {reg_vth_1st_int      }; end
    20'h0016C: begin sys_ack <= sys_en;  sys_rdata <= {dac_ladder_pre      }; end
    20'h00170: begin sys_ack <= sys_en;  sys_rdata <= {err_shift_idx_pre      }; end 
    20'h00174: begin sys_ack <= sys_en;  sys_rdata <= {err_signal_pre      }; end 
    20'h00178: begin sys_ack <= sys_en;  sys_rdata <= {dac_ladder_pre_vth      }; end
      default: begin sys_ack <= sys_en;  sys_rdata <=  32'h0   ; end 
  endcase
end

endmodule
