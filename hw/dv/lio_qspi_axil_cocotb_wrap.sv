// Copyright AccurateRTL contributors.
// Licensed under the MIT License, see LICENSE for details.
// SPDX-License-Identifier: MIT

module lio_qspi_axil_cocotb_wrap #(
  parameter A_WIDTH = 32,
  parameter CFG_A_WIDTH = 32,
  // Width of data bus in bits
  parameter DATA_WIDTH = 32,
  // Width of address bus in bits
  parameter ADDR_WIDTH = 32,
  // Width of wstrb (width of data bus in words)
  parameter STRB_WIDTH = (DATA_WIDTH/8),
  // Timeout delay (cycles)  
  parameter NumCS   = 1
)
( 
  input                       aclk,
  input                       arstn,
  
  input        [A_WIDTH-1:0]  awaddr,
  input        [2:0]          awprot,
  input                       awvalid,
  output logic                awready,
  input        [32-1:0]       wdata,
  input        [32/8-1:0]     wstrb,
  input                       wvalid,
  output logic                wready,
  output logic [1:0]          bresp,
  output logic                bvalid,
  input                       bready,
  
  input [A_WIDTH-1:0]         araddr,
  input        [2:0]          arprot,
  input                       arvalid,
  output logic                arready,
  output logic [32-1:0]       rdata,
  output logic                rvalid,
  input                       rready,
  output logic [1:0]          rresp,
  
  
  input    [CFG_A_WIDTH-1:0]  cfg_awaddr,
  input        [2:0]          cfg_awprot,
  input                       cfg_awvalid,
  output logic                cfg_awready,
  input        [32-1:0]       cfg_wdata,
  input        [32/8-1:0]     cfg_wstrb,
  input                       cfg_wvalid,
  output logic                cfg_wready,
  output logic [1:0]          cfg_bresp,
  output logic                cfg_bvalid,
  input                       cfg_bready,
                    
  input [CFG_A_WIDTH-1:0]     cfg_araddr,
  input        [2:0]          cfg_arprot,
  input                       cfg_arvalid,
  output logic                cfg_arready,
  output logic [32-1:0]       cfg_rdata,
  output logic                cfg_rvalid,
  input                       cfg_rready,
  output logic [1:0]          cfg_rresp,
  
         
  output   sclk,
  output   cs,
  inout    io0,
  inout    io1,
  inout    io2,
  inout    io3
);

logic [3:0]                                   sd_o;
logic [3:0]                                   sd_en_o;
logic [3:0]                                   sd_i;


assign sd_i = {io3, io2, io1, io0};
assign io3 = (sd_en_o[3] ? sd_o[3] : io3);
assign io2 = (sd_en_o[2] ? sd_o[2] : io2);
assign io1 = (sd_en_o[1] ? sd_o[1] : io1);
assign io0 = (sd_en_o[0] ? sd_o[0] : io0);

lio_qspi_axil lio_qspi_axil_i(
  .aclk(aclk),                                          // in
  .arstn(arstn),                                        // in
  .awaddr(awaddr),                                      // in
  .awprot(awprot),                                      // in
  .awvalid(awvalid),                                    // in
  .awready(awready),                                    // out
  .wdata(wdata),                                        // in
  .wstrb(wstrb),                                        // in
  .wvalid(wvalid),                                      // in
  .wready(wready),                                      // out
  .bresp(bresp),                                        // out
  .bvalid(bvalid),                                      // out
  .bready(bready),                                      // in
  .araddr(araddr),                                      // in
  .arprot(arprot),                                      // in
  .arvalid(arvalid),                                    // in
  .arready(arready),                                    // out
  .rdata(rdata),                                        // out
  .rvalid(rvalid),                                      // out
  .rready(rready),                                      // in
  .rresp(rresp),                                        // out
  .cfg_awaddr(cfg_awaddr),                              // in
  .cfg_awprot(cfg_awprot),                              // in
  .cfg_awvalid(cfg_awvalid),                            // in
  .cfg_awready(cfg_awready),                            // out
  .cfg_wdata(cfg_wdata),                                // in
  .cfg_wstrb(cfg_wstrb),                                // in
  .cfg_wvalid(cfg_wvalid),                              // in
  .cfg_wready(cfg_wready),                              // out
  .cfg_bresp(cfg_bresp),                                // out
  .cfg_bvalid(cfg_bvalid),                              // out
  .cfg_bready(cfg_bready),                              // in
  .cfg_araddr(cfg_araddr),                              // in
  .cfg_arprot(cfg_arprot),                              // in
  .cfg_arvalid(cfg_arvalid),                            // in
  .cfg_arready(cfg_arready),                            // out
  .cfg_rdata(cfg_rdata),                                // out
  .cfg_rvalid(cfg_rvalid),                              // out
  .cfg_rready(cfg_rready),                              // in
  .cfg_rresp(cfg_rresp),                                // out
  .sck_o(sclk),                                        // out
  .csb_o(cs),                                        // out
  .sd_o(sd_o),                                          // out
  .sd_en_o(sd_en_o),                                    // out
  .sd_i(sd_i)                                           // in
);

endmodule
