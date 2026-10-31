// =============================================================================
// File        : dma_axi_master_wrapper.sv
// Project     : RISC-V VeeR EL2 Based Real-Time Data Buffering SoC
// Description : Wrapper around dma_top's AXI4 master port that adds the
//               missing AWID / ARID / BID / RID signals so it can connect
//               directly to axi_interconnect_wrap_2x8 slave port s01.
//
// ┌─────────────────────────────────────────────────────────────────────┐
// │  PROBLEM BEING SOLVED                                               │
// │                                                                     │
// │  dma_top.m_axi_* is a stripped AXI4 master — it outputs the five  │
// │  AXI channels but omits the ID sideband signals (AWID, ARID, BID, │
// │  RID).  The interconnect's s01 slave port expects ID signals that  │
// │  are ID_WIDTH = 8 bits wide.                                        │
// │                                                                     │
// │  Solution: tie AWID and ARID to 8'b0 on the way out; accept BID   │
// │  and RID from the interconnect and discard them (the DMA does not  │
// │  use out-of-order IDs).                                             │
// │                                                                     │
// │  All other AXI4 signals (AWADDR, AWLEN, AWSIZE, AWBURST, WDATA,   │
// │  WSTRB, WLAST, BVALID, BREADY, BRESP, ARADDR, ARLEN, ARSIZE,      │
// │  ARBURST, RVALID, RREADY, RDATA, RRESP, RLAST) pass through        │
// │  unchanged.                                                         │
// │                                                                     │
// │  The sideband signals that the DMA does NOT drive (AWLOCK,         │
// │  AWCACHE, AWPROT, AWQOS, AWREGION, ARLOCK, ARCACHE, ARPROT, ARQOS,│
// │  ARREGION) are tied to safe default values.                         │
// └─────────────────────────────────────────────────────────────────────┘
//
// Clocking : single synchronous clock domain.
// Reset    : srst — active-HIGH synchronous (matches dma_top and
//            axi_interconnect_wrap_2x8).
// =============================================================================

`default_nettype none
`timescale 1ns / 1ps

