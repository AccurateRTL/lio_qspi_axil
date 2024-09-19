// Copyright AccurateRTL contributors.
// Licensed under the MIT License, see LICENSE for details.
// SPDX-License-Identifier: MIT

`define DBG_MARK (* MARK_DEBUG = "TRUE", DONT_TOUCH = "TRUE" *)

module lio_qspi_axil #(
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
  `DBG_MARK input                       awvalid,
  `DBG_MARK output logic                awready,
            input        [32-1:0]       wdata,
  `DBG_MARK input        [32/8-1:0]     wstrb,
  `DBG_MARK input                       wvalid,
  `DBG_MARK output logic                wready,
            output logic [1:0]          bresp,
  `DBG_MARK output logic                bvalid,
  `DBG_MARK input                       bready,
  
            input [A_WIDTH-1:0]         araddr,
            input        [2:0]          arprot,
  `DBG_MARK input                       arvalid,
  `DBG_MARK output logic                arready,
            output logic [32-1:0]       rdata,
  `DBG_MARK output logic                rvalid,
  `DBG_MARK input                       rready,
            output logic [1:0]          rresp,
  
  
            input    [CFG_A_WIDTH-1:0]  cfg_awaddr,
            input        [2:0]          cfg_awprot,
  `DBG_MARK input                       cfg_awvalid,
  `DBG_MARK output logic                cfg_awready,
            input        [32-1:0]       cfg_wdata,
  `DBG_MARK input        [32/8-1:0]     cfg_wstrb,
  `DBG_MARK input                       cfg_wvalid,
  `DBG_MARK output logic                cfg_wready,
            output logic [1:0]          cfg_bresp,
  `DBG_MARK output logic                cfg_bvalid,
  `DBG_MARK input                       cfg_bready,
                              
            input [CFG_A_WIDTH-1:0]     cfg_araddr,
            input        [2:0]          cfg_arprot,
 `DBG_MARK  input                       cfg_arvalid,
 `DBG_MARK  output logic                cfg_arready,
            output logic [32-1:0]       cfg_rdata,
 `DBG_MARK  output logic                cfg_rvalid,
 `DBG_MARK  input                       cfg_rready,
            output logic [1:0]          cfg_rresp,
  
  
 `DBG_MARK  output logic                sck_o,
 `DBG_MARK  output logic [NumCS-1:0]    csb_o,
 `DBG_MARK  output logic [3:0]          sd_o,
 `DBG_MARK  output logic [3:0]          sd_en_o,
 `DBG_MARK  input        [3:0]          sd_i
);

`DBG_MARK logic         command_valid_i;
`DBG_MARK logic         command_ready_o;
logic         en_i;
logic [31:0]  tx_data_i;
logic [3:0]   tx_be_i;
`DBG_MARK logic         tx_valid_i;
`DBG_MARK logic         tx_ready_o;
logic [31:0]  rx_data_o;
`DBG_MARK logic         rx_valid_o;
`DBG_MARK logic         rx_ready_i;
logic         sw_rst_i;
logic         rx_stall_o;
logic         tx_stall_o;
logic         active_o;
logic         clk_i;
logic         rst_ni;
logic         rst_n;

logic [1:0]   segm_speed;
logic         segm_cmd_wr_en;
logic         segm_cmd_rd_en;
logic [8:0]   segm_len;
logic         segm_csaat;

logic [1:0]   sw_cmd_speed;
logic         sw_cmd_cmd_wr_en;
logic         sw_cmd_cmd_rd_en;
logic [8:0]   sw_cmd_len;
logic         sw_cmd_csaat;


logic [1:0]   cfg_speed;
logic [7:0]   cfg_write_cmd;
logic [7:0]   cfg_read_cmd;
logic [31:0]  cfg_addr_mask;
logic [15:0]  cfg_clkdiv;
logic [3:0]   cfg_csnidle;
logic [3:0]   cfg_csnlead;
logic [3:0]   cfg_csntrail;
logic         cfg_full_cyc;
logic         cfg_cpha;
logic         cfg_cpol;
logic         cfg_sw_read;
logic [3:0]   cfg_pause_len;
logic         cfg_4b_address;

