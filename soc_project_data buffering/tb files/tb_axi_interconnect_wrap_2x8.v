// =============================================================================
//  tb_axi_interconnect_wrap_2x8.v
//
//  Self-checking testbench for axi_interconnect_wrap_2x8
//
//  SoC Address Map (ADDR_WIDTH per slave = 24 bits, base addresses below):
//    M00  Instruction Memory   0x0000_0000
//    M01  Data Memory          0x1000_0000
//    M02  FIFO                 0x2000_0000
//    M03  DMA Controller       0x3000_0000
//    M04  Interrupt Controller 0x4000_0000
//    M05  UART                 0x5000_0000
//    M06  Timer                0x6000_0000
//    M07  GPIO                 0x7000_0000
//
//  Scenario (CPU master s00_axi only):
//    Write 1: addr=0x2000_0000  data=0xDEAD_BEEF  → FIFO
//    Write 2: addr=0x3000_0000  data=0xCAFE_BABE  → DMA Controller
//    Write 3: addr=0x4000_0000  data=0x1234_5678  → Interrupt Controller
//    Read  1: addr=0x2000_0000  expected=0xDEAD_BEEF
//    Read  2: addr=0x3000_0000  expected=0xCAFE_BABE
//    Read  3: addr=0x4000_0000  expected=0x1234_5678
//
//  Pass/fail printed after each read; simulation ends after 3rd read.
// =============================================================================

`timescale 1ns / 1ps
`default_nettype none