module dma_axi_master_wrapper #(
    parameter int DATA_W          = 32,
    parameter int ADDR_W          = 32,
    parameter int INTERCONNECT_ID = 8,    // ID_WIDTH of axi_interconnect_wrap_2x8
    parameter int NUM_CH          = 4,
    parameter int MAX_BURST_LEN   = 16,
    parameter     ARB_MODE        = "ROUND_ROBIN"
) (
    input  logic                    clk,
    input  logic                    srst,       // active-HIGH synchronous

    // =========================================================================
    // CPU register-access port (from AXI4→reg adapter, m03_axi_* side)
    // =========================================================================
    input  logic                    reg_wr_en,
    input  logic                    reg_rd_en,
    input  logic [11:0]             reg_addr,
    input  logic [DATA_W-1:0]       reg_wr_data,
    output logic [DATA_W-1:0]       reg_rd_data,
    output logic                    reg_rd_valid,

    // =========================================================================
    // AXI4 Master — connects to axi_interconnect_wrap_2x8  s01_axi_*
    // ID signals are added here; all other signals pass through.
    // =========================================================================

    // Write address channel
    output logic [INTERCONNECT_ID-1:0] m_axi_awid,
    output logic [ADDR_W-1:0]          m_axi_awaddr,
    output logic [7:0]                 m_axi_awlen,
    output logic [2:0]                 m_axi_awsize,
    output logic [1:0]                 m_axi_awburst,
    output logic                       m_axi_awlock,
    output logic [3:0]                 m_axi_awcache,
    output logic [2:0]                 m_axi_awprot,
    output logic [3:0]                 m_axi_awqos,
    output logic                       m_axi_awvalid,
    input  logic                       m_axi_awready,

    // Write data channel
    output logic [DATA_W-1:0]          m_axi_wdata,
    output logic [DATA_W/8-1:0]        m_axi_wstrb,
    output logic                       m_axi_wlast,
    output logic                       m_axi_wvalid,
    input  logic                       m_axi_wready,

    // Write response channel
    input  logic [INTERCONNECT_ID-1:0] m_axi_bid,      // from interconnect, ignored
    input  logic [1:0]                 m_axi_bresp,
    input  logic                       m_axi_bvalid,
    output logic                       m_axi_bready,

    // Read address channel
    output logic [INTERCONNECT_ID-1:0] m_axi_arid,
    output logic [ADDR_W-1:0]          m_axi_araddr,
    output logic [7:0]                 m_axi_arlen,
    output logic [2:0]                 m_axi_arsize,
    output logic [1:0]                 m_axi_arburst,
    output logic                       m_axi_arlock,
    output logic [3:0]                 m_axi_arcache,
    output logic [2:0]                 m_axi_arprot,
    output logic [3:0]                 m_axi_arqos,
    output logic                       m_axi_arvalid,
    input  logic                       m_axi_arready,

    // Read data channel
    input  logic [INTERCONNECT_ID-1:0] m_axi_rid,      // from interconnect, ignored
    input  logic [DATA_W-1:0]          m_axi_rdata,
    input  logic [1:0]                 m_axi_rresp,
    input  logic                       m_axi_rlast,
    input  logic                       m_axi_rvalid,
    output logic                       m_axi_rready,

    // =========================================================================
    // Peripheral DMA-request handshake  (passed through to dma_top)
    // =========================================================================
    input  logic [NUM_CH-1:0]          dreq,
    output logic [NUM_CH-1:0]          dack,

    // =========================================================================
    // Interrupt output
    // =========================================================================
    output logic                       irq
);

    // -------------------------------------------------------------------------
    // Internal wires that connect to dma_top's stripped AXI master port
    // -------------------------------------------------------------------------
    logic                    dma_awvalid;
    logic                    dma_awready;
    logic [ADDR_W-1:0]       dma_awaddr;
    logic [7:0]              dma_awlen;
    logic [2:0]              dma_awsize;
    logic [1:0]              dma_awburst;

    logic                    dma_wvalid;
    logic                    dma_wready;
    logic [DATA_W-1:0]       dma_wdata;
    logic [DATA_W/8-1:0]     dma_wstrb;
    logic                    dma_wlast;

    logic                    dma_bvalid;
    logic                    dma_bready;
    logic [1:0]              dma_bresp;

    logic                    dma_arvalid;
    logic                    dma_arready;
    logic [ADDR_W-1:0]       dma_araddr;
    logic [7:0]              dma_arlen;
    logic [2:0]              dma_arsize;
    logic [1:0]              dma_arburst;

    logic                    dma_rvalid;
    logic                    dma_rready;
    logic [DATA_W-1:0]       dma_rdata;
    logic [1:0]              dma_rresp;
    logic                    dma_rlast;

    // -------------------------------------------------------------------------
    // Instantiate dma_top
    // -------------------------------------------------------------------------
    dma_top #(
        .NUM_CH       (NUM_CH),
        .DATA_W       (DATA_W),
        .ADDR_W       (ADDR_W),
        .MAX_BURST_LEN(MAX_BURST_LEN),
        .ARB_MODE     (ARB_MODE)
    ) u_dma (
        .clk           (clk),
        .srst          (srst),

        // CPU register interface
        .reg_wr_en     (reg_wr_en),
        .reg_rd_en     (reg_rd_en),
        .reg_addr      (reg_addr),
        .reg_wr_data   (reg_wr_data),
        .reg_rd_data   (reg_rd_data),
        .reg_rd_valid  (reg_rd_valid),

        // AXI4 master (stripped — no ID ports)
        .m_axi_awvalid (dma_awvalid),
        .m_axi_awready (dma_awready),
        .m_axi_awaddr  (dma_awaddr),
        .m_axi_awlen   (dma_awlen),
        .m_axi_awsize  (dma_awsize),
        .m_axi_awburst (dma_awburst),

        .m_axi_wvalid  (dma_wvalid),
        .m_axi_wready  (dma_wready),
        .m_axi_wdata   (dma_wdata),
        .m_axi_wstrb   (dma_wstrb),
        .m_axi_wlast   (dma_wlast),

        .m_axi_bvalid  (dma_bvalid),
        .m_axi_bready  (dma_bready),
        .m_axi_bresp   (dma_bresp),

        .m_axi_arvalid (dma_arvalid),
        .m_axi_arready (dma_arready),
        .m_axi_araddr  (dma_araddr),
        .m_axi_arlen   (dma_arlen),
        .m_axi_arsize  (dma_arsize),
        .m_axi_arburst (dma_arburst),

        .m_axi_rvalid  (dma_rvalid),
        .m_axi_rready  (dma_rready),
        .m_axi_rdata   (dma_rdata),
        .m_axi_rresp   (dma_rresp),
        .m_axi_rlast   (dma_rlast),

        // Peripheral handshake
        .dreq          (dreq),
        .dack          (dack),

        // Interrupt
        .irq           (irq)
    );

    // =========================================================================
    //  ID tie-offs and pass-through
    //
    //  DMA always uses ID=0 (it issues one transaction at a time through its
    //  internal arbiter, so out-of-order IDs are not needed).
    //  The interconnect's BID/RID are accepted and silently discarded.
    // =========================================================================

    // Write address channel — add AWID=0, tie optional sideband signals
    assign m_axi_awid    = {INTERCONNECT_ID{1'b0}};
    assign m_axi_awaddr  = dma_awaddr;
    assign m_axi_awlen   = dma_awlen;
    assign m_axi_awsize  = dma_awsize;
    assign m_axi_awburst = dma_awburst;
    assign m_axi_awlock  = 1'b0;        // normal access
    assign m_axi_awcache = 4'b0000;     // non-cacheable, non-bufferable
    assign m_axi_awprot  = 3'b000;      // normal, non-secure, data
    assign m_axi_awqos   = 4'b0000;
    assign m_axi_awvalid = dma_awvalid;
    assign dma_awready   = m_axi_awready;

    // Write data channel — pass through unchanged
    assign m_axi_wdata   = dma_wdata;
    assign m_axi_wstrb   = dma_wstrb;
    assign m_axi_wlast   = dma_wlast;
    assign m_axi_wvalid  = dma_wvalid;
    assign dma_wready    = m_axi_wready;

    // Write response channel — BID from interconnect is ignored (DMA has only one ID)
    assign dma_bvalid    = m_axi_bvalid;
    assign m_axi_bready  = dma_bready;
    assign dma_bresp     = m_axi_bresp;
    // m_axi_bid is an input (from interconnect) — declared in port list; unused

    // Read address channel — add ARID=0, tie optional sideband signals
    assign m_axi_arid    = {INTERCONNECT_ID{1'b0}};
    assign m_axi_araddr  = dma_araddr;
    assign m_axi_arlen   = dma_arlen;
    assign m_axi_arsize  = dma_arsize;
    assign m_axi_arburst = dma_arburst;
    assign m_axi_arlock  = 1'b0;
    assign m_axi_arcache = 4'b0000;
    assign m_axi_arprot  = 3'b000;
    assign m_axi_arqos   = 4'b0000;
    assign m_axi_arvalid = dma_arvalid;
    assign dma_arready   = m_axi_arready;

    // Read data channel — RID from interconnect is ignored
    assign dma_rvalid    = m_axi_rvalid;
    assign m_axi_rready  = dma_rready;
    assign dma_rdata     = m_axi_rdata;
    assign dma_rresp     = m_axi_rresp;
    assign dma_rlast     = m_axi_rlast;

endmodule

`default_nettype wire