logic         send_sw_cmd;
logic tx_valid_sw;
logic [CFG_A_WIDTH-1:0]  reg_wr_addr;
logic [DATA_WIDTH-1:0]   reg_wr_data;
logic [STRB_WIDTH-1:0]   reg_wr_strb;
logic                    reg_wr_en;
logic                    reg_wr_wait;
logic                    reg_wr_ack;
logic [CFG_A_WIDTH-1:0]  reg_rd_addr;
logic                    reg_rd_en;
logic [DATA_WIDTH-1:0]   reg_rd_data;
logic                    reg_rd_wait;
logic                    reg_rd_ack;
logic [31:0]             sw_rd_data;
logic bvalid_d;

logic [31:0]  addr;
logic [31:0]  addr_inv_bo;
logic [23:0]  addr_3b_inv_bo;
logic rst;
`DBG_MARK logic addr_valid;
`DBG_MARK logic [31:0] next_addr;
logic [31:0] masked_addr;
`DBG_MARK logic rd_addr_match;
`DBG_MARK logic wr_addr_match;
logic cur_cmd_is_read;
logic [15:0] cs_counter;
logic [15:0] cfg_cs_counter_max;
logic [31:0] cfg_boundary;
logic [31:0] cfg_boundary_mask;
`DBG_MARK logic cs_timeout;
`DBG_MARK logic boundary_cross;


typedef enum {
    IDLE,
    SENDING_WRITE_CMD,
    WRITING_WR_ADDR_TO_TXFIFO,
    SENDING_WR_ADDR,
    WRITING_DATA_TO_TXFIFO,
    SENDING_WRITE_DATA,
    SENDING_READ_CMD,
    WRITING_RD_ADDR_TO_TXFIFO,
    SENDING_RD_ADDR,
    SENDING_PAUSE_CMD,
    SENDING_READ_DATA_CMD,
    SKIPING_DUMMY_RD_DATA,
    WAITING_READ_DATA,
    SENDING_CUSTOM_CMD,
    SENDING_READ_NEXT_DATA_CMD,
    DESELECTING_BEFORE_RD,
    DESELECTING_BEFORE_WR,
    DESELECTING_AFTER_TIMEOUT
} sm_states;

