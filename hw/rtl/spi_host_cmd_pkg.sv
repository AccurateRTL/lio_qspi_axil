// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Command & Configuration Options structure for SPI HOST.
//

package spi_host_cmd_pkg;

  parameter int CSW = 1;
  parameter int CmdSize = CSW + 45;

  // For decoding the direction register
  typedef enum logic [1:0] {
     Dummy  = 2'b00,
     RdOnly = 2'b01,
     WrOnly = 2'b10,
     Bidir  = 2'b11
   } reg_direction_t;

  // For decoding the direction register
  typedef enum logic [1:0] {
     Standard = 2'b00,
     Dual     = 2'b01,
     Quad     = 2'b10,
     RsvdSpd  = 2'b11
   } speed_t;

  typedef struct packed {
    logic [15:0] clkdiv;
    logic [3:0]  csnidle;
    logic [3:0]  csnlead;
    logic [3:0]  csntrail;
    logic        full_cyc;
    logic        cpha;
    logic        cpol;
  } configopts_t;

  typedef struct packed {
    logic [1:0] speed;
    logic       cmd_wr_en;
    logic       cmd_rd_en;
    logic [8:0] len;
    logic       csaat;
  } segment_t;

  typedef struct packed {
    logic [CSW-1:0] csid;
    segment_t segment;
    configopts_t configopts;
  } command_t;

endpackage


// # REG0:Регистр состояния
// ## Access: RW
// ## Fields:
//   FLD1 | 0 | 2 | Выбор режима 
//   FLD2 | 4 | 2 | Выбор скорости
//   FLD3 | 6 | 8 | 
// ## Description
//   Регистр предназначен для задания настроек контроллера SPI 
//
// # REG1: 



//{ name: "MASKED_OE_UPPER",
//  desc: "GPIO write Output Enable upper with mask.",
//  swaccess: "rw",
//  fields: [
//        { name: "data", bits: "15:0", desc: "Данные для передачи"},
//        { name: "mask", bits: "31:16", desc: "Write OE mask[31:16]"},
//        ],
//},