module tb_axi_interconnect_wrap_2x8;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam DATA_WIDTH = 32;
    localparam ADDR_WIDTH = 32;
    localparam STRB_WIDTH = DATA_WIDTH / 8;
    localparam ID_WIDTH   = 8;

    // Clock period (10 ns → 100 MHz)
    localparam CLK_PERIOD = 10;

    // Slave base addresses
    localparam [ADDR_WIDTH-1:0] ADDR_IMEM   = 32'h0000_0000;  // M00 Instruction Memory
    localparam [ADDR_WIDTH-1:0] ADDR_DMEM   = 32'h1000_0000;  // M01 Data Memory
    localparam [ADDR_WIDTH-1:0] ADDR_FIFO   = 32'h2000_0000;  // M02 FIFO
    localparam [ADDR_WIDTH-1:0] ADDR_DMA    = 32'h3000_0000;  // M03 DMA Controller
    localparam [ADDR_WIDTH-1:0] ADDR_INTCTL = 32'h4000_0000;  // M04 Interrupt Controller
    localparam [ADDR_WIDTH-1:0] ADDR_UART   = 32'h5000_0000;  // M05 UART
    localparam [ADDR_WIDTH-1:0] ADDR_TIMER  = 32'h6000_0000;  // M06 Timer
    localparam [ADDR_WIDTH-1:0] ADDR_GPIO   = 32'h7000_0000;  // M07 GPIO

    // =========================================================================
    // DUT clock / reset
    // =========================================================================
    reg clk;
    reg rst;

    initial clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // =========================================================================
    // CPU master (s00_axi) – driven by testbench
    // =========================================================================
    // Write address channel
    reg  [ID_WIDTH-1:0]   s00_axi_awid;
    reg  [ADDR_WIDTH-1:0] s00_axi_awaddr;
    reg  [7:0]            s00_axi_awlen;
    reg  [2:0]            s00_axi_awsize;
    reg  [1:0]            s00_axi_awburst;
    reg                   s00_axi_awlock;
    reg  [3:0]            s00_axi_awcache;
    reg  [2:0]            s00_axi_awprot;
    reg  [3:0]            s00_axi_awqos;
    reg  [0:0]            s00_axi_awuser;
    reg                   s00_axi_awvalid;
    wire                  s00_axi_awready;

    // Write data channel
    reg  [DATA_WIDTH-1:0] s00_axi_wdata;
    reg  [STRB_WIDTH-1:0] s00_axi_wstrb;
    reg                   s00_axi_wlast;
    reg  [0:0]            s00_axi_wuser;
    reg                   s00_axi_wvalid;
    wire                  s00_axi_wready;

    // Write response channel
    wire [ID_WIDTH-1:0]   s00_axi_bid;
    wire [1:0]            s00_axi_bresp;
    wire [0:0]            s00_axi_buser;
    wire                  s00_axi_bvalid;
    reg                   s00_axi_bready;

    // Read address channel
    reg  [ID_WIDTH-1:0]   s00_axi_arid;
    reg  [ADDR_WIDTH-1:0] s00_axi_araddr;
    reg  [7:0]            s00_axi_arlen;
    reg  [2:0]            s00_axi_arsize;
    reg  [1:0]            s00_axi_arburst;
    reg                   s00_axi_arlock;
    reg  [3:0]            s00_axi_arcache;
    reg  [2:0]            s00_axi_arprot;
    reg  [3:0]            s00_axi_arqos;
    reg  [0:0]            s00_axi_aruser;
    reg                   s00_axi_arvalid;
    wire                  s00_axi_arready;

    // Read data channel
    wire [ID_WIDTH-1:0]   s00_axi_rid;
    wire [DATA_WIDTH-1:0] s00_axi_rdata;
    wire [1:0]            s00_axi_rresp;
    wire                  s00_axi_rlast;
    wire [0:0]            s00_axi_ruser;
    wire                  s00_axi_rvalid;
    reg                   s00_axi_rready;

    // =========================================================================
    // DMA master (s01_axi) – tied off (not driven in this scenario)
    // =========================================================================
    reg  [ID_WIDTH-1:0]   s01_axi_awid    = {ID_WIDTH{1'b0}};
    reg  [ADDR_WIDTH-1:0] s01_axi_awaddr  = {ADDR_WIDTH{1'b0}};
    reg  [7:0]            s01_axi_awlen   = 8'd0;
    reg  [2:0]            s01_axi_awsize  = 3'd0;
    reg  [1:0]            s01_axi_awburst = 2'b01;
    reg                   s01_axi_awlock  = 1'b0;
    reg  [3:0]            s01_axi_awcache = 4'd0;
    reg  [2:0]            s01_axi_awprot  = 3'd0;
    reg  [3:0]            s01_axi_awqos   = 4'd0;
    reg  [0:0]            s01_axi_awuser  = 1'b0;
    reg                   s01_axi_awvalid = 1'b0;
    wire                  s01_axi_awready;

    reg  [DATA_WIDTH-1:0] s01_axi_wdata   = {DATA_WIDTH{1'b0}};
    reg  [STRB_WIDTH-1:0] s01_axi_wstrb   = {STRB_WIDTH{1'b0}};
    reg                   s01_axi_wlast   = 1'b0;
    reg  [0:0]            s01_axi_wuser   = 1'b0;
    reg                   s01_axi_wvalid  = 1'b0;
    wire                  s01_axi_wready;

    wire [ID_WIDTH-1:0]   s01_axi_bid;
    wire [1:0]            s01_axi_bresp;
    wire [0:0]            s01_axi_buser;
    wire                  s01_axi_bvalid;
    reg                   s01_axi_bready  = 1'b1;

    reg  [ID_WIDTH-1:0]   s01_axi_arid    = {ID_WIDTH{1'b0}};
    reg  [ADDR_WIDTH-1:0] s01_axi_araddr  = {ADDR_WIDTH{1'b0}};
    reg  [7:0]            s01_axi_arlen   = 8'd0;
    reg  [2:0]            s01_axi_arsize  = 3'd0;
    reg  [1:0]            s01_axi_arburst = 2'b01;
    reg                   s01_axi_arlock  = 1'b0;
    reg  [3:0]            s01_axi_arcache = 4'd0;
    reg  [2:0]            s01_axi_arprot  = 3'd0;
    reg  [3:0]            s01_axi_arqos   = 4'd0;
    reg  [0:0]            s01_axi_aruser  = 1'b0;
    reg                   s01_axi_arvalid = 1'b0;
    wire                  s01_axi_arready;

    wire [ID_WIDTH-1:0]   s01_axi_rid;
    wire [DATA_WIDTH-1:0] s01_axi_rdata;
    wire [1:0]            s01_axi_rresp;
    wire                  s01_axi_rlast;
    wire [0:0]            s01_axi_ruser;
    wire                  s01_axi_rvalid;
    reg                   s01_axi_rready  = 1'b1;

    // =========================================================================
    // Master port wires (8 slaves) – connected to axi_slave_dummy instances
    // =========================================================================
    // Helper macros for the 8 master-port signal groups
    // M00
    wire [ID_WIDTH-1:0]   m00_axi_awid;   wire [ADDR_WIDTH-1:0] m00_axi_awaddr;
    wire [7:0]            m00_axi_awlen;  wire [2:0]            m00_axi_awsize;
    wire [1:0]            m00_axi_awburst;wire                  m00_axi_awlock;
    wire [3:0]            m00_axi_awcache;wire [2:0]            m00_axi_awprot;
    wire [3:0]            m00_axi_awqos;  wire [3:0]            m00_axi_awregion;
    wire [0:0]            m00_axi_awuser; wire                  m00_axi_awvalid;
    wire                  m00_axi_awready;
    wire [DATA_WIDTH-1:0] m00_axi_wdata;  wire [STRB_WIDTH-1:0] m00_axi_wstrb;
    wire                  m00_axi_wlast;  wire [0:0]            m00_axi_wuser;
    wire                  m00_axi_wvalid; wire                  m00_axi_wready;
    wire [ID_WIDTH-1:0]   m00_axi_bid;    wire [1:0]            m00_axi_bresp;
    wire [0:0]            m00_axi_buser;  wire                  m00_axi_bvalid;
    wire                  m00_axi_bready;
    wire [ID_WIDTH-1:0]   m00_axi_arid;   wire [ADDR_WIDTH-1:0] m00_axi_araddr;
    wire [7:0]            m00_axi_arlen;  wire [2:0]            m00_axi_arsize;
    wire [1:0]            m00_axi_arburst;wire                  m00_axi_arlock;
    wire [3:0]            m00_axi_arcache;wire [2:0]            m00_axi_arprot;
    wire [3:0]            m00_axi_arqos;  wire [3:0]            m00_axi_arregion;
    wire [0:0]            m00_axi_aruser; wire                  m00_axi_arvalid;
    wire                  m00_axi_arready;
    wire [ID_WIDTH-1:0]   m00_axi_rid;    wire [DATA_WIDTH-1:0] m00_axi_rdata;
    wire [1:0]            m00_axi_rresp;  wire                  m00_axi_rlast;
    wire [0:0]            m00_axi_ruser;  wire                  m00_axi_rvalid;
    wire                  m00_axi_rready;

    // M01
    wire [ID_WIDTH-1:0]   m01_axi_awid;   wire [ADDR_WIDTH-1:0] m01_axi_awaddr;
    wire [7:0]            m01_axi_awlen;  wire [2:0]            m01_axi_awsize;
    wire [1:0]            m01_axi_awburst;wire                  m01_axi_awlock;
    wire [3:0]            m01_axi_awcache;wire [2:0]            m01_axi_awprot;
    wire [3:0]            m01_axi_awqos;  wire [3:0]            m01_axi_awregion;
    wire [0:0]            m01_axi_awuser; wire                  m01_axi_awvalid;
    wire                  m01_axi_awready;
    wire [DATA_WIDTH-1:0] m01_axi_wdata;  wire [STRB_WIDTH-1:0] m01_axi_wstrb;
    wire                  m01_axi_wlast;  wire [0:0]            m01_axi_wuser;
    wire                  m01_axi_wvalid; wire                  m01_axi_wready;
    wire [ID_WIDTH-1:0]   m01_axi_bid;    wire [1:0]            m01_axi_bresp;
    wire [0:0]            m01_axi_buser;  wire                  m01_axi_bvalid;
    wire                  m01_axi_bready;
    wire [ID_WIDTH-1:0]   m01_axi_arid;   wire [ADDR_WIDTH-1:0] m01_axi_araddr;
    wire [7:0]            m01_axi_arlen;  wire [2:0]            m01_axi_arsize;
    wire [1:0]            m01_axi_arburst;wire                  m01_axi_arlock;
    wire [3:0]            m01_axi_arcache;wire [2:0]            m01_axi_arprot;
    wire [3:0]            m01_axi_arqos;  wire [3:0]            m01_axi_arregion;
    wire [0:0]            m01_axi_aruser; wire                  m01_axi_arvalid;
    wire                  m01_axi_arready;
    wire [ID_WIDTH-1:0]   m01_axi_rid;    wire [DATA_WIDTH-1:0] m01_axi_rdata;
    wire [1:0]            m01_axi_rresp;  wire                  m01_axi_rlast;
    wire [0:0]            m01_axi_ruser;  wire                  m01_axi_rvalid;
    wire                  m01_axi_rready;

    // M02
    wire [ID_WIDTH-1:0]   m02_axi_awid;   wire [ADDR_WIDTH-1:0] m02_axi_awaddr;
    wire [7:0]            m02_axi_awlen;  wire [2:0]            m02_axi_awsize;
    wire [1:0]            m02_axi_awburst;wire                  m02_axi_awlock;
    wire [3:0]            m02_axi_awcache;wire [2:0]            m02_axi_awprot;
    wire [3:0]            m02_axi_awqos;  wire [3:0]            m02_axi_awregion;
    wire [0:0]            m02_axi_awuser; wire                  m02_axi_awvalid;
    wire                  m02_axi_awready;
    wire [DATA_WIDTH-1:0] m02_axi_wdata;  wire [STRB_WIDTH-1:0] m02_axi_wstrb;
    wire                  m02_axi_wlast;  wire [0:0]            m02_axi_wuser;
    wire                  m02_axi_wvalid; wire                  m02_axi_wready;
    wire [ID_WIDTH-1:0]   m02_axi_bid;    wire [1:0]            m02_axi_bresp;
    wire [0:0]            m02_axi_buser;  wire                  m02_axi_bvalid;
    wire                  m02_axi_bready;
    wire [ID_WIDTH-1:0]   m02_axi_arid;   wire [ADDR_WIDTH-1:0] m02_axi_araddr;
    wire [7:0]            m02_axi_arlen;  wire [2:0]            m02_axi_arsize;
    wire [1:0]            m02_axi_arburst;wire                  m02_axi_arlock;
    wire [3:0]            m02_axi_arcache;wire [2:0]            m02_axi_arprot;
    wire [3:0]            m02_axi_arqos;  wire [3:0]            m02_axi_arregion;
    wire [0:0]            m02_axi_aruser; wire                  m02_axi_arvalid;
    wire                  m02_axi_arready;
    wire [ID_WIDTH-1:0]   m02_axi_rid;    wire [DATA_WIDTH-1:0] m02_axi_rdata;
    wire [1:0]            m02_axi_rresp;  wire                  m02_axi_rlast;
    wire [0:0]            m02_axi_ruser;  wire                  m02_axi_rvalid;
    wire                  m02_axi_rready;

    // M03
    wire [ID_WIDTH-1:0]   m03_axi_awid;   wire [ADDR_WIDTH-1:0] m03_axi_awaddr;
    wire [7:0]            m03_axi_awlen;  wire [2:0]            m03_axi_awsize;
    wire [1:0]            m03_axi_awburst;wire                  m03_axi_awlock;
    wire [3:0]            m03_axi_awcache;wire [2:0]            m03_axi_awprot;
    wire [3:0]            m03_axi_awqos;  wire [3:0]            m03_axi_awregion;
    wire [0:0]            m03_axi_awuser; wire                  m03_axi_awvalid;
    wire                  m03_axi_awready;
    wire [DATA_WIDTH-1:0] m03_axi_wdata;  wire [STRB_WIDTH-1:0] m03_axi_wstrb;
    wire                  m03_axi_wlast;  wire [0:0]            m03_axi_wuser;
    wire                  m03_axi_wvalid; wire                  m03_axi_wready;
    wire [ID_WIDTH-1:0]   m03_axi_bid;    wire [1:0]            m03_axi_bresp;
    wire [0:0]            m03_axi_buser;  wire                  m03_axi_bvalid;
    wire                  m03_axi_bready;
    wire [ID_WIDTH-1:0]   m03_axi_arid;   wire [ADDR_WIDTH-1:0] m03_axi_araddr;
    wire [7:0]            m03_axi_arlen;  wire [2:0]            m03_axi_arsize;
    wire [1:0]            m03_axi_arburst;wire                  m03_axi_arlock;
    wire [3:0]            m03_axi_arcache;wire [2:0]            m03_axi_arprot;
    wire [3:0]            m03_axi_arqos;  wire [3:0]            m03_axi_arregion;
    wire [0:0]            m03_axi_aruser; wire                  m03_axi_arvalid;
    wire                  m03_axi_arready;
    wire [ID_WIDTH-1:0]   m03_axi_rid;    wire [DATA_WIDTH-1:0] m03_axi_rdata;
    wire [1:0]            m03_axi_rresp;  wire                  m03_axi_rlast;
    wire [0:0]            m03_axi_ruser;  wire                  m03_axi_rvalid;
    wire                  m03_axi_rready;

    // M04
    wire [ID_WIDTH-1:0]   m04_axi_awid;   wire [ADDR_WIDTH-1:0] m04_axi_awaddr;
    wire [7:0]            m04_axi_awlen;  wire [2:0]            m04_axi_awsize;
    wire [1:0]            m04_axi_awburst;wire                  m04_axi_awlock;
    wire [3:0]            m04_axi_awcache;wire [2:0]            m04_axi_awprot;
    wire [3:0]            m04_axi_awqos;  wire [3:0]            m04_axi_awregion;
    wire [0:0]            m04_axi_awuser; wire                  m04_axi_awvalid;
    wire                  m04_axi_awready;
    wire [DATA_WIDTH-1:0] m04_axi_wdata;  wire [STRB_WIDTH-1:0] m04_axi_wstrb;
    wire                  m04_axi_wlast;  wire [0:0]            m04_axi_wuser;
    wire                  m04_axi_wvalid; wire                  m04_axi_wready;
    wire [ID_WIDTH-1:0]   m04_axi_bid;    wire [1:0]            m04_axi_bresp;
    wire [0:0]            m04_axi_buser;  wire                  m04_axi_bvalid;
    wire                  m04_axi_bready;
    wire [ID_WIDTH-1:0]   m04_axi_arid;   wire [ADDR_WIDTH-1:0] m04_axi_araddr;
    wire [7:0]            m04_axi_arlen;  wire [2:0]            m04_axi_arsize;
    wire [1:0]            m04_axi_arburst;wire                  m04_axi_arlock;
    wire [3:0]            m04_axi_arcache;wire [2:0]            m04_axi_arprot;
    wire [3:0]            m04_axi_arqos;  wire [3:0]            m04_axi_arregion;
    wire [0:0]            m04_axi_aruser; wire                  m04_axi_arvalid;
    wire                  m04_axi_arready;
    wire [ID_WIDTH-1:0]   m04_axi_rid;    wire [DATA_WIDTH-1:0] m04_axi_rdata;
    wire [1:0]            m04_axi_rresp;  wire                  m04_axi_rlast;
    wire [0:0]            m04_axi_ruser;  wire                  m04_axi_rvalid;
    wire                  m04_axi_rready;

    // M05
    wire [ID_WIDTH-1:0]   m05_axi_awid;   wire [ADDR_WIDTH-1:0] m05_axi_awaddr;
    wire [7:0]            m05_axi_awlen;  wire [2:0]            m05_axi_awsize;
    wire [1:0]            m05_axi_awburst;wire                  m05_axi_awlock;
    wire [3:0]            m05_axi_awcache;wire [2:0]            m05_axi_awprot;
    wire [3:0]            m05_axi_awqos;  wire [3:0]            m05_axi_awregion;
    wire [0:0]            m05_axi_awuser; wire                  m05_axi_awvalid;
    wire                  m05_axi_awready;
    wire [DATA_WIDTH-1:0] m05_axi_wdata;  wire [STRB_WIDTH-1:0] m05_axi_wstrb;
    wire                  m05_axi_wlast;  wire [0:0]            m05_axi_wuser;
    wire                  m05_axi_wvalid; wire                  m05_axi_wready;
    wire [ID_WIDTH-1:0]   m05_axi_bid;    wire [1:0]            m05_axi_bresp;
    wire [0:0]            m05_axi_buser;  wire                  m05_axi_bvalid;
    wire                  m05_axi_bready;
    wire [ID_WIDTH-1:0]   m05_axi_arid;   wire [ADDR_WIDTH-1:0] m05_axi_araddr;
    wire [7:0]            m05_axi_arlen;  wire [2:0]            m05_axi_arsize;
    wire [1:0]            m05_axi_arburst;wire                  m05_axi_arlock;
    wire [3:0]            m05_axi_arcache;wire [2:0]            m05_axi_arprot;
    wire [3:0]            m05_axi_arqos;  wire [3:0]            m05_axi_arregion;
    wire [0:0]            m05_axi_aruser; wire                  m05_axi_arvalid;
    wire                  m05_axi_arready;
    wire [ID_WIDTH-1:0]   m05_axi_rid;    wire [DATA_WIDTH-1:0] m05_axi_rdata;
    wire [1:0]            m05_axi_rresp;  wire                  m05_axi_rlast;
    wire [0:0]            m05_axi_ruser;  wire                  m05_axi_rvalid;
    wire                  m05_axi_rready;

    // M06
    wire [ID_WIDTH-1:0]   m06_axi_awid;   wire [ADDR_WIDTH-1:0] m06_axi_awaddr;
    wire [7:0]            m06_axi_awlen;  wire [2:0]            m06_axi_awsize;
    wire [1:0]            m06_axi_awburst;wire                  m06_axi_awlock;
    wire [3:0]            m06_axi_awcache;wire [2:0]            m06_axi_awprot;
    wire [3:0]            m06_axi_awqos;  wire [3:0]            m06_axi_awregion;
    wire [0:0]            m06_axi_awuser; wire                  m06_axi_awvalid;
    wire                  m06_axi_awready;
    wire [DATA_WIDTH-1:0] m06_axi_wdata;  wire [STRB_WIDTH-1:0] m06_axi_wstrb;
    wire                  m06_axi_wlast;  wire [0:0]            m06_axi_wuser;
    wire                  m06_axi_wvalid; wire                  m06_axi_wready;
    wire [ID_WIDTH-1:0]   m06_axi_bid;    wire [1:0]            m06_axi_bresp;
    wire [0:0]            m06_axi_buser;  wire                  m06_axi_bvalid;
    wire                  m06_axi_bready;
    wire [ID_WIDTH-1:0]   m06_axi_arid;   wire [ADDR_WIDTH-1:0] m06_axi_araddr;
    wire [7:0]            m06_axi_arlen;  wire [2:0]            m06_axi_arsize;
    wire [1:0]            m06_axi_arburst;wire                  m06_axi_arlock;
    wire [3:0]            m06_axi_arcache;wire [2:0]            m06_axi_arprot;
    wire [3:0]            m06_axi_arqos;  wire [3:0]            m06_axi_arregion;
    wire [0:0]            m06_axi_aruser; wire                  m06_axi_arvalid;
    wire                  m06_axi_arready;
    wire [ID_WIDTH-1:0]   m06_axi_rid;    wire [DATA_WIDTH-1:0] m06_axi_rdata;
    wire [1:0]            m06_axi_rresp;  wire                  m06_axi_rlast;
    wire [0:0]            m06_axi_ruser;  wire                  m06_axi_rvalid;
    wire                  m06_axi_rready;

    // M07
    wire [ID_WIDTH-1:0]   m07_axi_awid;   wire [ADDR_WIDTH-1:0] m07_axi_awaddr;
    wire [7:0]            m07_axi_awlen;  wire [2:0]            m07_axi_awsize;
    wire [1:0]            m07_axi_awburst;wire                  m07_axi_awlock;
    wire [3:0]            m07_axi_awcache;wire [2:0]            m07_axi_awprot;
    wire [3:0]            m07_axi_awqos;  wire [3:0]            m07_axi_awregion;
    wire [0:0]            m07_axi_awuser; wire                  m07_axi_awvalid;
    wire                  m07_axi_awready;
    wire [DATA_WIDTH-1:0] m07_axi_wdata;  wire [STRB_WIDTH-1:0] m07_axi_wstrb;
    wire                  m07_axi_wlast;  wire [0:0]            m07_axi_wuser;
    wire                  m07_axi_wvalid; wire                  m07_axi_wready;
    wire [ID_WIDTH-1:0]   m07_axi_bid;    wire [1:0]            m07_axi_bresp;
    wire [0:0]            m07_axi_buser;  wire                  m07_axi_bvalid;
    wire                  m07_axi_bready;
    wire [ID_WIDTH-1:0]   m07_axi_arid;   wire [ADDR_WIDTH-1:0] m07_axi_araddr;
    wire [7:0]            m07_axi_arlen;  wire [2:0]            m07_axi_arsize;
    wire [1:0]            m07_axi_arburst;wire                  m07_axi_arlock;
    wire [3:0]            m07_axi_arcache;wire [2:0]            m07_axi_arprot;
    wire [3:0]            m07_axi_arqos;  wire [3:0]            m07_axi_arregion;
    wire [0:0]            m07_axi_aruser; wire                  m07_axi_arvalid;
    wire                  m07_axi_arready;
    wire [ID_WIDTH-1:0]   m07_axi_rid;    wire [DATA_WIDTH-1:0] m07_axi_rdata;
    wire [1:0]            m07_axi_rresp;  wire                  m07_axi_rlast;
    wire [0:0]            m07_axi_ruser;  wire                  m07_axi_rvalid;
    wire                  m07_axi_rready;

    // =========================================================================
    // DUT instantiation
    // =========================================================================
    axi_interconnect_wrap_2x8 #(
        .DATA_WIDTH       (DATA_WIDTH),
        .ADDR_WIDTH       (ADDR_WIDTH),
        .STRB_WIDTH       (STRB_WIDTH),
        .ID_WIDTH         (ID_WIDTH),
        .AWUSER_ENABLE    (0),
        .AWUSER_WIDTH     (1),
        .WUSER_ENABLE     (0),
        .WUSER_WIDTH      (1),
        .BUSER_ENABLE     (0),
        .BUSER_WIDTH      (1),
        .ARUSER_ENABLE    (0),
        .ARUSER_WIDTH     (1),
        .RUSER_ENABLE     (0),
        .RUSER_WIDTH      (1),
        .FORWARD_ID       (0),
        .M_REGIONS        (1),
        // ----- Slave base addresses (24-bit region per slave) -----
        .M00_BASE_ADDR    (ADDR_IMEM),    // Instruction Memory   0x0000_0000
        .M00_ADDR_WIDTH   (32'd24),
        .M00_CONNECT_READ (2'b11),
        .M00_CONNECT_WRITE(2'b11),
        .M01_BASE_ADDR    (ADDR_DMEM),    // Data Memory          0x1000_0000
        .M01_ADDR_WIDTH   (32'd24),
        .M01_CONNECT_READ (2'b11),
        .M01_CONNECT_WRITE(2'b11),
        .M02_BASE_ADDR    (ADDR_FIFO),    // FIFO                 0x2000_0000
        .M02_ADDR_WIDTH   (32'd24),
        .M02_CONNECT_READ (2'b11),
        .M02_CONNECT_WRITE(2'b11),
        .M03_BASE_ADDR    (ADDR_DMA),     // DMA Controller       0x3000_0000
        .M03_ADDR_WIDTH   (32'd24),
        .M03_CONNECT_READ (2'b11),
        .M03_CONNECT_WRITE(2'b11),
        .M04_BASE_ADDR    (ADDR_INTCTL),  // Interrupt Controller 0x4000_0000
        .M04_ADDR_WIDTH   (32'd24),
        .M04_CONNECT_READ (2'b11),
        .M04_CONNECT_WRITE(2'b11),
        .M05_BASE_ADDR    (ADDR_UART),    // UART                 0x5000_0000
        .M05_ADDR_WIDTH   (32'd24),
        .M05_CONNECT_READ (2'b11),
        .M05_CONNECT_WRITE(2'b11),
        .M06_BASE_ADDR    (ADDR_TIMER),   // Timer                0x6000_0000
        .M06_ADDR_WIDTH   (32'd24),
        .M06_CONNECT_READ (2'b11),
        .M06_CONNECT_WRITE(2'b11),
        .M07_BASE_ADDR    (ADDR_GPIO),    // GPIO                 0x7000_0000
        .M07_ADDR_WIDTH   (32'd24),
        .M07_CONNECT_READ (2'b11),
        .M07_CONNECT_WRITE(2'b11)
    ) dut (
        .clk              (clk),
        .rst              (rst),
        // ---- s00 (CPU / VeeR EL2) ----
        .s00_axi_awid     (s00_axi_awid),
        .s00_axi_awaddr   (s00_axi_awaddr),
        .s00_axi_awlen    (s00_axi_awlen),
        .s00_axi_awsize   (s00_axi_awsize),
        .s00_axi_awburst  (s00_axi_awburst),
        .s00_axi_awlock   (s00_axi_awlock),
        .s00_axi_awcache  (s00_axi_awcache),
        .s00_axi_awprot   (s00_axi_awprot),
        .s00_axi_awqos    (s00_axi_awqos),
        .s00_axi_awuser   (s00_axi_awuser),
        .s00_axi_awvalid  (s00_axi_awvalid),
        .s00_axi_awready  (s00_axi_awready),
        .s00_axi_wdata    (s00_axi_wdata),
        .s00_axi_wstrb    (s00_axi_wstrb),
        .s00_axi_wlast    (s00_axi_wlast),
        .s00_axi_wuser    (s00_axi_wuser),
        .s00_axi_wvalid   (s00_axi_wvalid),
        .s00_axi_wready   (s00_axi_wready),
        .s00_axi_bid      (s00_axi_bid),
        .s00_axi_bresp    (s00_axi_bresp),
        .s00_axi_buser    (s00_axi_buser),
        .s00_axi_bvalid   (s00_axi_bvalid),
        .s00_axi_bready   (s00_axi_bready),
        .s00_axi_arid     (s00_axi_arid),
        .s00_axi_araddr   (s00_axi_araddr),
        .s00_axi_arlen    (s00_axi_arlen),
        .s00_axi_arsize   (s00_axi_arsize),
        .s00_axi_arburst  (s00_axi_arburst),
        .s00_axi_arlock   (s00_axi_arlock),
        .s00_axi_arcache  (s00_axi_arcache),
        .s00_axi_arprot   (s00_axi_arprot),
        .s00_axi_arqos    (s00_axi_arqos),
        .s00_axi_aruser   (s00_axi_aruser),
        .s00_axi_arvalid  (s00_axi_arvalid),
        .s00_axi_arready  (s00_axi_arready),
        .s00_axi_rid      (s00_axi_rid),
        .s00_axi_rdata    (s00_axi_rdata),
        .s00_axi_rresp    (s00_axi_rresp),
        .s00_axi_rlast    (s00_axi_rlast),
        .s00_axi_ruser    (s00_axi_ruser),
        .s00_axi_rvalid   (s00_axi_rvalid),
        .s00_axi_rready   (s00_axi_rready),
        // ---- s01 (DMA – tied off) ----
        .s01_axi_awid     (s01_axi_awid),
        .s01_axi_awaddr   (s01_axi_awaddr),
        .s01_axi_awlen    (s01_axi_awlen),
        .s01_axi_awsize   (s01_axi_awsize),
        .s01_axi_awburst  (s01_axi_awburst),
        .s01_axi_awlock   (s01_axi_awlock),
        .s01_axi_awcache  (s01_axi_awcache),
        .s01_axi_awprot   (s01_axi_awprot),
        .s01_axi_awqos    (s01_axi_awqos),
        .s01_axi_awuser   (s01_axi_awuser),
        .s01_axi_awvalid  (s01_axi_awvalid),
        .s01_axi_awready  (s01_axi_awready),
        .s01_axi_wdata    (s01_axi_wdata),
        .s01_axi_wstrb    (s01_axi_wstrb),
        .s01_axi_wlast    (s01_axi_wlast),
        .s01_axi_wuser    (s01_axi_wuser),
        .s01_axi_wvalid   (s01_axi_wvalid),
        .s01_axi_wready   (s01_axi_wready),
        .s01_axi_bid      (s01_axi_bid),
        .s01_axi_bresp    (s01_axi_bresp),
        .s01_axi_buser    (s01_axi_buser),
        .s01_axi_bvalid   (s01_axi_bvalid),
        .s01_axi_bready   (s01_axi_bready),
        .s01_axi_arid     (s01_axi_arid),
        .s01_axi_araddr   (s01_axi_araddr),
        .s01_axi_arlen    (s01_axi_arlen),
        .s01_axi_arsize   (s01_axi_arsize),
        .s01_axi_arburst  (s01_axi_arburst),
        .s01_axi_arlock   (s01_axi_arlock),
        .s01_axi_arcache  (s01_axi_arcache),
        .s01_axi_arprot   (s01_axi_arprot),
        .s01_axi_arqos    (s01_axi_arqos),
        .s01_axi_aruser   (s01_axi_aruser),
        .s01_axi_arvalid  (s01_axi_arvalid),
        .s01_axi_arready  (s01_axi_arready),
        .s01_axi_rid      (s01_axi_rid),
        .s01_axi_rdata    (s01_axi_rdata),
        .s01_axi_rresp    (s01_axi_rresp),
        .s01_axi_rlast    (s01_axi_rlast),
        .s01_axi_ruser    (s01_axi_ruser),
        .s01_axi_rvalid   (s01_axi_rvalid),
        .s01_axi_rready   (s01_axi_rready),
        // ---- m00 (Instruction Memory) ----
        .m00_axi_awid     (m00_axi_awid),    .m00_axi_awaddr   (m00_axi_awaddr),
        .m00_axi_awlen    (m00_axi_awlen),   .m00_axi_awsize   (m00_axi_awsize),
        .m00_axi_awburst  (m00_axi_awburst), .m00_axi_awlock   (m00_axi_awlock),
        .m00_axi_awcache  (m00_axi_awcache), .m00_axi_awprot   (m00_axi_awprot),
        .m00_axi_awqos    (m00_axi_awqos),   .m00_axi_awregion (m00_axi_awregion),
        .m00_axi_awuser   (m00_axi_awuser),  .m00_axi_awvalid  (m00_axi_awvalid),
        .m00_axi_awready  (m00_axi_awready),
        .m00_axi_wdata    (m00_axi_wdata),   .m00_axi_wstrb    (m00_axi_wstrb),
        .m00_axi_wlast    (m00_axi_wlast),   .m00_axi_wuser    (m00_axi_wuser),
        .m00_axi_wvalid   (m00_axi_wvalid),  .m00_axi_wready   (m00_axi_wready),
        .m00_axi_bid      (m00_axi_bid),     .m00_axi_bresp    (m00_axi_bresp),
        .m00_axi_buser    (m00_axi_buser),   .m00_axi_bvalid   (m00_axi_bvalid),
        .m00_axi_bready   (m00_axi_bready),
        .m00_axi_arid     (m00_axi_arid),    .m00_axi_araddr   (m00_axi_araddr),
        .m00_axi_arlen    (m00_axi_arlen),   .m00_axi_arsize   (m00_axi_arsize),
        .m00_axi_arburst  (m00_axi_arburst), .m00_axi_arlock   (m00_axi_arlock),
        .m00_axi_arcache  (m00_axi_arcache), .m00_axi_arprot   (m00_axi_arprot),
        .m00_axi_arqos    (m00_axi_arqos),   .m00_axi_arregion (m00_axi_arregion),
        .m00_axi_aruser   (m00_axi_aruser),  .m00_axi_arvalid  (m00_axi_arvalid),
        .m00_axi_arready  (m00_axi_arready),
        .m00_axi_rid      (m00_axi_rid),     .m00_axi_rdata    (m00_axi_rdata),
        .m00_axi_rresp    (m00_axi_rresp),   .m00_axi_rlast    (m00_axi_rlast),
        .m00_axi_ruser    (m00_axi_ruser),   .m00_axi_rvalid   (m00_axi_rvalid),
        .m00_axi_rready   (m00_axi_rready),
        // ---- m01 (Data Memory) ----
        .m01_axi_awid     (m01_axi_awid),    .m01_axi_awaddr   (m01_axi_awaddr),
        .m01_axi_awlen    (m01_axi_awlen),   .m01_axi_awsize   (m01_axi_awsize),
        .m01_axi_awburst  (m01_axi_awburst), .m01_axi_awlock   (m01_axi_awlock),
        .m01_axi_awcache  (m01_axi_awcache), .m01_axi_awprot   (m01_axi_awprot),
        .m01_axi_awqos    (m01_axi_awqos),   .m01_axi_awregion (m01_axi_awregion),
        .m01_axi_awuser   (m01_axi_awuser),  .m01_axi_awvalid  (m01_axi_awvalid),
        .m01_axi_awready  (m01_axi_awready),
        .m01_axi_wdata    (m01_axi_wdata),   .m01_axi_wstrb    (m01_axi_wstrb),
        .m01_axi_wlast    (m01_axi_wlast),   .m01_axi_wuser    (m01_axi_wuser),
        .m01_axi_wvalid   (m01_axi_wvalid),  .m01_axi_wready   (m01_axi_wready),
        .m01_axi_bid      (m01_axi_bid),     .m01_axi_bresp    (m01_axi_bresp),
        .m01_axi_buser    (m01_axi_buser),   .m01_axi_bvalid   (m01_axi_bvalid),
        .m01_axi_bready   (m01_axi_bready),
        .m01_axi_arid     (m01_axi_arid),    .m01_axi_araddr   (m01_axi_araddr),
        .m01_axi_arlen    (m01_axi_arlen),   .m01_axi_arsize   (m01_axi_arsize),
        .m01_axi_arburst  (m01_axi_arburst), .m01_axi_arlock   (m01_axi_arlock),
        .m01_axi_arcache  (m01_axi_arcache), .m01_axi_arprot   (m01_axi_arprot),
        .m01_axi_arqos    (m01_axi_arqos),   .m01_axi_arregion (m01_axi_arregion),
        .m01_axi_aruser   (m01_axi_aruser),  .m01_axi_arvalid  (m01_axi_arvalid),
        .m01_axi_arready  (m01_axi_arready),
        .m01_axi_rid      (m01_axi_rid),     .m01_axi_rdata    (m01_axi_rdata),
        .m01_axi_rresp    (m01_axi_rresp),   .m01_axi_rlast    (m01_axi_rlast),
        .m01_axi_ruser    (m01_axi_ruser),   .m01_axi_rvalid   (m01_axi_rvalid),
        .m01_axi_rready   (m01_axi_rready),
        // ---- m02 (FIFO) ----
        .m02_axi_awid     (m02_axi_awid),    .m02_axi_awaddr   (m02_axi_awaddr),
        .m02_axi_awlen    (m02_axi_awlen),   .m02_axi_awsize   (m02_axi_awsize),
        .m02_axi_awburst  (m02_axi_awburst), .m02_axi_awlock   (m02_axi_awlock),
        .m02_axi_awcache  (m02_axi_awcache), .m02_axi_awprot   (m02_axi_awprot),
        .m02_axi_awqos    (m02_axi_awqos),   .m02_axi_awregion (m02_axi_awregion),
        .m02_axi_awuser   (m02_axi_awuser),  .m02_axi_awvalid  (m02_axi_awvalid),
        .m02_axi_awready  (m02_axi_awready),
        .m02_axi_wdata    (m02_axi_wdata),   .m02_axi_wstrb    (m02_axi_wstrb),
        .m02_axi_wlast    (m02_axi_wlast),   .m02_axi_wuser    (m02_axi_wuser),
        .m02_axi_wvalid   (m02_axi_wvalid),  .m02_axi_wready   (m02_axi_wready),
        .m02_axi_bid      (m02_axi_bid),     .m02_axi_bresp    (m02_axi_bresp),
        .m02_axi_buser    (m02_axi_buser),   .m02_axi_bvalid   (m02_axi_bvalid),
        .m02_axi_bready   (m02_axi_bready),
        .m02_axi_arid     (m02_axi_arid),    .m02_axi_araddr   (m02_axi_araddr),
        .m02_axi_arlen    (m02_axi_arlen),   .m02_axi_arsize   (m02_axi_arsize),
        .m02_axi_arburst  (m02_axi_arburst), .m02_axi_arlock   (m02_axi_arlock),
        .m02_axi_arcache  (m02_axi_arcache), .m02_axi_arprot   (m02_axi_arprot),
        .m02_axi_arqos    (m02_axi_arqos),   .m02_axi_arregion (m02_axi_arregion),
        .m02_axi_aruser   (m02_axi_aruser),  .m02_axi_arvalid  (m02_axi_arvalid),
        .m02_axi_arready  (m02_axi_arready),
        .m02_axi_rid      (m02_axi_rid),     .m02_axi_rdata    (m02_axi_rdata),
        .m02_axi_rresp    (m02_axi_rresp),   .m02_axi_rlast    (m02_axi_rlast),
        .m02_axi_ruser    (m02_axi_ruser),   .m02_axi_rvalid   (m02_axi_rvalid),
        .m02_axi_rready   (m02_axi_rready),
        // ---- m03 (DMA Controller) ----
        .m03_axi_awid     (m03_axi_awid),    .m03_axi_awaddr   (m03_axi_awaddr),
        .m03_axi_awlen    (m03_axi_awlen),   .m03_axi_awsize   (m03_axi_awsize),
        .m03_axi_awburst  (m03_axi_awburst), .m03_axi_awlock   (m03_axi_awlock),
        .m03_axi_awcache  (m03_axi_awcache), .m03_axi_awprot   (m03_axi_awprot),
        .m03_axi_awqos    (m03_axi_awqos),   .m03_axi_awregion (m03_axi_awregion),
        .m03_axi_awuser   (m03_axi_awuser),  .m03_axi_awvalid  (m03_axi_awvalid),
        .m03_axi_awready  (m03_axi_awready),
        .m03_axi_wdata    (m03_axi_wdata),   .m03_axi_wstrb    (m03_axi_wstrb),
        .m03_axi_wlast    (m03_axi_wlast),   .m03_axi_wuser    (m03_axi_wuser),
        .m03_axi_wvalid   (m03_axi_wvalid),  .m03_axi_wready   (m03_axi_wready),
        .m03_axi_bid      (m03_axi_bid),     .m03_axi_bresp    (m03_axi_bresp),
        .m03_axi_buser    (m03_axi_buser),   .m03_axi_bvalid   (m03_axi_bvalid),
        .m03_axi_bready   (m03_axi_bready),
        .m03_axi_arid     (m03_axi_arid),    .m03_axi_araddr   (m03_axi_araddr),
        .m03_axi_arlen    (m03_axi_arlen),   .m03_axi_arsize   (m03_axi_arsize),
        .m03_axi_arburst  (m03_axi_arburst), .m03_axi_arlock   (m03_axi_arlock),
        .m03_axi_arcache  (m03_axi_arcache), .m03_axi_arprot   (m03_axi_arprot),
        .m03_axi_arqos    (m03_axi_arqos),   .m03_axi_arregion (m03_axi_arregion),
        .m03_axi_aruser   (m03_axi_aruser),  .m03_axi_arvalid  (m03_axi_arvalid),
        .m03_axi_arready  (m03_axi_arready),
        .m03_axi_rid      (m03_axi_rid),     .m03_axi_rdata    (m03_axi_rdata),
        .m03_axi_rresp    (m03_axi_rresp),   .m03_axi_rlast    (m03_axi_rlast),
        .m03_axi_ruser    (m03_axi_ruser),   .m03_axi_rvalid   (m03_axi_rvalid),
        .m03_axi_rready   (m03_axi_rready),
        // ---- m04 (Interrupt Controller) ----
        .m04_axi_awid     (m04_axi_awid),    .m04_axi_awaddr   (m04_axi_awaddr),
        .m04_axi_awlen    (m04_axi_awlen),   .m04_axi_awsize   (m04_axi_awsize),
        .m04_axi_awburst  (m04_axi_awburst), .m04_axi_awlock   (m04_axi_awlock),
        .m04_axi_awcache  (m04_axi_awcache), .m04_axi_awprot   (m04_axi_awprot),
        .m04_axi_awqos    (m04_axi_awqos),   .m04_axi_awregion (m04_axi_awregion),
        .m04_axi_awuser   (m04_axi_awuser),  .m04_axi_awvalid  (m04_axi_awvalid),
        .m04_axi_awready  (m04_axi_awready),
        .m04_axi_wdata    (m04_axi_wdata),   .m04_axi_wstrb    (m04_axi_wstrb),
        .m04_axi_wlast    (m04_axi_wlast),   .m04_axi_wuser    (m04_axi_wuser),
        .m04_axi_wvalid   (m04_axi_wvalid),  .m04_axi_wready   (m04_axi_wready),
        .m04_axi_bid      (m04_axi_bid),     .m04_axi_bresp    (m04_axi_bresp),
        .m04_axi_buser    (m04_axi_buser),   .m04_axi_bvalid   (m04_axi_bvalid),
        .m04_axi_bready   (m04_axi_bready),
        .m04_axi_arid     (m04_axi_arid),    .m04_axi_araddr   (m04_axi_araddr),
        .m04_axi_arlen    (m04_axi_arlen),   .m04_axi_arsize   (m04_axi_arsize),
        .m04_axi_arburst  (m04_axi_arburst), .m04_axi_arlock   (m04_axi_arlock),
        .m04_axi_arcache  (m04_axi_arcache), .m04_axi_arprot   (m04_axi_arprot),
        .m04_axi_arqos    (m04_axi_arqos),   .m04_axi_arregion (m04_axi_arregion),
        .m04_axi_aruser   (m04_axi_aruser),  .m04_axi_arvalid  (m04_axi_arvalid),
        .m04_axi_arready  (m04_axi_arready),
        .m04_axi_rid      (m04_axi_rid),     .m04_axi_rdata    (m04_axi_rdata),
        .m04_axi_rresp    (m04_axi_rresp),   .m04_axi_rlast    (m04_axi_rlast),
        .m04_axi_ruser    (m04_axi_ruser),   .m04_axi_rvalid   (m04_axi_rvalid),
        .m04_axi_rready   (m04_axi_rready),
        // ---- m05 (UART) ----
        .m05_axi_awid     (m05_axi_awid),    .m05_axi_awaddr   (m05_axi_awaddr),
        .m05_axi_awlen    (m05_axi_awlen),   .m05_axi_awsize   (m05_axi_awsize),
        .m05_axi_awburst  (m05_axi_awburst), .m05_axi_awlock   (m05_axi_awlock),
        .m05_axi_awcache  (m05_axi_awcache), .m05_axi_awprot   (m05_axi_awprot),
        .m05_axi_awqos    (m05_axi_awqos),   .m05_axi_awregion (m05_axi_awregion),
        .m05_axi_awuser   (m05_axi_awuser),  .m05_axi_awvalid  (m05_axi_awvalid),
        .m05_axi_awready  (m05_axi_awready),
        .m05_axi_wdata    (m05_axi_wdata),   .m05_axi_wstrb    (m05_axi_wstrb),
        .m05_axi_wlast    (m05_axi_wlast),   .m05_axi_wuser    (m05_axi_wuser),
        .m05_axi_wvalid   (m05_axi_wvalid),  .m05_axi_wready   (m05_axi_wready),
        .m05_axi_bid      (m05_axi_bid),     .m05_axi_bresp    (m05_axi_bresp),
        .m05_axi_buser    (m05_axi_buser),   .m05_axi_bvalid   (m05_axi_bvalid),
        .m05_axi_bready   (m05_axi_bready),
        .m05_axi_arid     (m05_axi_arid),    .m05_axi_araddr   (m05_axi_araddr),
        .m05_axi_arlen    (m05_axi_arlen),   .m05_axi_arsize   (m05_axi_arsize),
        .m05_axi_arburst  (m05_axi_arburst), .m05_axi_arlock   (m05_axi_arlock),
        .m05_axi_arcache  (m05_axi_arcache), .m05_axi_arprot   (m05_axi_arprot),
        .m05_axi_arqos    (m05_axi_arqos),   .m05_axi_arregion (m05_axi_arregion),
        .m05_axi_aruser   (m05_axi_aruser),  .m05_axi_arvalid  (m05_axi_arvalid),
        .m05_axi_arready  (m05_axi_arready),
        .m05_axi_rid      (m05_axi_rid),     .m05_axi_rdata    (m05_axi_rdata),
        .m05_axi_rresp    (m05_axi_rresp),   .m05_axi_rlast    (m05_axi_rlast),
        .m05_axi_ruser    (m05_axi_ruser),   .m05_axi_rvalid   (m05_axi_rvalid),
        .m05_axi_rready   (m05_axi_rready),
        // ---- m06 (Timer) ----
        .m06_axi_awid     (m06_axi_awid),    .m06_axi_awaddr   (m06_axi_awaddr),
        .m06_axi_awlen    (m06_axi_awlen),   .m06_axi_awsize   (m06_axi_awsize),
        .m06_axi_awburst  (m06_axi_awburst), .m06_axi_awlock   (m06_axi_awlock),
        .m06_axi_awcache  (m06_axi_awcache), .m06_axi_awprot   (m06_axi_awprot),
        .m06_axi_awqos    (m06_axi_awqos),   .m06_axi_awregion (m06_axi_awregion),
        .m06_axi_awuser   (m06_axi_awuser),  .m06_axi_awvalid  (m06_axi_awvalid),
        .m06_axi_awready  (m06_axi_awready),
        .m06_axi_wdata    (m06_axi_wdata),   .m06_axi_wstrb    (m06_axi_wstrb),
        .m06_axi_wlast    (m06_axi_wlast),   .m06_axi_wuser    (m06_axi_wuser),
        .m06_axi_wvalid   (m06_axi_wvalid),  .m06_axi_wready   (m06_axi_wready),
        .m06_axi_bid      (m06_axi_bid),     .m06_axi_bresp    (m06_axi_bresp),
        .m06_axi_buser    (m06_axi_buser),   .m06_axi_bvalid   (m06_axi_bvalid),
        .m06_axi_bready   (m06_axi_bready),
        .m06_axi_arid     (m06_axi_arid),    .m06_axi_araddr   (m06_axi_araddr),
        .m06_axi_arlen    (m06_axi_arlen),   .m06_axi_arsize   (m06_axi_arsize),
        .m06_axi_arburst  (m06_axi_arburst), .m06_axi_arlock   (m06_axi_arlock),
        .m06_axi_arcache  (m06_axi_arcache), .m06_axi_arprot   (m06_axi_arprot),
        .m06_axi_arqos    (m06_axi_arqos),   .m06_axi_arregion (m06_axi_arregion),
        .m06_axi_aruser   (m06_axi_aruser),  .m06_axi_arvalid  (m06_axi_arvalid),
        .m06_axi_arready  (m06_axi_arready),
        .m06_axi_rid      (m06_axi_rid),     .m06_axi_rdata    (m06_axi_rdata),
        .m06_axi_rresp    (m06_axi_rresp),   .m06_axi_rlast    (m06_axi_rlast),
        .m06_axi_ruser    (m06_axi_ruser),   .m06_axi_rvalid   (m06_axi_rvalid),
        .m06_axi_rready   (m06_axi_rready),
        // ---- m07 (GPIO) ----
        .m07_axi_awid     (m07_axi_awid),    .m07_axi_awaddr   (m07_axi_awaddr),
        .m07_axi_awlen    (m07_axi_awlen),   .m07_axi_awsize   (m07_axi_awsize),
        .m07_axi_awburst  (m07_axi_awburst), .m07_axi_awlock   (m07_axi_awlock),
        .m07_axi_awcache  (m07_axi_awcache), .m07_axi_awprot   (m07_axi_awprot),
        .m07_axi_awqos    (m07_axi_awqos),   .m07_axi_awregion (m07_axi_awregion),
        .m07_axi_awuser   (m07_axi_awuser),  .m07_axi_awvalid  (m07_axi_awvalid),
        .m07_axi_awready  (m07_axi_awready),
        .m07_axi_wdata    (m07_axi_wdata),   .m07_axi_wstrb    (m07_axi_wstrb),
        .m07_axi_wlast    (m07_axi_wlast),   .m07_axi_wuser    (m07_axi_wuser),
        .m07_axi_wvalid   (m07_axi_wvalid),  .m07_axi_wready   (m07_axi_wready),
        .m07_axi_bid      (m07_axi_bid),     .m07_axi_bresp    (m07_axi_bresp),
        .m07_axi_buser    (m07_axi_buser),   .m07_axi_bvalid   (m07_axi_bvalid),
        .m07_axi_bready   (m07_axi_bready),
        .m07_axi_arid     (m07_axi_arid),    .m07_axi_araddr   (m07_axi_araddr),
        .m07_axi_arlen    (m07_axi_arlen),   .m07_axi_arsize   (m07_axi_arsize),
        .m07_axi_arburst  (m07_axi_arburst), .m07_axi_arlock   (m07_axi_arlock),
        .m07_axi_arcache  (m07_axi_arcache), .m07_axi_arprot   (m07_axi_arprot),
        .m07_axi_arqos    (m07_axi_arqos),   .m07_axi_arregion (m07_axi_arregion),
        .m07_axi_aruser   (m07_axi_aruser),  .m07_axi_arvalid  (m07_axi_arvalid),
        .m07_axi_arready  (m07_axi_arready),
        .m07_axi_rid      (m07_axi_rid),     .m07_axi_rdata    (m07_axi_rdata),
        .m07_axi_rresp    (m07_axi_rresp),   .m07_axi_rlast    (m07_axi_rlast),
        .m07_axi_ruser    (m07_axi_ruser),   .m07_axi_rvalid   (m07_axi_rvalid),
        .m07_axi_rready   (m07_axi_rready)
    );

    // =========================================================================
    // Dummy slave instances  (one per master port)
    // =========================================================================

    // M00 – Instruction Memory
    axi_slave_dummy #(.DATA_WIDTH(DATA_WIDTH),.ADDR_WIDTH(ADDR_WIDTH),.ID_WIDTH(ID_WIDTH)) u_slave_m00 (
        .clk(clk),.rst(rst),
        .s_axi_awid(m00_axi_awid),.s_axi_awaddr(m00_axi_awaddr),.s_axi_awlen(m00_axi_awlen),
        .s_axi_awsize(m00_axi_awsize),.s_axi_awburst(m00_axi_awburst),.s_axi_awlock(m00_axi_awlock),
        .s_axi_awcache(m00_axi_awcache),.s_axi_awprot(m00_axi_awprot),.s_axi_awqos(m00_axi_awqos),
        .s_axi_awregion(m00_axi_awregion),.s_axi_awvalid(m00_axi_awvalid),.s_axi_awready(m00_axi_awready),
        .s_axi_wdata(m00_axi_wdata),.s_axi_wstrb(m00_axi_wstrb),.s_axi_wlast(m00_axi_wlast),
        .s_axi_wvalid(m00_axi_wvalid),.s_axi_wready(m00_axi_wready),
        .s_axi_bid(m00_axi_bid),.s_axi_bresp(m00_axi_bresp),.s_axi_bvalid(m00_axi_bvalid),
        .s_axi_bready(m00_axi_bready),
        .s_axi_arid(m00_axi_arid),.s_axi_araddr(m00_axi_araddr),.s_axi_arlen(m00_axi_arlen),
        .s_axi_arsize(m00_axi_arsize),.s_axi_arburst(m00_axi_arburst),.s_axi_arlock(m00_axi_arlock),
        .s_axi_arcache(m00_axi_arcache),.s_axi_arprot(m00_axi_arprot),.s_axi_arqos(m00_axi_arqos),
        .s_axi_arregion(m00_axi_arregion),.s_axi_arvalid(m00_axi_arvalid),.s_axi_arready(m00_axi_arready),
        .s_axi_rid(m00_axi_rid),.s_axi_rdata(m00_axi_rdata),.s_axi_rresp(m00_axi_rresp),
        .s_axi_rlast(m00_axi_rlast),.s_axi_rvalid(m00_axi_rvalid),.s_axi_rready(m00_axi_rready)
    );

    // M01 – Data Memory
    axi_slave_dummy #(.DATA_WIDTH(DATA_WIDTH),.ADDR_WIDTH(ADDR_WIDTH),.ID_WIDTH(ID_WIDTH)) u_slave_m01 (
        .clk(clk),.rst(rst),
        .s_axi_awid(m01_axi_awid),.s_axi_awaddr(m01_axi_awaddr),.s_axi_awlen(m01_axi_awlen),
        .s_axi_awsize(m01_axi_awsize),.s_axi_awburst(m01_axi_awburst),.s_axi_awlock(m01_axi_awlock),
        .s_axi_awcache(m01_axi_awcache),.s_axi_awprot(m01_axi_awprot),.s_axi_awqos(m01_axi_awqos),
        .s_axi_awregion(m01_axi_awregion),.s_axi_awvalid(m01_axi_awvalid),.s_axi_awready(m01_axi_awready),
        .s_axi_wdata(m01_axi_wdata),.s_axi_wstrb(m01_axi_wstrb),.s_axi_wlast(m01_axi_wlast),
        .s_axi_wvalid(m01_axi_wvalid),.s_axi_wready(m01_axi_wready),
        .s_axi_bid(m01_axi_bid),.s_axi_bresp(m01_axi_bresp),.s_axi_bvalid(m01_axi_bvalid),
        .s_axi_bready(m01_axi_bready),
        .s_axi_arid(m01_axi_arid),.s_axi_araddr(m01_axi_araddr),.s_axi_arlen(m01_axi_arlen),
        .s_axi_arsize(m01_axi_arsize),.s_axi_arburst(m01_axi_arburst),.s_axi_arlock(m01_axi_arlock),
        .s_axi_arcache(m01_axi_arcache),.s_axi_arprot(m01_axi_arprot),.s_axi_arqos(m01_axi_arqos),
        .s_axi_arregion(m01_axi_arregion),.s_axi_arvalid(m01_axi_arvalid),.s_axi_arready(m01_axi_arready),
        .s_axi_rid(m01_axi_rid),.s_axi_rdata(m01_axi_rdata),.s_axi_rresp(m01_axi_rresp),
        .s_axi_rlast(m01_axi_rlast),.s_axi_rvalid(m01_axi_rvalid),.s_axi_rready(m01_axi_rready)
    );

    // M02 – FIFO
    axi_slave_dummy #(.DATA_WIDTH(DATA_WIDTH),.ADDR_WIDTH(ADDR_WIDTH),.ID_WIDTH(ID_WIDTH)) u_slave_m02 (
        .clk(clk),.rst(rst),
        .s_axi_awid(m02_axi_awid),.s_axi_awaddr(m02_axi_awaddr),.s_axi_awlen(m02_axi_awlen),
        .s_axi_awsize(m02_axi_awsize),.s_axi_awburst(m02_axi_awburst),.s_axi_awlock(m02_axi_awlock),
        .s_axi_awcache(m02_axi_awcache),.s_axi_awprot(m02_axi_awprot),.s_axi_awqos(m02_axi_awqos),
        .s_axi_awregion(m02_axi_awregion),.s_axi_awvalid(m02_axi_awvalid),.s_axi_awready(m02_axi_awready),
        .s_axi_wdata(m02_axi_wdata),.s_axi_wstrb(m02_axi_wstrb),.s_axi_wlast(m02_axi_wlast),
        .s_axi_wvalid(m02_axi_wvalid),.s_axi_wready(m02_axi_wready),
        .s_axi_bid(m02_axi_bid),.s_axi_bresp(m02_axi_bresp),.s_axi_bvalid(m02_axi_bvalid),
        .s_axi_bready(m02_axi_bready),
        .s_axi_arid(m02_axi_arid),.s_axi_araddr(m02_axi_araddr),.s_axi_arlen(m02_axi_arlen),
        .s_axi_arsize(m02_axi_arsize),.s_axi_arburst(m02_axi_arburst),.s_axi_arlock(m02_axi_arlock),
        .s_axi_arcache(m02_axi_arcache),.s_axi_arprot(m02_axi_arprot),.s_axi_arqos(m02_axi_arqos),
        .s_axi_arregion(m02_axi_arregion),.s_axi_arvalid(m02_axi_arvalid),.s_axi_arready(m02_axi_arready),
        .s_axi_rid(m02_axi_rid),.s_axi_rdata(m02_axi_rdata),.s_axi_rresp(m02_axi_rresp),
        .s_axi_rlast(m02_axi_rlast),.s_axi_rvalid(m02_axi_rvalid),.s_axi_rready(m02_axi_rready)
    );

    // M03 – DMA Controller
    axi_slave_dummy #(.DATA_WIDTH(DATA_WIDTH),.ADDR_WIDTH(ADDR_WIDTH),.ID_WIDTH(ID_WIDTH)) u_slave_m03 (
        .clk(clk),.rst(rst),
        .s_axi_awid(m03_axi_awid),.s_axi_awaddr(m03_axi_awaddr),.s_axi_awlen(m03_axi_awlen),
        .s_axi_awsize(m03_axi_awsize),.s_axi_awburst(m03_axi_awburst),.s_axi_awlock(m03_axi_awlock),
        .s_axi_awcache(m03_axi_awcache),.s_axi_awprot(m03_axi_awprot),.s_axi_awqos(m03_axi_awqos),
        .s_axi_awregion(m03_axi_awregion),.s_axi_awvalid(m03_axi_awvalid),.s_axi_awready(m03_axi_awready),
        .s_axi_wdata(m03_axi_wdata),.s_axi_wstrb(m03_axi_wstrb),.s_axi_wlast(m03_axi_wlast),
        .s_axi_wvalid(m03_axi_wvalid),.s_axi_wready(m03_axi_wready),
        .s_axi_bid(m03_axi_bid),.s_axi_bresp(m03_axi_bresp),.s_axi_bvalid(m03_axi_bvalid),
        .s_axi_bready(m03_axi_bready),
        .s_axi_arid(m03_axi_arid),.s_axi_araddr(m03_axi_araddr),.s_axi_arlen(m03_axi_arlen),
        .s_axi_arsize(m03_axi_arsize),.s_axi_arburst(m03_axi_arburst),.s_axi_arlock(m03_axi_arlock),
        .s_axi_arcache(m03_axi_arcache),.s_axi_arprot(m03_axi_arprot),.s_axi_arqos(m03_axi_arqos),
        .s_axi_arregion(m03_axi_arregion),.s_axi_arvalid(m03_axi_arvalid),.s_axi_arready(m03_axi_arready),
        .s_axi_rid(m03_axi_rid),.s_axi_rdata(m03_axi_rdata),.s_axi_rresp(m03_axi_rresp),
        .s_axi_rlast(m03_axi_rlast),.s_axi_rvalid(m03_axi_rvalid),.s_axi_rready(m03_axi_rready)
    );

    // M04 – Interrupt Controller
    axi_slave_dummy #(.DATA_WIDTH(DATA_WIDTH),.ADDR_WIDTH(ADDR_WIDTH),.ID_WIDTH(ID_WIDTH)) u_slave_m04 (
        .clk(clk),.rst(rst),
        .s_axi_awid(m04_axi_awid),.s_axi_awaddr(m04_axi_awaddr),.s_axi_awlen(m04_axi_awlen),
        .s_axi_awsize(m04_axi_awsize),.s_axi_awburst(m04_axi_awburst),.s_axi_awlock(m04_axi_awlock),
        .s_axi_awcache(m04_axi_awcache),.s_axi_awprot(m04_axi_awprot),.s_axi_awqos(m04_axi_awqos),
        .s_axi_awregion(m04_axi_awregion),.s_axi_awvalid(m04_axi_awvalid),.s_axi_awready(m04_axi_awready),
        .s_axi_wdata(m04_axi_wdata),.s_axi_wstrb(m04_axi_wstrb),.s_axi_wlast(m04_axi_wlast),
        .s_axi_wvalid(m04_axi_wvalid),.s_axi_wready(m04_axi_wready),
        .s_axi_bid(m04_axi_bid),.s_axi_bresp(m04_axi_bresp),.s_axi_bvalid(m04_axi_bvalid),
        .s_axi_bready(m04_axi_bready),
        .s_axi_arid(m04_axi_arid),.s_axi_araddr(m04_axi_araddr),.s_axi_arlen(m04_axi_arlen),
        .s_axi_arsize(m04_axi_arsize),.s_axi_arburst(m04_axi_arburst),.s_axi_arlock(m04_axi_arlock),
        .s_axi_arcache(m04_axi_arcache),.s_axi_arprot(m04_axi_arprot),.s_axi_arqos(m04_axi_arqos),
        .s_axi_arregion(m04_axi_arregion),.s_axi_arvalid(m04_axi_arvalid),.s_axi_arready(m04_axi_arready),
        .s_axi_rid(m04_axi_rid),.s_axi_rdata(m04_axi_rdata),.s_axi_rresp(m04_axi_rresp),
        .s_axi_rlast(m04_axi_rlast),.s_axi_rvalid(m04_axi_rvalid),.s_axi_rready(m04_axi_rready)
    );

    // M05 – UART
    axi_slave_dummy #(.DATA_WIDTH(DATA_WIDTH),.ADDR_WIDTH(ADDR_WIDTH),.ID_WIDTH(ID_WIDTH)) u_slave_m05 (
        .clk(clk),.rst(rst),
        .s_axi_awid(m05_axi_awid),.s_axi_awaddr(m05_axi_awaddr),.s_axi_awlen(m05_axi_awlen),
        .s_axi_awsize(m05_axi_awsize),.s_axi_awburst(m05_axi_awburst),.s_axi_awlock(m05_axi_awlock),
        .s_axi_awcache(m05_axi_awcache),.s_axi_awprot(m05_axi_awprot),.s_axi_awqos(m05_axi_awqos),
        .s_axi_awregion(m05_axi_awregion),.s_axi_awvalid(m05_axi_awvalid),.s_axi_awready(m05_axi_awready),
        .s_axi_wdata(m05_axi_wdata),.s_axi_wstrb(m05_axi_wstrb),.s_axi_wlast(m05_axi_wlast),
        .s_axi_wvalid(m05_axi_wvalid),.s_axi_wready(m05_axi_wready),
        .s_axi_bid(m05_axi_bid),.s_axi_bresp(m05_axi_bresp),.s_axi_bvalid(m05_axi_bvalid),
        .s_axi_bready(m05_axi_bready),
        .s_axi_arid(m05_axi_arid),.s_axi_araddr(m05_axi_araddr),.s_axi_arlen(m05_axi_arlen),
        .s_axi_arsize(m05_axi_arsize),.s_axi_arburst(m05_axi_arburst),.s_axi_arlock(m05_axi_arlock),
        .s_axi_arcache(m05_axi_arcache),.s_axi_arprot(m05_axi_arprot),.s_axi_arqos(m05_axi_arqos),
        .s_axi_arregion(m05_axi_arregion),.s_axi_arvalid(m05_axi_arvalid),.s_axi_arready(m05_axi_arready),
        .s_axi_rid(m05_axi_rid),.s_axi_rdata(m05_axi_rdata),.s_axi_rresp(m05_axi_rresp),
        .s_axi_rlast(m05_axi_rlast),.s_axi_rvalid(m05_axi_rvalid),.s_axi_rready(m05_axi_rready)
    );

    // M06 – Timer
    axi_slave_dummy #(.DATA_WIDTH(DATA_WIDTH),.ADDR_WIDTH(ADDR_WIDTH),.ID_WIDTH(ID_WIDTH)) u_slave_m06 (
        .clk(clk),.rst(rst),
        .s_axi_awid(m06_axi_awid),.s_axi_awaddr(m06_axi_awaddr),.s_axi_awlen(m06_axi_awlen),
        .s_axi_awsize(m06_axi_awsize),.s_axi_awburst(m06_axi_awburst),.s_axi_awlock(m06_axi_awlock),
        .s_axi_awcache(m06_axi_awcache),.s_axi_awprot(m06_axi_awprot),.s_axi_awqos(m06_axi_awqos),
        .s_axi_awregion(m06_axi_awregion),.s_axi_awvalid(m06_axi_awvalid),.s_axi_awready(m06_axi_awready),
        .s_axi_wdata(m06_axi_wdata),.s_axi_wstrb(m06_axi_wstrb),.s_axi_wlast(m06_axi_wlast),
        .s_axi_wvalid(m06_axi_wvalid),.s_axi_wready(m06_axi_wready),
        .s_axi_bid(m06_axi_bid),.s_axi_bresp(m06_axi_bresp),.s_axi_bvalid(m06_axi_bvalid),
        .s_axi_bready(m06_axi_bready),
        .s_axi_arid(m06_axi_arid),.s_axi_araddr(m06_axi_araddr),.s_axi_arlen(m06_axi_arlen),
        .s_axi_arsize(m06_axi_arsize),.s_axi_arburst(m06_axi_arburst),.s_axi_arlock(m06_axi_arlock),
        .s_axi_arcache(m06_axi_arcache),.s_axi_arprot(m06_axi_arprot),.s_axi_arqos(m06_axi_arqos),
        .s_axi_arregion(m06_axi_arregion),.s_axi_arvalid(m06_axi_arvalid),.s_axi_arready(m06_axi_arready),
        .s_axi_rid(m06_axi_rid),.s_axi_rdata(m06_axi_rdata),.s_axi_rresp(m06_axi_rresp),
        .s_axi_rlast(m06_axi_rlast),.s_axi_rvalid(m06_axi_rvalid),.s_axi_rready(m06_axi_rready)
    );

    // M07 – GPIO
    axi_slave_dummy #(.DATA_WIDTH(DATA_WIDTH),.ADDR_WIDTH(ADDR_WIDTH),.ID_WIDTH(ID_WIDTH)) u_slave_m07 (
        .clk(clk),.rst(rst),
        .s_axi_awid(m07_axi_awid),.s_axi_awaddr(m07_axi_awaddr),.s_axi_awlen(m07_axi_awlen),
        .s_axi_awsize(m07_axi_awsize),.s_axi_awburst(m07_axi_awburst),.s_axi_awlock(m07_axi_awlock),
        .s_axi_awcache(m07_axi_awcache),.s_axi_awprot(m07_axi_awprot),.s_axi_awqos(m07_axi_awqos),
        .s_axi_awregion(m07_axi_awregion),.s_axi_awvalid(m07_axi_awvalid),.s_axi_awready(m07_axi_awready),
        .s_axi_wdata(m07_axi_wdata),.s_axi_wstrb(m07_axi_wstrb),.s_axi_wlast(m07_axi_wlast),
        .s_axi_wvalid(m07_axi_wvalid),.s_axi_wready(m07_axi_wready),
        .s_axi_bid(m07_axi_bid),.s_axi_bresp(m07_axi_bresp),.s_axi_bvalid(m07_axi_bvalid),
        .s_axi_bready(m07_axi_bready),
        .s_axi_arid(m07_axi_arid),.s_axi_araddr(m07_axi_araddr),.s_axi_arlen(m07_axi_arlen),
        .s_axi_arsize(m07_axi_arsize),.s_axi_arburst(m07_axi_arburst),.s_axi_arlock(m07_axi_arlock),
        .s_axi_arcache(m07_axi_arcache),.s_axi_arprot(m07_axi_arprot),.s_axi_arqos(m07_axi_arqos),
        .s_axi_arregion(m07_axi_arregion),.s_axi_arvalid(m07_axi_arvalid),.s_axi_arready(m07_axi_arready),
        .s_axi_rid(m07_axi_rid),.s_axi_rdata(m07_axi_rdata),.s_axi_rresp(m07_axi_rresp),
        .s_axi_rlast(m07_axi_rlast),.s_axi_rvalid(m07_axi_rvalid),.s_axi_rready(m07_axi_rready)
    );

    // =========================================================================
    // FSDB waveform dump (Verdi)
    // =========================================================================
    initial begin
        $fsdbDumpfile("inter.fsdb");
        $fsdbDumpvars(0, tb_axi_interconnect_wrap_2x8);
    end

    // =========================================================================
    // Shared task: AXI4 single-beat write  (AW + W simultaneous, then B)
    // =========================================================================
    task axi_write;
        input [ADDR_WIDTH-1:0]  addr;
        input [DATA_WIDTH-1:0]  data;
        input [ID_WIDTH-1:0]    txid;
        begin
            // ---- Drive AW and W channels together ----
            @(negedge clk);
            s00_axi_awid    = txid;
            s00_axi_awaddr  = addr;
            s00_axi_awlen   = 8'd0;        // single beat
            s00_axi_awsize  = 3'b010;      // 4 bytes
            s00_axi_awburst = 2'b01;       // INCR
            s00_axi_awlock  = 1'b0;
            s00_axi_awcache = 4'b0000;
            s00_axi_awprot  = 3'b000;
            s00_axi_awqos   = 4'b0000;
            s00_axi_awuser  = 1'b0;
            s00_axi_awvalid = 1'b1;

            s00_axi_wdata   = data;
            s00_axi_wstrb   = {STRB_WIDTH{1'b1}};
            s00_axi_wlast   = 1'b1;
            s00_axi_wuser   = 1'b0;
            s00_axi_wvalid  = 1'b1;
            s00_axi_bready  = 1'b1;

            // Wait for AW handshake
            @(posedge clk);
            while (!s00_axi_awready) @(posedge clk);
            @(negedge clk);
            s00_axi_awvalid = 1'b0;

            // Wait for W handshake (usually same cycle, but be safe)
            @(posedge clk);
            while (!s00_axi_wready) @(posedge clk);
            @(negedge clk);
            s00_axi_wvalid = 1'b0;
            s00_axi_wlast  = 1'b0;

            // Wait for B response
            @(posedge clk);
            while (!s00_axi_bvalid) @(posedge clk);
            @(negedge clk);
            s00_axi_bready = 1'b0;
        end
    endtask

    // =========================================================================
    // Shared task: AXI4 single-beat read  (AR, then R)
    // Returns read data in output register rdata_out
    // =========================================================================
    reg [DATA_WIDTH-1:0] rdata_out;

    task axi_read;
        input [ADDR_WIDTH-1:0]  addr;
        input [ID_WIDTH-1:0]    txid;
        begin
            @(negedge clk);
            s00_axi_arid    = txid;
            s00_axi_araddr  = addr;
            s00_axi_arlen   = 8'd0;
            s00_axi_arsize  = 3'b010;
            s00_axi_arburst = 2'b01;
            s00_axi_arlock  = 1'b0;
            s00_axi_arcache = 4'b0000;
            s00_axi_arprot  = 3'b000;
            s00_axi_arqos   = 4'b0000;
            s00_axi_aruser  = 1'b0;
            s00_axi_arvalid = 1'b1;
            s00_axi_rready  = 1'b1;

            // Wait for AR handshake
            @(posedge clk);
            while (!s00_axi_arready) @(posedge clk);
            @(negedge clk);
            s00_axi_arvalid = 1'b0;

            // Wait for R data
            @(posedge clk);
            while (!s00_axi_rvalid) @(posedge clk);
            rdata_out = s00_axi_rdata;
            @(negedge clk);
            s00_axi_rready = 1'b0;
        end
    endtask

    // =========================================================================
    // Main stimulus
    // =========================================================================
    integer pass_count;
    integer fail_count;

    initial begin
        // ----- Reset all master-side outputs -----
        rst             = 1'b1;
        pass_count      = 0;
        fail_count      = 0;

        s00_axi_awid    = {ID_WIDTH{1'b0}};
        s00_axi_awaddr  = {ADDR_WIDTH{1'b0}};
        s00_axi_awlen   = 8'd0;
        s00_axi_awsize  = 3'b010;
        s00_axi_awburst = 2'b01;
        s00_axi_awlock  = 1'b0;
        s00_axi_awcache = 4'b0000;
        s00_axi_awprot  = 3'b000;
        s00_axi_awqos   = 4'b0000;
        s00_axi_awuser  = 1'b0;
        s00_axi_awvalid = 1'b0;
        s00_axi_wdata   = {DATA_WIDTH{1'b0}};
        s00_axi_wstrb   = {STRB_WIDTH{1'b1}};
        s00_axi_wlast   = 1'b0;
        s00_axi_wuser   = 1'b0;
        s00_axi_wvalid  = 1'b0;
        s00_axi_bready  = 1'b0;
        s00_axi_arid    = {ID_WIDTH{1'b0}};
        s00_axi_araddr  = {ADDR_WIDTH{1'b0}};
        s00_axi_arlen   = 8'd0;
        s00_axi_arsize  = 3'b010;
        s00_axi_arburst = 2'b01;
        s00_axi_arlock  = 1'b0;
        s00_axi_arcache = 4'b0000;
        s00_axi_arprot  = 3'b000;
        s00_axi_arqos   = 4'b0000;
        s00_axi_aruser  = 1'b0;
        s00_axi_arvalid = 1'b0;
        s00_axi_rready  = 1'b0;

        // Hold reset for 5 clock cycles
        repeat(5) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        // Allow one idle cycle after de-reset
        repeat(2) @(posedge clk);

        // =====================================================================
        // WRITE TRANSACTION 1 – FIFO  (0x2000_0000)  data = 0xDEAD_BEEF
        // =====================================================================
        $display("[%0t ns] WRITE 1: addr=0x%08h  data=0x%08h  → FIFO (M02)",
                 $time, ADDR_FIFO, 32'hDEAD_BEEF);
        axi_write(ADDR_FIFO, 32'hDEAD_BEEF, 8'h01);
        $display("[%0t ns] WRITE 1 COMPLETE: bresp=%0b", $time, s00_axi_bresp);

        // =====================================================================
        // WRITE TRANSACTION 2 – DMA Controller  (0x3000_0000)  data = 0xCAFE_BABE
        // =====================================================================
        $display("[%0t ns] WRITE 2: addr=0x%08h  data=0x%08h  → DMA Controller (M03)",
                 $time, ADDR_DMA, 32'hCAFE_BABE);
        axi_write(ADDR_DMA, 32'hCAFE_BABE, 8'h02);
        $display("[%0t ns] WRITE 2 COMPLETE: bresp=%0b", $time, s00_axi_bresp);

        // =====================================================================
        // WRITE TRANSACTION 3 – Interrupt Controller  (0x4000_0000)  data = 0x1234_5678
        // =====================================================================
        $display("[%0t ns] WRITE 3: addr=0x%08h  data=0x%08h  → Interrupt Controller (M04)",
                 $time, ADDR_INTCTL, 32'h1234_5678);
        axi_write(ADDR_INTCTL, 32'h1234_5678, 8'h03);
        $display("[%0t ns] WRITE 3 COMPLETE: bresp=%0b", $time, s00_axi_bresp);

        // Give the interconnect two idle cycles between writes and reads
        repeat(4) @(posedge clk);

        // =====================================================================
        // READ TRANSACTION 1 – FIFO  (0x2000_0000)  expected = 0xDEAD_BEEF
        // =====================================================================
        $display("[%0t ns] READ  1: addr=0x%08h  → FIFO (M02)",
                 $time, ADDR_FIFO);
        axi_read(ADDR_FIFO, 8'h11);
        $display("[%0t ns] READ  1 COMPLETE: rdata=0x%08h  expected=0x%08h  %s",
                 $time, rdata_out, 32'hDEAD_BEEF,
                 (rdata_out === 32'hDEAD_BEEF) ? "PASS" : "FAIL");
        if (rdata_out === 32'hDEAD_BEEF) pass_count = pass_count + 1;
        else                             fail_count = fail_count + 1;

        // =====================================================================
        // READ TRANSACTION 2 – DMA Controller  (0x3000_0000)  expected = 0xCAFE_BABE
        // =====================================================================
        $display("[%0t ns] READ  2: addr=0x%08h  → DMA Controller (M03)",
                 $time, ADDR_DMA);
        axi_read(ADDR_DMA, 8'h12);
        $display("[%0t ns] READ  2 COMPLETE: rdata=0x%08h  expected=0x%08h  %s",
                 $time, rdata_out, 32'hCAFE_BABE,
                 (rdata_out === 32'hCAFE_BABE) ? "PASS" : "FAIL");
        if (rdata_out === 32'hCAFE_BABE) pass_count = pass_count + 1;
        else                             fail_count = fail_count + 1;

        // =====================================================================
        // READ TRANSACTION 3 – Interrupt Controller  (0x4000_0000)  expected = 0x1234_5678
        // =====================================================================
        $display("[%0t ns] READ  3: addr=0x%08h  → Interrupt Controller (M04)",
                 $time, ADDR_INTCTL);
        axi_read(ADDR_INTCTL, 8'h13);
        $display("[%0t ns] READ  3 COMPLETE: rdata=0x%08h  expected=0x%08h  %s",
                 $time, rdata_out, 32'h1234_5678,
                 (rdata_out === 32'h1234_5678) ? "PASS" : "FAIL");
        if (rdata_out === 32'h1234_5678) pass_count = pass_count + 1;
        else                             fail_count = fail_count + 1;

        // =====================================================================
        // Summary
        // =====================================================================
        $display("------------------------------------------------------------");
        $display("SIMULATION COMPLETE: %0d PASSED / %0d FAILED", pass_count, fail_count);
        if (fail_count == 0)
            $display("*** ALL TESTS PASSED ***");
        else
            $display("*** SOME TESTS FAILED – check waveform in inter.fsdb ***");
        $display("------------------------------------------------------------");

        $finish;
    end

    // =========================================================================
    // Watchdog – abort if simulation hangs for more than 10 000 cycles
    // =========================================================================
    initial begin
        #(CLK_PERIOD * 10000);
        $display("WATCHDOG TIMEOUT at %0t ns – simulation did not complete in time.", $time);
        $finish;
    end

endmodule

`default_nettype wire