`DBG_MARK sm_states stt;


assign clk_i  = aclk;
assign rst_ni = arstn;
assign rst    = ~arstn;

assign en_i       = 1'b1;
assign sw_rst_i   = 1'b0;

spi_host_cmd_pkg::command_t command_i;

assign command_i.csid                =  '0;
assign command_i.configopts.clkdiv   =  cfg_clkdiv  ;
assign command_i.configopts.csnidle  =  cfg_csnidle ;
assign command_i.configopts.csnlead  =  cfg_csnlead ;
assign command_i.configopts.csntrail =  cfg_csntrail;
assign command_i.configopts.full_cyc =  cfg_full_cyc;
assign command_i.configopts.cpha     =  cfg_cpha    ;
assign command_i.configopts.cpol     =  cfg_cpol    ;

assign command_i.segment.speed       =  segm_speed;
assign command_i.segment.cmd_wr_en   =  segm_cmd_wr_en;
assign command_i.segment.cmd_rd_en   =  segm_cmd_rd_en;
assign command_i.segment.len         =  segm_len      ;
assign command_i.segment.csaat       =  segm_csaat    ;


spi_host_core spi_host_core_i(.*);

assign masked_addr  = addr & cfg_addr_mask;

assign addr_inv_bo[31:24]    = masked_addr[7:0];
assign addr_inv_bo[23:16]    = masked_addr[15:8];
assign addr_inv_bo[15:8]     = masked_addr[23:16];
assign addr_inv_bo[7:0]      = masked_addr[31:24];

assign addr_3b_inv_bo[23:16] = masked_addr[7:0];
assign addr_3b_inv_bo[15:8]  = masked_addr[15:8];
assign addr_3b_inv_bo[7:0]   = masked_addr[23:16];

always_comb begin
  case (stt)
    IDLE: begin
      segm_speed       =  '0;
      segm_cmd_wr_en   =  '0;
      segm_cmd_rd_en   =  '0;
      segm_len         =  '0;
      segm_csaat       =  '0;
      command_valid_i  = 1'b0;
    end
    
    SENDING_CUSTOM_CMD: begin
      segm_speed       =  sw_cmd_speed;
      segm_cmd_wr_en   =  sw_cmd_cmd_wr_en;
      segm_cmd_rd_en   =  sw_cmd_cmd_rd_en;
      segm_len         =  sw_cmd_len;
      segm_csaat       =  sw_cmd_csaat;
      command_valid_i  =  1'b1;
    end

    SENDING_WRITE_CMD: begin
      segm_speed       =  cfg_speed;
      segm_cmd_wr_en   =  1'b1;
      segm_cmd_rd_en   =  '0;
      segm_len         =  0;
      segm_csaat       =  1'b1;
      command_valid_i  =  1'b1;
    end
    
    SENDING_WR_ADDR: begin
      segm_speed       =  cfg_speed;
      segm_cmd_wr_en   =  1'b1;
      segm_cmd_rd_en   =  '0;
      segm_len         =  (cfg_4b_address ? 3 : 2);
      segm_csaat       =  1'b1;
      command_valid_i  =  1'b1;
    end

    SENDING_WRITE_DATA: begin
      segm_speed       =  cfg_speed;
      segm_cmd_wr_en   =  1'b1;
      segm_cmd_rd_en   =  '0;
      segm_len         =  3;
      segm_csaat       =  1'b1;
      command_valid_i  =  1'b1;
    end
    
    SENDING_READ_CMD: begin
      segm_speed       =  cfg_speed;
      segm_cmd_wr_en   =  1'b1;
      segm_cmd_rd_en   =  '0;
      segm_len         =  0;
      segm_csaat       =  1'b1;
      command_valid_i  =  1'b1;
    end
    
    SENDING_RD_ADDR: begin
      segm_speed       =  cfg_speed;
      segm_cmd_wr_en   =  1'b1;
      segm_cmd_rd_en   =  '0;
      segm_len         =  (cfg_4b_address ? 3 : 2);
      segm_csaat       =  1'b1;
      command_valid_i  =  1'b1;
    end
    
    SENDING_PAUSE_CMD: begin
      segm_speed       =  cfg_speed;
      segm_cmd_wr_en   =  1'b0;
      segm_cmd_rd_en   =  1'b1;
      segm_len         =  cfg_pause_len;
      segm_csaat       =  1'b1;
      command_valid_i  =  1'b1;
    end
    
    SENDING_READ_DATA_CMD: begin
      segm_speed       =  cfg_speed;
      segm_cmd_wr_en   =  1'b0;
      segm_cmd_rd_en   =  1'b1;
      segm_len         =  3;
      segm_csaat       =  1'b1;
      command_valid_i  =  1'b1;
    end
    
    DESELECTING_BEFORE_RD: begin
      segm_speed       =  cfg_speed;
      segm_cmd_wr_en   =  1'b0;
      segm_cmd_rd_en   =  1'b0;
      segm_len         =  0;
      segm_csaat       =  1'b0;
      command_valid_i  =  1'b1;
    end
    
    DESELECTING_BEFORE_WR: begin
      segm_speed       =  cfg_speed;
      segm_cmd_wr_en   =  1'b0;
      segm_cmd_rd_en   =  1'b0;
      segm_len         =  0;
      segm_csaat       =  1'b0;
      command_valid_i  =  1'b1;
    end
    
    DESELECTING_AFTER_TIMEOUT: begin
      segm_speed       =  cfg_speed;
      segm_cmd_wr_en   =  1'b0;
      segm_cmd_rd_en   =  1'b0;
      segm_len         =  0;
      segm_csaat       =  1'b0;
      command_valid_i  =  1'b1;
    end
    
    SENDING_READ_NEXT_DATA_CMD: begin
      segm_speed       =  cfg_speed;
      segm_cmd_wr_en   =  1'b0;
      segm_cmd_rd_en   =  1'b1;
      segm_len         =  3;
      segm_csaat       =  1'b1;
      command_valid_i  =  1'b1;
    end
    
    default: begin
      segm_speed       =  '0;
      segm_cmd_wr_en   =  '0;
      segm_cmd_rd_en   =  '0;
      segm_len         =  '0;
      segm_csaat       =  '0;
      command_valid_i  = 1'b0;
    end
    
  endcase
end 

assign wready = (stt==WRITING_DATA_TO_TXFIFO ? tx_ready_o : 1'b0);

assign bresp  = '0;

always_ff @(posedge aclk or negedge arstn) begin
  if (!arstn) begin
    bvalid_d <= 1'b0;
  end
  else 
    if (wready & wvalid & (~bready))
      bvalid_d <= 1'b1;  
    else 
      if (bvalid_d & bready)
        bvalid_d <= 1'b0;  
end
  
assign bvalid = wready | bvalid_d;

assign rresp  = '0;
assign rvalid = (stt==WAITING_READ_DATA ? rx_valid_o : 1'b0);
assign rdata  = rx_data_o;

assign boundary_cross = ((next_addr & cfg_boundary_mask) == cfg_boundary);
assign rd_addr_match  = ((araddr[31:2] == next_addr[31:2]) & (~boundary_cross) ? addr_valid & cur_cmd_is_read    : 1'b0);
assign wr_addr_match  = ((awaddr[31:2] == next_addr[31:2]) & (~boundary_cross) ? addr_valid & (~cur_cmd_is_read) : 1'b0);

always_comb begin
  if (tx_valid_sw) begin
    tx_data_i     = reg_wr_data;
    tx_be_i       = reg_wr_strb;
    tx_valid_i    = 1'b1;
  end 
  else
    case (stt)
      IDLE: begin
        if (!cs_timeout) begin
          if (awvalid & (~wr_addr_match)) begin
            tx_data_i        = cfg_write_cmd;
            tx_be_i          = 4'b0001;
            tx_valid_i       = 1'b1;
          end
          else
            if (arvalid & (~rd_addr_match)) begin
              tx_data_i        = cfg_read_cmd;
              tx_be_i          = 4'b0001;
              tx_valid_i       = 1'b1;
            end 
            else begin
              tx_data_i       = '0;
              tx_be_i         = '0;
              tx_valid_i      = 1'b0;
            end
        end
        else begin
          tx_data_i       = '0;
          tx_be_i         = '0;
          tx_valid_i      = 1'b0;
        end    
      end 
      
      WRITING_WR_ADDR_TO_TXFIFO: begin
        tx_data_i       = (cfg_4b_address ? addr_inv_bo : addr_3b_inv_bo);
        tx_be_i         = (cfg_4b_address ? 4'b1111 : 4'b0111);
        tx_valid_i      = 1'b1;
      end
      
      WRITING_DATA_TO_TXFIFO: begin
        tx_data_i       = wdata;
        tx_be_i         = 4'b1111;
        tx_valid_i      = wvalid;
      end
      
      WRITING_RD_ADDR_TO_TXFIFO: begin
        tx_data_i       = (cfg_4b_address ? addr_inv_bo : addr_3b_inv_bo);
        tx_be_i         = (cfg_4b_address ? 4'b1111 : 4'b0111);
        tx_valid_i      = 1'b1;
      end
      
      default: begin
        tx_data_i       = '0;
        tx_be_i         = '0;
        tx_valid_i      = 1'b0;
      end
    endcase
end 

assign rx_ready_i = rready | cfg_sw_read;


always_ff @(posedge aclk) begin
  if (!addr_valid) begin
    cs_counter <= '0;
    cs_timeout <= 1'b0;
  end
  else begin
    if (cs_counter < cfg_cs_counter_max)
      cs_counter <= cs_counter + 1;
    else
      cs_timeout <= 1'b1;
    
  end
end

always_ff @(posedge aclk or negedge arstn) begin
  if (!arstn) begin
    stt         <= IDLE;
    addr        <= '0;
    awready     <= 1'b0;
    arready     <= 1'b0;
    addr_valid  <= 1'b0;
    cur_cmd_is_read    <= 1'b0;
  end
  else begin
    case (stt)
      IDLE: begin
        if (send_sw_cmd & command_ready_o)
          stt <= SENDING_CUSTOM_CMD;
        else  
          if (cs_timeout) begin
            addr_valid <= 1'b0;
            stt        <= DESELECTING_AFTER_TIMEOUT;
          end
          else begin
            if (tx_ready_o)
              if (awvalid) begin
                  if (addr_valid) begin
                    if ((wr_addr_match))
                      stt  <= WRITING_DATA_TO_TXFIFO;
                    else
                      stt  <= DESELECTING_BEFORE_WR;
                  end
                  else begin
                    stt              <= SENDING_WRITE_CMD;                  
                  end
                  addr             <= {awaddr[31:2], 2'b00};
                  next_addr        <= {awaddr[31:2], 2'b00} + 4; 
                  awready          <= 1'b1;
                  addr_valid       <= 1'b1;
                  cur_cmd_is_read         <= 1'b0;
              end
              else
                  if (arvalid) begin
                    if (addr_valid) begin
                      if ((rd_addr_match))
                        stt <= SENDING_READ_NEXT_DATA_CMD;
                      else  
                        stt <= DESELECTING_BEFORE_RD;
                    end    
                    else  
                      stt <= SENDING_READ_CMD;
                      
                    addr             <= {araddr[31:2], 2'b00};
                    next_addr        <= {araddr[31:2], 2'b00} + 4; 
                    arready          <= 1'b1;
                    addr_valid       <= 1'b1;
                    cur_cmd_is_read         <= 1'b1;
                  end
        end
      end
      
      DESELECTING_BEFORE_RD: begin
         arready          <= 1'b0;
         if (command_ready_o) 
           stt         <= SENDING_READ_CMD; 
      end
      
      DESELECTING_BEFORE_WR: begin
         awready          <= 1'b0;
         if (command_ready_o) 
           stt         <= SENDING_WRITE_CMD; 
      end
      
      DESELECTING_AFTER_TIMEOUT: begin
         if (command_ready_o) 
           stt         <= IDLE; 
      end
      
      SENDING_WRITE_CMD: begin
        awready          <= 1'b0;
        if (command_ready_o) 
          stt             <= WRITING_WR_ADDR_TO_TXFIFO;
      end
      
      SENDING_CUSTOM_CMD: begin
        stt             <= IDLE;
      end
            
      WRITING_WR_ADDR_TO_TXFIFO: begin
        if (tx_ready_o) begin
          stt <= SENDING_WR_ADDR;
        end
      end
         
      SENDING_WR_ADDR: begin
        if (command_ready_o) begin
          stt        <= WRITING_DATA_TO_TXFIFO;
        end
      end
      
     WRITING_DATA_TO_TXFIFO: begin
        awready          <= 1'b0;
        if (tx_ready_o & wvalid) begin
          stt <= SENDING_WRITE_DATA;
        end
      end
         
      SENDING_WRITE_DATA: begin
        if (command_ready_o) begin
          stt  <= IDLE;
        end
      end
      
      SENDING_READ_CMD: begin
        arready          <= 1'b0;
        if (command_ready_o) 
          stt    <= WRITING_RD_ADDR_TO_TXFIFO;
      end 
      
      WRITING_RD_ADDR_TO_TXFIFO: begin
        if (tx_ready_o) begin
          stt  <= SENDING_RD_ADDR;
        end
      end 
     
      SENDING_RD_ADDR: begin
        if (command_ready_o) begin
          stt           <= SENDING_PAUSE_CMD;
        end
      end 
     
      SENDING_PAUSE_CMD: begin
        if (command_ready_o) begin
          stt  <= SENDING_READ_DATA_CMD;
        end
      end 
      
      SENDING_READ_DATA_CMD: begin
        if (command_ready_o) begin
          stt             <= SKIPING_DUMMY_RD_DATA;
        end
      end 
      
      SENDING_READ_NEXT_DATA_CMD: begin
        arready           <= 1'b0;
        if (command_ready_o) begin
          stt             <= WAITING_READ_DATA;
        end
      end
      
      SKIPING_DUMMY_RD_DATA: begin
        if (rx_valid_o)
          stt <= WAITING_READ_DATA;
      end
      
      WAITING_READ_DATA: begin
        if (rx_valid_o)
          stt <= IDLE;
      end 
      
      default: begin
        stt  <= IDLE;
      end
    endcase  
  end    
end

logic cfg_bvalid_d;

assign reg_wr_ack  = reg_wr_en;
assign reg_rd_ack  = reg_rd_en;
assign reg_wr_data = cfg_wdata;
assign reg_wr_strb = cfg_wstrb;
assign cfg_awready = ~reg_wr_en;
assign cfg_wready  = reg_wr_ack;

assign cfg_arready = ~reg_rd_en;
assign cfg_rvalid  = reg_rd_ack;

assign cfg_rdata  = reg_rd_data;
assign cfg_rresp  = '0;
assign cfg_bresp  = '0;
assign cfg_bvalid = reg_wr_ack | cfg_bvalid_d;

always_ff @(posedge aclk or negedge arstn) begin
  if (!arstn) begin
    reg_wr_en   <= 1'b0;
    reg_rd_en   <= 1'b0;
    cfg_bvalid_d    <= 1'b0;
  end
  else begin
    if (cfg_awvalid & (~reg_wr_en)) begin
      reg_wr_addr    <= cfg_awaddr;
      reg_wr_en      <= 1'b1;
    end
    else begin
      if (reg_wr_ack) begin
        reg_wr_en <= 1'b0;
      end   
    end
    
    if (reg_wr_en & reg_wr_ack & (~cfg_bready))
      cfg_bvalid_d <= 1'b1;
    else  
      if (cfg_bvalid_d & cfg_bready)
        cfg_bvalid_d <= 1'b0;
    
    if (cfg_arvalid & (~reg_rd_en)) begin
      reg_rd_addr    <= cfg_araddr;
      reg_rd_en      <= 1'b1;
    end
    else begin
      if (reg_rd_ack)
        reg_rd_en <= 1'b0;
    end
  end    
end

always_ff @(posedge aclk or negedge arstn) begin
  if (!arstn) begin
    send_sw_cmd <= 1'b0;
  end
  else begin
    if ((reg_wr_en) && (reg_wr_addr[7:0] == CUST_CMD_REG))
      send_sw_cmd <= 1'b1; 
    else
      if ((stt==IDLE) & command_ready_o & send_sw_cmd)
        send_sw_cmd <= 1'b0; 
  end    
end

always_comb begin
  if ((reg_wr_en) && (reg_wr_addr[7:0] == TX_FIFO_DI))
    tx_valid_sw = 1'b1;
  else
    tx_valid_sw = 1'b0;
end 

always_ff @(posedge aclk) begin
  if (cfg_sw_read & rx_valid_o)
    sw_rd_data <= rx_data_o; 
  
end

 
parameter logic [7:0] VERSION_REG    = 8'h00;
parameter logic [7:0] CONFIG_REG     = 8'h04;
parameter logic [7:0] ADDR_MASK_REG  = 8'h08;
parameter logic [7:0] CMD_CONFIG_REG = 8'h0C;
parameter logic [7:0] SPEED_REG      = 8'h10;
parameter logic [7:0] CUST_CMD_REG   = 8'h14;
parameter logic [7:0] TX_FIFO_DI     = 8'h18;
parameter logic [7:0] SW_READ_REG    = 8'h1c;
parameter logic [7:0] CS_TIMEOUT_REG = 8'h20;
parameter logic [7:0] CS_BOUNDARY_REG = 8'h24;
parameter logic [7:0] CS_BOUNDARY_MASK_REG = 8'h28;


always_ff @(posedge aclk or negedge arstn) begin
  if (!arstn) begin
    cfg_speed      <= 2'b10;
    cfg_write_cmd  <= 8'h02;
    cfg_read_cmd   <= 8'hEB;
    cfg_addr_mask  <= 32'hFFFFF;
    cfg_clkdiv     <= 1;
    cfg_csnidle    <= 2;
    cfg_csnlead    <= 1;
    cfg_csntrail   <= 1;
    cfg_full_cyc   <= '0;
    cfg_cpha       <= '0;
    cfg_cpol       <= '0;
    cfg_sw_read    <= 1'b1;
    cfg_pause_len  <= 2;
    cfg_4b_address <= 1'b0;
    cfg_cs_counter_max <= 16'h0FFF;
    cfg_boundary       <= 32'h3FFC;
    cfg_boundary_mask  <= 32'hFFFFC000;
  end
  else begin
    if ((reg_wr_en))
      case ({reg_wr_addr[7:2], 2'b0})
        CONFIG_REG: begin
          cfg_cpha     <= reg_wr_data[31];
          cfg_cpol     <= reg_wr_data[30];
          cfg_full_cyc <= reg_wr_data[29];
          cfg_sw_read  <= reg_wr_data[28];
          cfg_csnidle  <= reg_wr_data[27:24];
          cfg_csnlead  <= reg_wr_data[23:20];
          cfg_csntrail <= reg_wr_data[19:16];
          cfg_clkdiv   <= reg_wr_data[15:0];
        end           

        ADDR_MASK_REG: begin
          cfg_addr_mask <= reg_wr_data;
        end           

        CMD_CONFIG_REG: begin
          cfg_pause_len  <= reg_wr_data[31:28];
          cfg_4b_address <= reg_wr_data[24];
          cfg_write_cmd  <= reg_wr_data[15:8];
          cfg_read_cmd   <= reg_wr_data[7:0];
        end           

        SPEED_REG: begin
          cfg_speed     <= reg_wr_data[1:0];
        end           

        CUST_CMD_REG: begin
          sw_cmd_speed     <= reg_wr_data[21:20];
          sw_cmd_cmd_wr_en <= reg_wr_data[18];
          sw_cmd_cmd_rd_en <= reg_wr_data[17];
          sw_cmd_csaat     <= reg_wr_data[16];
          sw_cmd_len       <= reg_wr_data[8:0];
        end         
        
        CS_TIMEOUT_REG: begin
          cfg_cs_counter_max <= reg_wr_data[15:0];
        end 
        
        CS_BOUNDARY_REG: begin
          cfg_boundary      <= reg_wr_data;
        end 

        CS_BOUNDARY_MASK_REG: begin
          cfg_boundary_mask <= reg_wr_data;
        end 

        default: begin
        end
      endcase  
  end    
end    


always_comb begin
  if ((reg_rd_en)) begin
    case ({reg_rd_addr[5:2],2'b00})
      VERSION_REG: begin    
        reg_rd_data        = 32'hAC210824;
      end
      
      CONFIG_REG: begin
        reg_rd_data[31]    = cfg_cpha    ;
        reg_rd_data[30]    = cfg_cpol    ;
        reg_rd_data[29]    = cfg_full_cyc;
        reg_rd_data[28]    = cfg_sw_read ;
        reg_rd_data[27:24] = cfg_csnidle ;
        reg_rd_data[23:20] = cfg_csnlead ;
        reg_rd_data[19:16] = cfg_csntrail;
        reg_rd_data[15:0]  = cfg_clkdiv  ;
      end           

      ADDR_MASK_REG: begin
        reg_rd_data  = cfg_addr_mask;
      end           

      CMD_CONFIG_REG: begin
        reg_rd_data[31:28] = cfg_pause_len;
        reg_rd_data[27:25] = '0;
        reg_rd_data[24]    = cfg_4b_address;
        reg_rd_data[23:16] = '0;
        reg_rd_data[15:8]  = cfg_write_cmd;
        reg_rd_data[7:0]   = cfg_read_cmd ;
      end           
      
      SPEED_REG: begin
        reg_rd_data[31:2] = '0;
        reg_rd_data[1:0]   = cfg_speed ;
      end      
      
      SW_READ_REG: begin
        reg_rd_data = sw_rd_data;
      end

      CS_TIMEOUT_REG: begin
        reg_rd_data[31:16] = '0;
        reg_rd_data[15:0]  = cfg_cs_counter_max;
      end

      CS_BOUNDARY_REG: begin
        reg_rd_data <= cfg_boundary;
      end 

      CS_BOUNDARY_MASK_REG: begin
        reg_rd_data <= cfg_boundary_mask;
      end 
      
      default: begin
        reg_rd_data[31:0] = '0;        
      end
    endcase  
  end 
  else begin
    reg_rd_data[31:0] = '0;        
  end
  
end 

endmodule
