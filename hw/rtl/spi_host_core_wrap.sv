// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Core Implemenation module for Serial Peripheral Interface (SPI) Host IP.
//

module spi_host_core_wrap #(
  parameter  int NumCS     = 1
) (
  input                             clk_i,
  input                             rst_ni,

  input        command_csid,
  input [15:0] command_clkdiv,
  input [3:0]  command_csnidle,
  input [3:0]  command_csnlead,
  input [3:0]  command_csntrail,
  input        command_full_cyc,
  input        command_cpha,
  input        command_cpol,
  input [1:0]  command_speed,
  input        command_cmd_wr_en,
  input        command_cmd_rd_en,
  input [8:0]  command_len,
  input        command_csaat,

  input                             command_valid_i,
  output                            command_ready_o,
  input                             en_i,

  input        [31:0]               tx_data_i,
  input        [3:0]                tx_be_i,
  input                             tx_valid_i,
  output logic                      tx_ready_o,

  output logic [31:0]               rx_data_o,
  output logic                      rx_valid_o,
  input                             rx_ready_i,

  input                             sw_rst_i,

  // SPI Interface
  /*
  output logic                      sck_o,
  output logic [NumCS-1:0]          csb_o,
  output logic [3:0]                sd_o,
  output logic [3:0]                sd_en_o,
  input [3:0]                       sd_i,
  */
  output  sclk, 
  output  mosi,
  input   miso,
  output  cs,  // active-low
  
  // Status bits
  output logic                      rx_stall_o,
  output logic                      tx_stall_o,
  output logic                      active_o
);


logic               sck_o  ;
logic [NumCS-1:0]   csb_o  ;
logic [3:0]         sd_o   ;
logic [3:0]         sd_en_o;
logic [3:0]         sd_i   ;

spi_host_cmd_pkg::command_t command_i;

assign sclk = sck_o;
assign cs   = csb_o;
assign mosi = sd_o[0];

assign sd_i[0]   = 1'b0;
assign sd_i[1]   = miso;
assign sd_i[3:2] = 2'b00;

assign command_i.csid                =  command_csid        ;
assign command_i.configopts.clkdiv   =  command_clkdiv      ;
assign command_i.configopts.csnidle  =  command_csnidle     ;
assign command_i.configopts.csnlead  =  command_csnlead     ;
assign command_i.configopts.csntrail =  command_csntrail    ;
assign command_i.configopts.full_cyc =  command_full_cyc    ;
assign command_i.configopts.cpha     =  command_cpha        ;
assign command_i.configopts.cpol     =  command_cpol        ;
assign command_i.segment.speed       =  command_speed       ;
assign command_i.segment.cmd_wr_en   =  command_cmd_wr_en  ;
assign command_i.segment.cmd_rd_en   =  command_cmd_rd_en  ;
assign command_i.segment.len         =  command_len         ;
assign command_i.segment.csaat       =  command_csaat       ;


spi_host_core spi_host_core_i(.*);




endmodule : spi_host_core_wrap
