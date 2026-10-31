// =============================================================================
// File        : soc_data_buffering_top.sv
// Project     : RISC-V VeeR EL2 Based Real-Time Data Buffering SoC (Project A)
// Description : Top-Level System-on-Chip integrating:
//                 - 32-bit RV32IMC VeeR EL2 RISC-V Core (with ICCM/DCCM)
//                 - AXI4 64-to-32 LSU Adapter
//                 - AXI4 2x8 Interconnect (axi_interconnect_wrap_2x8)
//                 - 4-Channel Scatter-Gather DMA Controller (dma_top + wrapper)
//                 - Real-Time Data Buffering FIFO with Stream Input (axi_data_buffer_fifo)
//                 - Platform-Level Interrupt Controller (plic_top + adapter)
//                 - AXI-Lite UART IP Core (axi_uart_top + adapter)
//                 - 64 KiB Instruction Memory (axi_ram)
//                 - Synthesizable 32-bit Timer Peripheral (axi_timer)
//                 - Synthesizable 32-bit GPIO Peripheral (axi_gpio)
//
// Memory Map (16 MiB aperture per slave port):
//   0x0000_0000 - 0x00FF_FFFF : S0 - Instruction Memory (IMEM, 64 KiB SRAM)
//   0x1000_0000 - 0x10FF_FFFF : S1 - Data Memory (DMEM, 64 KiB SRAM)
//   0x2000_0000 - 0x20FF_FFFF : S2 - UART Controller
//   0x3000_0000 - 0x30FF_FFFF : S3 - Timer Peripheral
//   0x4000_0000 - 0x40FF_FFFF : S4 - GPIO Peripheral
//   0x5000_0000 - 0x50FF_FFFF : S5 - Real-Time Data Buffer FIFO (Registers & Data)
//   0x6000_0000 - 0x60FF_FFFF : S6 - DMA Controller Configuration Registers
//   0x7000_0000 - 0x70FF_FFFF : S7 - Interrupt Controller (PLIC)
//
// Reset       : rst_l - active-LOW asynchronous / synchronous (VeeR convention).
//               Internal synchronous active-HIGH rst = ~rst_l generated for IPs.
// =============================================================================

`default_nettype none
`timescale 1ns / 1ps

`include "common_defines.vh"

module soc_data_buffering_top
import el2_pkg::*;
#(
    parameter int DATA_WIDTH          = 32,
    parameter int ADDR_WIDTH          = 32,
    parameter int ID_WIDTH            = 8,
    parameter int CPU_TAG_WIDTH       = 4,
    parameter int FIFO_DEPTH          = 64,
    parameter int MEM_ADDR_WIDTH      = 16,     // 64 KiB
    parameter int DMA_NUM_CH          = 4,
    parameter int PLIC_NUM_SOURCES    = 32,
    parameter int PLIC_NUM_TARGETS    = 2,
    parameter bit ENABLE_INTERNAL_CPU = 1'b1
) (
    input  logic                     clk,
    input  logic                     rst_l,     // Active-LOW master reset

    // =========================================================================
    // External Sensor Streaming Sample Interface (Hardware input to FIFO)
    // =========================================================================
    input  logic                     sample_stream_valid,
    input  logic [31:0]              sample_stream_data,
    output logic                     sample_stream_ready,

    // =========================================================================
    // External Serial UART Interface
    // =========================================================================
    output logic                     uart_tx,
    input  logic                     uart_rx,

    // =========================================================================
    // Interrupt and Status Observation Outputs
    // =========================================================================
    output logic                     fifo_irq_o,
    output logic                     dma_irq_o,
    output logic                     uart_irq_o,
    output logic                     timer_irq_o,
    output logic [PLIC_NUM_TARGETS-1:0] cpu_eip_o,

    // =========================================================================
    // External GPIO Physical Pins
    // =========================================================================
    input  logic [31:0]              gpio_i = 32'b0,
    output logic [31:0]              gpio_o,
    output logic [31:0]              gpio_oe,

    // =========================================================================
    // Optional Direct Bus Master Injection (active when ENABLE_INTERNAL_CPU = 0)
    // =========================================================================
    input  logic [ID_WIDTH-1:0]      ext_s00_axi_awid,
    input  logic [ADDR_WIDTH-1:0]    ext_s00_axi_awaddr,
    input  logic [7:0]               ext_s00_axi_awlen,
    input  logic [2:0]               ext_s00_axi_awsize,
    input  logic [1:0]               ext_s00_axi_awburst,
    input  logic                     ext_s00_axi_awvalid,
    output logic                     ext_s00_axi_awready,
    input  logic [DATA_WIDTH-1:0]    ext_s00_axi_wdata,
    input  logic [DATA_WIDTH/8-1:0]  ext_s00_axi_wstrb,
    input  logic                     ext_s00_axi_wlast,
    input  logic                     ext_s00_axi_wvalid,
    output logic                     ext_s00_axi_wready,
    output logic [ID_WIDTH-1:0]      ext_s00_axi_bid,
    output logic [1:0]               ext_s00_axi_bresp,
    output logic                     ext_s00_axi_bvalid,
    input  logic                     ext_s00_axi_bready,
    input  logic [ID_WIDTH-1:0]      ext_s00_axi_arid,
    input  logic [ADDR_WIDTH-1:0]    ext_s00_axi_araddr,
    input  logic [7:0]               ext_s00_axi_arlen,
    input  logic [2:0]               ext_s00_axi_arsize,
    input  logic [1:0]               ext_s00_axi_arburst,
    input  logic                     ext_s00_axi_arvalid,
    output logic                     ext_s00_axi_arready,
    output logic [ID_WIDTH-1:0]      ext_s00_axi_rid,
    output logic [DATA_WIDTH-1:0]    ext_s00_axi_rdata,
    output logic [1:0]               ext_s00_axi_rresp,
    output logic                     ext_s00_axi_rlast,
    output logic                     ext_s00_axi_rvalid,
    input  logic                     ext_s00_axi_rready
);

    // -------------------------------------------------------------------------
    // Reset inversion for synchronous active-HIGH peripherals
    // -------------------------------------------------------------------------
    logic rst;
    assign rst = ~rst_l;

    // -------------------------------------------------------------------------
    // Interrupt lines
    // -------------------------------------------------------------------------
    logic                    fifo_irq;
    logic                    dma_irq;
    logic                    uart_irq;
    logic                    timer_irq;
    logic [PLIC_NUM_SOURCES:1] plic_irq_sources;
    logic [PLIC_NUM_TARGETS-1:0] plic_eip;

    assign fifo_irq_o  = fifo_irq;
    assign dma_irq_o   = dma_irq;
    assign uart_irq_o  = uart_irq;
    assign timer_irq_o = timer_irq;
    assign cpu_eip_o   = plic_eip;

    always_comb begin
        plic_irq_sources    = '0;
        plic_irq_sources[1] = dma_irq;
        plic_irq_sources[2] = fifo_irq;
        plic_irq_sources[3] = uart_irq;
        plic_irq_sources[4] = timer_irq;
    end

    // -------------------------------------------------------------------------
    // DMA Hardware Handshake
    // -------------------------------------------------------------------------
    logic [DMA_NUM_CH-1:0] dma_dreq;
    logic [DMA_NUM_CH-1:0] dma_dack;

    logic fifo_dreq;
    logic fifo_dack;

    assign dma_dreq[0] = fifo_dreq;
    assign dma_dreq[DMA_NUM_CH-1:1] = '0;
    assign fifo_dack   = dma_dack[0];

    // =========================================================================
    // Interconnect Ports
    // =========================================================================

    // Slave Port s00 (CPU LSU or External Master)
    logic [ID_WIDTH-1:0]      s00_axi_awid;
    logic [ADDR_WIDTH-1:0]    s00_axi_awaddr;
    logic [7:0]               s00_axi_awlen;
    logic [2:0]               s00_axi_awsize;
    logic [1:0]               s00_axi_awburst;
    logic                     s00_axi_awlock;
    logic [3:0]               s00_axi_awcache;
    logic [2:0]               s00_axi_awprot;
    logic [3:0]               s00_axi_awqos;
    logic [3:0]               s00_axi_awregion;
    logic                     s00_axi_awvalid;
    logic                     s00_axi_awready;

    logic [DATA_WIDTH-1:0]    s00_axi_wdata;
    logic [DATA_WIDTH/8-1:0]  s00_axi_wstrb;
    logic                     s00_axi_wlast;
    logic                     s00_axi_wvalid;
    logic                     s00_axi_wready;

    logic [ID_WIDTH-1:0]      s00_axi_bid;
    logic [1:0]               s00_axi_bresp;
    logic                     s00_axi_bvalid;
    logic                     s00_axi_bready;

    logic [ID_WIDTH-1:0]      s00_axi_arid;
    logic [ADDR_WIDTH-1:0]    s00_axi_araddr;
    logic [7:0]               s00_axi_arlen;
    logic [2:0]               s00_axi_arsize;
    logic [1:0]               s00_axi_arburst;
    logic                     s00_axi_arlock;
    logic [3:0]               s00_axi_arcache;
    logic [2:0]               s00_axi_arprot;
    logic [3:0]               s00_axi_arqos;
    logic [3:0]               s00_axi_arregion;
    logic                     s00_axi_arvalid;
    logic                     s00_axi_arready;

    logic [ID_WIDTH-1:0]      s00_axi_rid;
    logic [DATA_WIDTH-1:0]    s00_axi_rdata;
    logic [1:0]               s00_axi_rresp;
    logic                     s00_axi_rlast;
    logic                     s00_axi_rvalid;
    logic                     s00_axi_rready;

    // Slave Port s01 (DMA Master)
    logic [ID_WIDTH-1:0]      s01_axi_awid;
    logic [ADDR_WIDTH-1:0]    s01_axi_awaddr;
    logic [7:0]               s01_axi_awlen;
    logic [2:0]               s01_axi_awsize;
    logic [1:0]               s01_axi_awburst;
    logic                     s01_axi_awlock;
    logic [3:0]               s01_axi_awcache;
    logic [2:0]               s01_axi_awprot;
    logic [3:0]               s01_axi_awqos;
    logic                     s01_axi_awvalid;
    logic                     s01_axi_awready;

    logic [DATA_WIDTH-1:0]    s01_axi_wdata;
    logic [DATA_WIDTH/8-1:0]  s01_axi_wstrb;
    logic                     s01_axi_wlast;
    logic                     s01_axi_wvalid;
    logic                     s01_axi_wready;

    logic [ID_WIDTH-1:0]      s01_axi_bid;
    logic [1:0]               s01_axi_bresp;
    logic                     s01_axi_bvalid;
    logic                     s01_axi_bready;

    logic [ID_WIDTH-1:0]      s01_axi_arid;
    logic [ADDR_WIDTH-1:0]    s01_axi_araddr;
    logic [7:0]               s01_axi_arlen;
    logic [2:0]               s01_axi_arsize;
    logic [1:0]               s01_axi_arburst;
    logic                     s01_axi_arlock;
    logic [3:0]               s01_axi_arcache;
    logic [2:0]               s01_axi_arprot;
    logic [3:0]               s01_axi_arqos;
    logic                     s01_axi_arvalid;
    logic                     s01_axi_arready;

    logic [ID_WIDTH-1:0]      s01_axi_rid;
    logic [DATA_WIDTH-1:0]    s01_axi_rdata;
    logic [1:0]               s01_axi_rresp;
    logic                     s01_axi_rlast;
    logic                     s01_axi_rvalid;
    logic                     s01_axi_rready;

    // Master Ports m00 - m07
    // M00: IMEM
    logic [ID_WIDTH-1:0]      m00_axi_awid;
    logic [ADDR_WIDTH-1:0]    m00_axi_awaddr;
    logic [7:0]               m00_axi_awlen;
    logic [2:0]               m00_axi_awsize;
    logic [1:0]               m00_axi_awburst;
    logic                     m00_axi_awlock;
    logic [3:0]               m00_axi_awcache;
    logic [2:0]               m00_axi_awprot;
    logic                     m00_axi_awvalid;
    logic                     m00_axi_awready;
    logic [DATA_WIDTH-1:0]    m00_axi_wdata;
    logic [DATA_WIDTH/8-1:0]  m00_axi_wstrb;
    logic                     m00_axi_wlast;
    logic                     m00_axi_wvalid;
    logic                     m00_axi_wready;
    logic [ID_WIDTH-1:0]      m00_axi_bid;
    logic [1:0]               m00_axi_bresp;
    logic                     m00_axi_bvalid;
    logic                     m00_axi_bready;
    logic [ID_WIDTH-1:0]      m00_axi_arid;
    logic [ADDR_WIDTH-1:0]    m00_axi_araddr;
    logic [7:0]               m00_axi_arlen;
    logic [2:0]               m00_axi_arsize;
    logic [1:0]               m00_axi_arburst;
    logic                     m00_axi_arlock;
    logic [3:0]               m00_axi_arcache;
    logic [2:0]               m00_axi_arprot;
    logic                     m00_axi_arvalid;
    logic                     m00_axi_arready;
    logic [ID_WIDTH-1:0]      m00_axi_rid;
    logic [DATA_WIDTH-1:0]    m00_axi_rdata;
    logic [1:0]               m00_axi_rresp;
    logic                     m00_axi_rlast;
    logic                     m00_axi_rvalid;
    logic                     m00_axi_rready;

    // M01: DMEM
    logic [ID_WIDTH-1:0]      m01_axi_awid;
    logic [ADDR_WIDTH-1:0]    m01_axi_awaddr;
    logic [7:0]               m01_axi_awlen;
    logic [2:0]               m01_axi_awsize;
    logic [1:0]               m01_axi_awburst;
    logic                     m01_axi_awlock;
    logic [3:0]               m01_axi_awcache;
    logic [2:0]               m01_axi_awprot;
    logic                     m01_axi_awvalid;
    logic                     m01_axi_awready;
    logic [DATA_WIDTH-1:0]    m01_axi_wdata;
    logic [DATA_WIDTH/8-1:0]  m01_axi_wstrb;
    logic                     m01_axi_wlast;
    logic                     m01_axi_wvalid;
    logic                     m01_axi_wready;
    logic [ID_WIDTH-1:0]      m01_axi_bid;
    logic [1:0]               m01_axi_bresp;
    logic                     m01_axi_bvalid;
    logic                     m01_axi_bready;
    logic [ID_WIDTH-1:0]      m01_axi_arid;
    logic [ADDR_WIDTH-1:0]    m01_axi_araddr;
    logic [7:0]               m01_axi_arlen;
    logic [2:0]               m01_axi_arsize;
    logic [1:0]               m01_axi_arburst;
    logic                     m01_axi_arlock;
    logic [3:0]               m01_axi_arcache;
    logic [2:0]               m01_axi_arprot;
    logic                     m01_axi_arvalid;
    logic                     m01_axi_arready;
    logic [ID_WIDTH-1:0]      m01_axi_rid;
    logic [DATA_WIDTH-1:0]    m01_axi_rdata;
    logic [1:0]               m01_axi_rresp;
    logic                     m01_axi_rlast;
    logic                     m01_axi_rvalid;
    logic                     m01_axi_rready;

    // M02: FIFO
    logic [ID_WIDTH-1:0]      m02_axi_awid;
    logic [ADDR_WIDTH-1:0]    m02_axi_awaddr;
    logic [7:0]               m02_axi_awlen;
    logic [2:0]               m02_axi_awsize;
    logic [1:0]               m02_axi_awburst;
    logic                     m02_axi_awlock;
    logic [3:0]               m02_axi_awcache;
    logic [2:0]               m02_axi_awprot;
    logic [3:0]               m02_axi_awqos;
    logic [3:0]               m02_axi_awregion;
    logic                     m02_axi_awvalid;
    logic                     m02_axi_awready;
    logic [DATA_WIDTH-1:0]    m02_axi_wdata;
    logic [DATA_WIDTH/8-1:0]  m02_axi_wstrb;
    logic                     m02_axi_wlast;
    logic                     m02_axi_wvalid;
    logic                     m02_axi_wready;
    logic [ID_WIDTH-1:0]      m02_axi_bid;
    logic [1:0]               m02_axi_bresp;
    logic                     m02_axi_bvalid;
    logic                     m02_axi_bready;
    logic [ID_WIDTH-1:0]      m02_axi_arid;
    logic [ADDR_WIDTH-1:0]    m02_axi_araddr;
    logic [7:0]               m02_axi_arlen;
    logic [2:0]               m02_axi_arsize;
    logic [1:0]               m02_axi_arburst;
    logic                     m02_axi_arlock;
    logic [3:0]               m02_axi_arcache;
    logic [2:0]               m02_axi_arprot;
    logic [3:0]               m02_axi_arqos;
    logic [3:0]               m02_axi_arregion;
    logic                     m02_axi_arvalid;
    logic                     m02_axi_arready;
    logic [ID_WIDTH-1:0]      m02_axi_rid;
    logic [DATA_WIDTH-1:0]    m02_axi_rdata;
    logic [1:0]               m02_axi_rresp;
    logic                     m02_axi_rlast;
    logic                     m02_axi_rvalid;
    logic                     m02_axi_rready;

    // M03: DMA Regs
    logic [ID_WIDTH-1:0]      m03_axi_awid;
    logic [ADDR_WIDTH-1:0]    m03_axi_awaddr;
    logic [7:0]               m03_axi_awlen;
    logic [2:0]               m03_axi_awsize;
    logic [1:0]               m03_axi_awburst;
    logic                     m03_axi_awlock;
    logic [3:0]               m03_axi_awcache;
    logic [2:0]               m03_axi_awprot;
    logic [3:0]               m03_axi_awqos;
    logic [3:0]               m03_axi_awregion;
    logic                     m03_axi_awvalid;
    logic                     m03_axi_awready;
    logic [DATA_WIDTH-1:0]    m03_axi_wdata;
    logic [DATA_WIDTH/8-1:0]  m03_axi_wstrb;
    logic                     m03_axi_wlast;
    logic                     m03_axi_wvalid;
    logic                     m03_axi_wready;
    logic [ID_WIDTH-1:0]      m03_axi_bid;
    logic [1:0]               m03_axi_bresp;
    logic                     m03_axi_bvalid;
    logic                     m03_axi_bready;
    logic [ID_WIDTH-1:0]      m03_axi_arid;
    logic [ADDR_WIDTH-1:0]    m03_axi_araddr;
    logic [7:0]               m03_axi_arlen;
    logic [2:0]               m03_axi_arsize;
    logic [1:0]               m03_axi_arburst;
    logic                     m03_axi_arlock;
    logic [3:0]               m03_axi_arcache;
    logic [2:0]               m03_axi_arprot;
    logic [3:0]               m03_axi_arqos;
    logic [3:0]               m03_axi_arregion;
    logic                     m03_axi_arvalid;
    logic                     m03_axi_arready;
    logic [ID_WIDTH-1:0]      m03_axi_rid;
    logic [DATA_WIDTH-1:0]    m03_axi_rdata;
    logic [1:0]               m03_axi_rresp;
    logic                     m03_axi_rlast;
    logic                     m03_axi_rvalid;
    logic                     m03_axi_rready;

    // M04: PLIC
    logic [ID_WIDTH-1:0]      m04_axi_awid;
    logic [ADDR_WIDTH-1:0]    m04_axi_awaddr;
    logic [7:0]               m04_axi_awlen;
    logic [2:0]               m04_axi_awsize;
    logic [1:0]               m04_axi_awburst;
    logic                     m04_axi_awlock;
    logic [3:0]               m04_axi_awcache;
    logic [2:0]               m04_axi_awprot;
    logic [3:0]               m04_axi_awqos;
    logic [3:0]               m04_axi_awregion;
    logic                     m04_axi_awvalid;
    logic                     m04_axi_awready;
    logic [DATA_WIDTH-1:0]    m04_axi_wdata;
    logic [DATA_WIDTH/8-1:0]  m04_axi_wstrb;
    logic                     m04_axi_wlast;
    logic                     m04_axi_wvalid;
    logic                     m04_axi_wready;
    logic [ID_WIDTH-1:0]      m04_axi_bid;
    logic [1:0]               m04_axi_bresp;
    logic                     m04_axi_bvalid;
    logic                     m04_axi_bready;
    logic [ID_WIDTH-1:0]      m04_axi_arid;
    logic [ADDR_WIDTH-1:0]    m04_axi_araddr;
    logic [7:0]               m04_axi_arlen;
    logic [2:0]               m04_axi_arsize;
    logic [1:0]               m04_axi_arburst;
    logic                     m04_axi_arlock;
    logic [3:0]               m04_axi_arcache;
    logic [2:0]               m04_axi_arprot;
    logic [3:0]               m04_axi_arqos;
    logic [3:0]               m04_axi_arregion;
    logic                     m04_axi_arvalid;
    logic                     m04_axi_arready;
    logic [ID_WIDTH-1:0]      m04_axi_rid;
    logic [DATA_WIDTH-1:0]    m04_axi_rdata;
    logic [1:0]               m04_axi_rresp;
    logic                     m04_axi_rlast;
    logic                     m04_axi_rvalid;
    logic                     m04_axi_rready;

    // M05: UART
    logic [ID_WIDTH-1:0]      m05_axi_awid;
    logic [ADDR_WIDTH-1:0]    m05_axi_awaddr;
    logic [7:0]               m05_axi_awlen;
    logic [2:0]               m05_axi_awsize;
    logic [1:0]               m05_axi_awburst;
    logic                     m05_axi_awlock;
    logic [3:0]               m05_axi_awcache;
    logic [2:0]               m05_axi_awprot;
    logic [3:0]               m05_axi_awqos;
    logic [3:0]               m05_axi_awregion;
    logic                     m05_axi_awvalid;
    logic                     m05_axi_awready;
    logic [DATA_WIDTH-1:0]    m05_axi_wdata;
    logic [DATA_WIDTH/8-1:0]  m05_axi_wstrb;
    logic                     m05_axi_wlast;
    logic                     m05_axi_wvalid;
    logic                     m05_axi_wready;
    logic [ID_WIDTH-1:0]      m05_axi_bid;
    logic [1:0]               m05_axi_bresp;
    logic                     m05_axi_bvalid;
    logic                     m05_axi_bready;
    logic [ID_WIDTH-1:0]      m05_axi_arid;
    logic [ADDR_WIDTH-1:0]    m05_axi_araddr;
    logic [7:0]               m05_axi_arlen;
    logic [2:0]               m05_axi_arsize;
    logic [1:0]               m05_axi_arburst;
    logic                     m05_axi_arlock;
    logic [3:0]               m05_axi_arcache;
    logic [2:0]               m05_axi_arprot;
    logic [3:0]               m05_axi_arqos;
    logic [3:0]               m05_axi_arregion;
    logic                     m05_axi_arvalid;
    logic                     m05_axi_arready;
    logic [ID_WIDTH-1:0]      m05_axi_rid;
    logic [DATA_WIDTH-1:0]    m05_axi_rdata;
    logic [1:0]               m05_axi_rresp;
    logic                     m05_axi_rlast;
    logic                     m05_axi_rvalid;
    logic                     m05_axi_rready;

    // M06: Timer (Dummy Responder)
    logic [ID_WIDTH-1:0]      m06_axi_awid;
    logic [ADDR_WIDTH-1:0]    m06_axi_awaddr;
    logic [7:0]               m06_axi_awlen;
    logic [2:0]               m06_axi_awsize;
    logic [1:0]               m06_axi_awburst;
    logic                     m06_axi_awlock;
    logic [3:0]               m06_axi_awcache;
    logic [2:0]               m06_axi_awprot;
    logic [3:0]               m06_axi_awqos;
    logic [3:0]               m06_axi_awregion;
    logic                     m06_axi_awvalid;
    logic                     m06_axi_awready;
    logic [DATA_WIDTH-1:0]    m06_axi_wdata;
    logic [DATA_WIDTH/8-1:0]  m06_axi_wstrb;
    logic                     m06_axi_wlast;
    logic                     m06_axi_wvalid;
    logic                     m06_axi_wready;
    logic [ID_WIDTH-1:0]      m06_axi_bid;
    logic [1:0]               m06_axi_bresp;
    logic                     m06_axi_bvalid;
    logic                     m06_axi_bready;
    logic [ID_WIDTH-1:0]      m06_axi_arid;
    logic [ADDR_WIDTH-1:0]    m06_axi_araddr;
    logic [7:0]               m06_axi_arlen;
    logic [2:0]               m06_axi_arsize;
    logic [1:0]               m06_axi_arburst;
    logic                     m06_axi_arlock;
    logic [3:0]               m06_axi_arcache;
    logic [2:0]               m06_axi_arprot;
    logic [3:0]               m06_axi_arqos;
    logic [3:0]               m06_axi_arregion;
    logic                     m06_axi_arvalid;
    logic                     m06_axi_arready;
    logic [ID_WIDTH-1:0]      m06_axi_rid;
    logic [DATA_WIDTH-1:0]    m06_axi_rdata;
    logic [1:0]               m06_axi_rresp;
    logic                     m06_axi_rlast;
    logic                     m06_axi_rvalid;
    logic                     m06_axi_rready;

    // M07: GPIO (Dummy Responder)
    logic [ID_WIDTH-1:0]      m07_axi_awid;
    logic [ADDR_WIDTH-1:0]    m07_axi_awaddr;
    logic [7:0]               m07_axi_awlen;
    logic [2:0]               m07_axi_awsize;
    logic [1:0]               m07_axi_awburst;
    logic                     m07_axi_awlock;
    logic [3:0]               m07_axi_awcache;
    logic [2:0]               m07_axi_awprot;
    logic [3:0]               m07_axi_awqos;
    logic [3:0]               m07_axi_awregion;
    logic                     m07_axi_awvalid;
    logic                     m07_axi_awready;
    logic [DATA_WIDTH-1:0]    m07_axi_wdata;
    logic [DATA_WIDTH/8-1:0]  m07_axi_wstrb;
    logic                     m07_axi_wlast;
    logic                     m07_axi_wvalid;
    logic                     m07_axi_wready;
    logic [ID_WIDTH-1:0]      m07_axi_bid;
    logic [1:0]               m07_axi_bresp;
    logic                     m07_axi_bvalid;
    logic                     m07_axi_bready;
    logic [ID_WIDTH-1:0]      m07_axi_arid;
    logic [ADDR_WIDTH-1:0]    m07_axi_araddr;
    logic [7:0]               m07_axi_arlen;
    logic [2:0]               m07_axi_arsize;
    logic [1:0]               m07_axi_arburst;
    logic                     m07_axi_arlock;
    logic [3:0]               m07_axi_arcache;
    logic [2:0]               m07_axi_arprot;
    logic [3:0]               m07_axi_arqos;
    logic [3:0]               m07_axi_arregion;
    logic                     m07_axi_arvalid;
    logic                     m07_axi_arready;
    logic [ID_WIDTH-1:0]      m07_axi_rid;
    logic [DATA_WIDTH-1:0]    m07_axi_rdata;
    logic [1:0]               m07_axi_rresp;
    logic                     m07_axi_rlast;
    logic                     m07_axi_rvalid;
    logic                     m07_axi_rready;

    // =========================================================================
    // CPU LSU 64-bit to 32-bit Adapter Connections
    // =========================================================================
    logic                            cpu_lsu_awvalid;
    logic                            cpu_lsu_awready;
    logic [CPU_TAG_WIDTH-1:0]        cpu_lsu_awid;
    logic [31:0]                     cpu_lsu_awaddr;
    logic [3:0]                      cpu_lsu_awregion;
    logic [7:0]                      cpu_lsu_awlen;
    logic [2:0]                      cpu_lsu_awsize;
    logic [1:0]                      cpu_lsu_awburst;
    logic                            cpu_lsu_awlock;
    logic [3:0]                      cpu_lsu_awcache;
    logic [2:0]                      cpu_lsu_awprot;
    logic [3:0]                      cpu_lsu_awqos;

    logic                            cpu_lsu_wvalid;
    logic                            cpu_lsu_wready;
    logic [63:0]                     cpu_lsu_wdata;
    logic [7:0]                      cpu_lsu_wstrb;
    logic                            cpu_lsu_wlast;

    logic                            cpu_lsu_bvalid;
    logic                            cpu_lsu_bready;
    logic [1:0]                      cpu_lsu_bresp;
    logic [CPU_TAG_WIDTH-1:0]        cpu_lsu_bid;

    logic                            cpu_lsu_arvalid;
    logic                            cpu_lsu_arready;
    logic [CPU_TAG_WIDTH-1:0]        cpu_lsu_arid;
    logic [31:0]                     cpu_lsu_araddr;
    logic [3:0]                      cpu_lsu_arregion;
    logic [7:0]                      cpu_lsu_arlen;
    logic [2:0]                      cpu_lsu_arsize;
    logic [1:0]                      cpu_lsu_arburst;
    logic                            cpu_lsu_arlock;
    logic [3:0]                      cpu_lsu_arcache;
    logic [2:0]                      cpu_lsu_arprot;
    logic [3:0]                      cpu_lsu_arqos;

    logic                            cpu_lsu_rvalid;
    logic                            cpu_lsu_rready;
    logic [CPU_TAG_WIDTH-1:0]        cpu_lsu_rid;
    logic [63:0]                     cpu_lsu_rdata;
    logic [1:0]                      cpu_lsu_rresp;
    logic                            cpu_lsu_rlast;

    // Wires from adapter to s00
    logic [ID_WIDTH-1:0]      adp_s00_awid;
    logic [ADDR_WIDTH-1:0]    adp_s00_awaddr;
    logic [7:0]               adp_s00_awlen;
    logic [2:0]               adp_s00_awsize;
    logic [1:0]               adp_s00_awburst;
    logic                     adp_s00_awlock;
    logic [3:0]               adp_s00_awcache;
    logic [2:0]               adp_s00_awprot;
    logic [3:0]               adp_s00_awqos;
    logic [3:0]               adp_s00_awregion;
    assign adp_s00_awregion = 4'b0;
    logic                     adp_s00_awvalid;
    logic                     adp_s00_awready;

    logic [DATA_WIDTH-1:0]    adp_s00_wdata;
    logic [DATA_WIDTH/8-1:0]  adp_s00_wstrb;
    logic                     adp_s00_wlast;
    logic                     adp_s00_wvalid;
    logic                     adp_s00_wready;

    logic [ID_WIDTH-1:0]      adp_s00_bid;
    logic [1:0]               adp_s00_bresp;
    logic                     adp_s00_bvalid;
    logic                     adp_s00_bready;

    logic [ID_WIDTH-1:0]      adp_s00_arid;
    logic [ADDR_WIDTH-1:0]    adp_s00_araddr;
    logic [7:0]               adp_s00_arlen;
    logic [2:0]               adp_s00_arsize;
    logic [1:0]               adp_s00_arburst;
    logic                     adp_s00_arlock;
    logic [3:0]               adp_s00_arcache;
    logic [2:0]               adp_s00_arprot;
    logic [3:0]               adp_s00_arqos;
    logic [3:0]               adp_s00_arregion;
    assign adp_s00_arregion = 4'b0;
    logic                     adp_s00_arvalid;
    logic                     adp_s00_arready;

    logic [ID_WIDTH-1:0]      adp_s00_rid;
    logic [DATA_WIDTH-1:0]    adp_s00_rdata;
    logic [1:0]               adp_s00_rresp;
    logic                     adp_s00_rlast;
    logic                     adp_s00_rvalid;
    logic                     adp_s00_rready;

    // Selection between internal CPU LSU adapter and external direct bus injection
    generate
        if (ENABLE_INTERNAL_CPU) begin : gen_internal_cpu_bus
            assign s00_axi_awid     = adp_s00_awid;
            assign s00_axi_awaddr   = adp_s00_awaddr;
            assign s00_axi_awlen    = adp_s00_awlen;
            assign s00_axi_awsize   = adp_s00_awsize;
            assign s00_axi_awburst  = adp_s00_awburst;
            assign s00_axi_awlock   = adp_s00_awlock;
            assign s00_axi_awcache  = adp_s00_awcache;
            assign s00_axi_awprot   = adp_s00_awprot;
            assign s00_axi_awqos    = adp_s00_awqos;
            assign s00_axi_awregion = adp_s00_awregion;
            assign s00_axi_awvalid  = adp_s00_awvalid;
            assign adp_s00_awready  = s00_axi_awready;

            assign s00_axi_wdata    = adp_s00_wdata;
            assign s00_axi_wstrb    = adp_s00_wstrb;
            assign s00_axi_wlast    = adp_s00_wlast;
            assign s00_axi_wvalid   = adp_s00_wvalid;
            assign adp_s00_wready   = s00_axi_wready;

            assign adp_s00_bid      = s00_axi_bid;
            assign adp_s00_bresp    = s00_axi_bresp;
            assign adp_s00_bvalid   = s00_axi_bvalid;
            assign s00_axi_bready   = adp_s00_bready;

            assign s00_axi_arid     = adp_s00_arid;
            assign s00_axi_araddr   = adp_s00_araddr;
            assign s00_axi_arlen    = adp_s00_arlen;
            assign s00_axi_arsize   = adp_s00_arsize;
            assign s00_axi_arburst  = adp_s00_arburst;
            assign s00_axi_arlock   = adp_s00_arlock;
            assign s00_axi_arcache  = adp_s00_arcache;
            assign s00_axi_arprot   = adp_s00_arprot;
            assign s00_axi_arqos    = adp_s00_arqos;
            assign s00_axi_arregion = adp_s00_arregion;
            assign s00_axi_arvalid  = adp_s00_arvalid;
            assign adp_s00_arready  = s00_axi_arready;

            assign adp_s00_rid      = s00_axi_rid;
            assign adp_s00_rdata    = s00_axi_rdata;
            assign adp_s00_rresp    = s00_axi_rresp;
            assign adp_s00_rlast    = s00_axi_rlast;
            assign adp_s00_rvalid   = s00_axi_rvalid;
            assign s00_axi_rready   = adp_s00_rready;

            assign ext_s00_axi_awready = 1'b0;
            assign ext_s00_axi_wready  = 1'b0;
            assign ext_s00_axi_bid     = '0;
            assign ext_s00_axi_bresp   = 2'b10;
            assign ext_s00_axi_bvalid  = 1'b0;
            assign ext_s00_axi_arready = 1'b0;
            assign ext_s00_axi_rid     = '0;
            assign ext_s00_axi_rdata   = '0;
            assign ext_s00_axi_rresp   = 2'b10;
            assign ext_s00_axi_rlast   = 1'b0;
            assign ext_s00_axi_rvalid  = 1'b0;
        end else begin : gen_external_bus
            assign s00_axi_awid     = ext_s00_axi_awid;
            assign s00_axi_awaddr   = ext_s00_axi_awaddr;
            assign s00_axi_awlen    = ext_s00_axi_awlen;
            assign s00_axi_awsize   = ext_s00_axi_awsize;
            assign s00_axi_awburst  = ext_s00_axi_awburst;
            assign s00_axi_awlock   = 1'b0;
            assign s00_axi_awcache  = 4'b0;
            assign s00_axi_awprot   = 3'b0;
            assign s00_axi_awqos    = 4'b0;
            assign s00_axi_awregion = 4'b0;
            assign s00_axi_awvalid  = ext_s00_axi_awvalid;
            assign ext_s00_axi_awready = s00_axi_awready;

            assign s00_axi_wdata    = ext_s00_axi_wdata;
            assign s00_axi_wstrb    = ext_s00_axi_wstrb;
            assign s00_axi_wlast    = ext_s00_axi_wlast;
            assign s00_axi_wvalid   = ext_s00_axi_wvalid;
            assign ext_s00_axi_wready  = s00_axi_wready;

            assign ext_s00_axi_bid  = s00_axi_bid;
            assign ext_s00_axi_bresp= s00_axi_bresp;
            assign ext_s00_axi_bvalid= s00_axi_bvalid;
            assign s00_axi_bready   = ext_s00_axi_bready;

            assign s00_axi_arid     = ext_s00_axi_arid;
            assign s00_axi_araddr   = ext_s00_axi_araddr;
            assign s00_axi_arlen    = ext_s00_axi_arlen;
            assign s00_axi_arsize   = ext_s00_axi_arsize;
            assign s00_axi_arburst  = ext_s00_axi_arburst;
            assign s00_axi_arlock   = 1'b0;
            assign s00_axi_arcache  = 4'b0;
            assign s00_axi_arprot   = 3'b0;
            assign s00_axi_arqos    = 4'b0;
            assign s00_axi_arregion = 4'b0;
            assign s00_axi_arvalid  = ext_s00_axi_arvalid;
            assign ext_s00_axi_arready = s00_axi_arready;

            assign ext_s00_axi_rid  = s00_axi_rid;
            assign ext_s00_axi_rdata= s00_axi_rdata;
            assign ext_s00_axi_rresp= s00_axi_rresp;
            assign ext_s00_axi_rlast= s00_axi_rlast;
            assign ext_s00_axi_rvalid= s00_axi_rvalid;
            assign s00_axi_rready   = ext_s00_axi_rready;

            assign adp_s00_awready = 1'b0;
            assign adp_s00_wready  = 1'b0;
            assign adp_s00_bid     = '0;
            assign adp_s00_bresp   = 2'b10;
            assign adp_s00_bvalid  = 1'b0;
            assign adp_s00_arready = 1'b0;
            assign adp_s00_rid     = '0;
            assign adp_s00_rdata   = '0;
            assign adp_s00_rresp   = 2'b10;
            assign adp_s00_rlast   = 1'b0;
            assign adp_s00_rvalid  = 1'b0;
        end
    endgenerate

    // -------------------------------------------------------------------------
    // Instantiate 64-to-32 AXI Adapter for CPU LSU
    // -------------------------------------------------------------------------
    axi4_64_to_32_adapter #(
        .SLAVE_ID_WIDTH (CPU_TAG_WIDTH),
        .MASTER_ID_WIDTH(ID_WIDTH),
        .ADDR_WIDTH     (ADDR_WIDTH)
    ) u_lsu_adapter (
        .clk            (clk),
        .rst_l          (rst_l),

        // Slave side (from CPU LSU)
        .s_axi_awid     (cpu_lsu_awid),
        .s_axi_awaddr   (cpu_lsu_awaddr),
        .s_axi_awlen    (cpu_lsu_awlen),
        .s_axi_awsize   (cpu_lsu_awsize),
        .s_axi_awburst  (cpu_lsu_awburst),
        .s_axi_awlock   (cpu_lsu_awlock),
        .s_axi_awcache  (cpu_lsu_awcache),
        .s_axi_awprot   (cpu_lsu_awprot),
        .s_axi_awqos    (cpu_lsu_awqos),
        .s_axi_awregion (cpu_lsu_awregion),
        .s_axi_awvalid  (cpu_lsu_awvalid),
        .s_axi_awready  (cpu_lsu_awready),

        .s_axi_wdata    (cpu_lsu_wdata),
        .s_axi_wstrb    (cpu_lsu_wstrb),
        .s_axi_wlast    (cpu_lsu_wlast),
        .s_axi_wvalid   (cpu_lsu_wvalid),
        .s_axi_wready   (cpu_lsu_wready),

        .s_axi_bid      (cpu_lsu_bid),
        .s_axi_bresp    (cpu_lsu_bresp),
        .s_axi_bvalid   (cpu_lsu_bvalid),
        .s_axi_bready   (cpu_lsu_bready),

        .s_axi_arid     (cpu_lsu_arid),
        .s_axi_araddr   (cpu_lsu_araddr),
        .s_axi_arlen    (cpu_lsu_arlen),
        .s_axi_arsize   (cpu_lsu_arsize),
        .s_axi_arburst  (cpu_lsu_arburst),
        .s_axi_arlock   (cpu_lsu_arlock),
        .s_axi_arcache  (cpu_lsu_arcache),
        .s_axi_arprot   (cpu_lsu_arprot),
        .s_axi_arqos    (cpu_lsu_arqos),
        .s_axi_arregion (cpu_lsu_arregion),
        .s_axi_arvalid  (cpu_lsu_arvalid),
        .s_axi_arready  (cpu_lsu_arready),

        .s_axi_rid      (cpu_lsu_rid),
        .s_axi_rdata    (cpu_lsu_rdata),
        .s_axi_rresp    (cpu_lsu_rresp),
        .s_axi_rlast    (cpu_lsu_rlast),
        .s_axi_rvalid   (cpu_lsu_rvalid),
        .s_axi_rready   (cpu_lsu_rready),

        // Master side (to s00)
        .m_axi_awid     (adp_s00_awid),
        .m_axi_awaddr   (adp_s00_awaddr),
        .m_axi_awlen    (adp_s00_awlen),
        .m_axi_awsize   (adp_s00_awsize),
        .m_axi_awburst  (adp_s00_awburst),
        .m_axi_awlock   (adp_s00_awlock),
        .m_axi_awcache  (adp_s00_awcache),
        .m_axi_awprot   (adp_s00_awprot),
        .m_axi_awqos    (adp_s00_awqos),
        .m_axi_awvalid  (adp_s00_awvalid),
        .m_axi_awready  (adp_s00_awready),

        .m_axi_wdata    (adp_s00_wdata),
        .m_axi_wstrb    (adp_s00_wstrb),
        .m_axi_wlast    (adp_s00_wlast),
        .m_axi_wvalid   (adp_s00_wvalid),
        .m_axi_wready   (adp_s00_wready),

        .m_axi_bid      (adp_s00_bid),
        .m_axi_bresp    (adp_s00_bresp),
        .m_axi_bvalid   (adp_s00_bvalid),
        .m_axi_bready   (adp_s00_bready),

        .m_axi_arid     (adp_s00_arid),
        .m_axi_araddr   (adp_s00_araddr),
        .m_axi_arlen    (adp_s00_arlen),
        .m_axi_arsize   (adp_s00_arsize),
        .m_axi_arburst  (adp_s00_arburst),
        .m_axi_arlock   (adp_s00_arlock),
        .m_axi_arcache  (adp_s00_arcache),
        .m_axi_arprot   (adp_s00_arprot),
        .m_axi_arqos    (adp_s00_arqos),
        .m_axi_arvalid  (adp_s00_arvalid),
        .m_axi_arready  (adp_s00_arready),

        .m_axi_rid      (adp_s00_rid),
        .m_axi_rdata    (adp_s00_rdata),
        .m_axi_rresp    (adp_s00_rresp),
        .m_axi_rlast    (adp_s00_rlast),
        .m_axi_rvalid   (adp_s00_rvalid),
        .m_axi_rready   (adp_s00_rready)
    );

    // -------------------------------------------------------------------------
    // Instantiate VeeR EL2 Processor Core
    // -------------------------------------------------------------------------
    generate
        if (ENABLE_INTERNAL_CPU) begin : gen_veer_core
            el2_mem_if el2_mem_export();
            el2_mem_if el2_icache_export();

            el2_veer_wrapper u_cpu (
                .clk                    (clk),
                .rst_l                  (rst_l),
                .dbg_rst_l              (rst_l),
                .rst_vec                (31'h7700_0000), // Boot address: 0xEE00_0000 (ICCM)
                .nmi_int                (1'b0),
                .nmi_vec                (31'h0000_0000),
                .jtag_id                (31'h0000_0001),

                // Trace interface
                .trace_rv_i_insn_ip     (),
                .trace_rv_i_address_ip  (),
                .trace_rv_i_valid_ip    (),
                .trace_rv_i_exception_ip(),
                .trace_rv_i_ecause_ip   (),
                .trace_rv_i_interrupt_ip(),
                .trace_rv_i_tval_ip     (),

                // LSU AXI4 Master Port
                .lsu_axi_awvalid        (cpu_lsu_awvalid),
                .lsu_axi_awready        (cpu_lsu_awready),
                .lsu_axi_awid           (cpu_lsu_awid),
                .lsu_axi_awaddr         (cpu_lsu_awaddr),
                .lsu_axi_awregion       (cpu_lsu_awregion),
                .lsu_axi_awlen          (cpu_lsu_awlen),
                .lsu_axi_awsize         (cpu_lsu_awsize),
                .lsu_axi_awburst        (cpu_lsu_awburst),
                .lsu_axi_awlock         (cpu_lsu_awlock),
                .lsu_axi_awcache        (cpu_lsu_awcache),
                .lsu_axi_awprot         (cpu_lsu_awprot),
                .lsu_axi_awqos          (cpu_lsu_awqos),

                .lsu_axi_wvalid         (cpu_lsu_wvalid),
                .lsu_axi_wready         (cpu_lsu_wready),
                .lsu_axi_wdata          (cpu_lsu_wdata),
                .lsu_axi_wstrb          (cpu_lsu_wstrb),
                .lsu_axi_wlast          (cpu_lsu_wlast),

                .lsu_axi_bvalid         (cpu_lsu_bvalid),
                .lsu_axi_bready         (cpu_lsu_bready),
                .lsu_axi_bresp          (cpu_lsu_bresp),
                .lsu_axi_bid            (cpu_lsu_bid),

                .lsu_axi_arvalid        (cpu_lsu_arvalid),
                .lsu_axi_arready        (cpu_lsu_arready),
                .lsu_axi_arid           (cpu_lsu_arid),
                .lsu_axi_araddr         (cpu_lsu_araddr),
                .lsu_axi_arregion       (cpu_lsu_arregion),
                .lsu_axi_arlen          (cpu_lsu_arlen),
                .lsu_axi_arsize         (cpu_lsu_arsize),
                .lsu_axi_arburst        (cpu_lsu_arburst),
                .lsu_axi_arlock         (cpu_lsu_arlock),
                .lsu_axi_arcache        (cpu_lsu_arcache),
                .lsu_axi_arprot         (cpu_lsu_arprot),
                .lsu_axi_arqos          (cpu_lsu_arqos),

                .lsu_axi_rvalid         (cpu_lsu_rvalid),
                .lsu_axi_rready         (cpu_lsu_rready),
                .lsu_axi_rid            (cpu_lsu_rid),
                .lsu_axi_rdata          (cpu_lsu_rdata),
                .lsu_axi_rresp          (cpu_lsu_rresp),
                .lsu_axi_rlast          (cpu_lsu_rlast),

                // IFU AXI Master (tie-offs for external IFU since instructions run from ICCM)
                .ifu_axi_awvalid        (),
                .ifu_axi_awready        (1'b0),
                .ifu_axi_awid           (),
                .ifu_axi_awaddr         (),
                .ifu_axi_awregion       (),
                .ifu_axi_awlen          (),
                .ifu_axi_awsize         (),
                .ifu_axi_awburst        (),
                .ifu_axi_awlock         (),
                .ifu_axi_awcache        (),
                .ifu_axi_awprot         (),
                .ifu_axi_awqos          (),

                .ifu_axi_wvalid         (),
                .ifu_axi_wready         (1'b0),
                .ifu_axi_wdata          (),
                .ifu_axi_wstrb          (),
                .ifu_axi_wlast          (),

                .ifu_axi_bvalid         (1'b0),
                .ifu_axi_bready         (),
                .ifu_axi_bresp          (2'b00),
                .ifu_axi_bid            ('0),

                .ifu_axi_arvalid        (),
                .ifu_axi_arready        (1'b0),
                .ifu_axi_arid           (),
                .ifu_axi_araddr         (),
                .ifu_axi_arregion       (),
                .ifu_axi_arlen          (),
                .ifu_axi_arsize         (),
                .ifu_axi_arburst        (),
                .ifu_axi_arlock         (),
                .ifu_axi_arcache        (),
                .ifu_axi_arprot         (),
                .ifu_axi_arqos          (),

                .ifu_axi_rvalid         (1'b0),
                .ifu_axi_rready         (),
                .ifu_axi_rid            ('0),
                .ifu_axi_rdata          ('0),
                .ifu_axi_rresp          (2'b00),
                .ifu_axi_rlast          (1'b0),

                // System Bus / DMA slave into core
                .dma_axi_awvalid        (1'b0),
                .dma_axi_awready        (),
                .dma_axi_awid           ('0),
                .dma_axi_awaddr         ('0),
                .dma_axi_awsize         (3'b010),
                .dma_axi_awprot         (3'b000),
                .dma_axi_awlen          (8'b0),
                .dma_axi_awburst        (2'b01),
                .dma_axi_wvalid         (1'b0),
                .dma_axi_wready         (),
                .dma_axi_wdata          ('0),
                .dma_axi_wstrb          ('0),
                .dma_axi_wlast          (1'b0),
                .dma_axi_bvalid         (),
                .dma_axi_bready         (1'b1),
                .dma_axi_bresp          (),
                .dma_axi_bid            (),
                .dma_axi_arvalid        (1'b0),
                .dma_axi_arready        (),
                .dma_axi_arid           ('0),
                .dma_axi_araddr         ('0),
                .dma_axi_arsize         (3'b010),
                .dma_axi_arprot         (3'b000),
                .dma_axi_arlen          (8'b0),
                .dma_axi_arburst        (2'b01),
                .dma_axi_rvalid         (),
                .dma_axi_rready         (1'b1),
                .dma_axi_rid            (),
                .dma_axi_rdata          (),
                .dma_axi_rresp          (),
                .dma_axi_rlast          (),

                // Clocks and Interfaces
                .lsu_bus_clk_en         (1'b1),
                .ifu_bus_clk_en         (1'b1),
                .dbg_bus_clk_en         (1'b1),
                .dma_bus_clk_en         (1'b1),

                .el2_mem_export         (el2_mem_export),
                .el2_icache_export      (el2_icache_export),

                // Interrupts (Extint lines fed from DMA, FIFO, UART, Timer, and PLIC eip)
                .timer_int              (timer_irq),
                .soft_int               (1'b0),
                .extintsrc_req          ({ {27{1'b0}}, timer_irq, uart_irq, fifo_irq, dma_irq }),

                // JTAG & Debug
                .jtag_tck               (1'b0),
                .jtag_tms               (1'b0),
                .jtag_tdi               (1'b0),
                .jtag_trst_n            (1'b1),
                .jtag_tdo               (),
                .jtag_tdoEn             (),

                .core_id                ('0),
                .mpc_debug_halt_req     (1'b0),
                .mpc_debug_run_req      (1'b0),
                .mpc_reset_run_req      (1'b1),
                .i_cpu_halt_req         (1'b0),
                .i_cpu_run_req          (1'b0),
                .scan_mode              (1'b0),
                .mbist_mode             (1'b0),
                .dmi_core_enable        (1'b0),
                .dmi_uncore_enable      (1'b0),
                .dmi_uncore_rdata       ('0)
            );

            // -----------------------------------------------------------------
            // Tie off icache export (instructions execute from local ICCM)
            // -----------------------------------------------------------------
            assign el2_icache_export.wb_packeddout_pre = '0;
            assign el2_icache_export.wb_dout_pre_up = '0;
            assign el2_icache_export.ic_tag_data_raw_packed_pre = '0;
            assign el2_icache_export.ic_tag_data_raw_pre = '0;

            // -----------------------------------------------------------------
            // 4 ICCM SRAM Banks (64 KiB total, 4096 words x 39 bits per bank)
            // -----------------------------------------------------------------
            wire [38:0] iccm_bank_q [4];
            for (genvar i = 0; i < 4; i++) begin : gen_iccm_bank
                assign el2_mem_export.iccm_bank_dout[i] = iccm_bank_q[i][31:0];
                assign el2_mem_export.iccm_bank_ecc[i]  = iccm_bank_q[i][38:32];

                ram_4096x39 iccm_bank (
                    .CLK      (el2_mem_export.clk),
                    .ME       (el2_mem_export.iccm_clken[i]),
                    .WE       (el2_mem_export.iccm_wren_bank[i]),
                    .ADR      (el2_mem_export.iccm_addr_bank[i]),
                    .D        ({el2_mem_export.iccm_bank_wr_ecc[i], el2_mem_export.iccm_bank_wr_data[i]}),
                    .Q        (iccm_bank_q[i]),
                    .TEST1    (1'b0),
                    .RME      (1'b0),
                    .RM       (4'b0000),
                    .LS       (1'b0),
                    .DS       (1'b0),
                    .SD       (1'b0),
                    .TEST_RNM (1'b0),
                    .BC1      (1'b0),
                    .BC2      (1'b0),
                    .ROP      ()
                );
            end

            // -----------------------------------------------------------------
            // 4 DCCM SRAM Banks (64 KiB total, 4096 words x 39 bits per bank)
            // -----------------------------------------------------------------
            wire [38:0] dccm_bank_q [4];
            for (genvar i = 0; i < 4; i++) begin : gen_dccm_bank
                assign el2_mem_export.dccm_bank_dout[i] = dccm_bank_q[i][31:0];
                assign el2_mem_export.dccm_bank_ecc[i]  = dccm_bank_q[i][38:32];

                ram_4096x39 dccm_bank (
                    .CLK      (el2_mem_export.clk),
                    .ME       (el2_mem_export.dccm_clken[i]),
                    .WE       (el2_mem_export.dccm_wren_bank[i]),
                    .ADR      (el2_mem_export.dccm_addr_bank[i]),
                    .D        ({el2_mem_export.dccm_wr_ecc_bank[i], el2_mem_export.dccm_wr_data_bank[i]}),
                    .Q        (dccm_bank_q[i]),
                    .TEST1    (1'b0),
                    .RME      (1'b0),
                    .RM       (4'b0000),
                    .LS       (1'b0),
                    .DS       (1'b0),
                    .SD       (1'b0),
                    .TEST_RNM (1'b0),
                    .BC1      (1'b0),
                    .BC2      (1'b0),
                    .ROP      ()
                );
            end
        end else begin : gen_no_internal_cpu
            assign cpu_lsu_awvalid = 1'b0;
            assign cpu_lsu_awid    = '0;
            assign cpu_lsu_awaddr  = '0;
            assign cpu_lsu_awregion= '0;
            assign cpu_lsu_awlen   = '0;
            assign cpu_lsu_awsize  = '0;
            assign cpu_lsu_awburst = '0;
            assign cpu_lsu_awlock  = '0;
            assign cpu_lsu_awcache = '0;
            assign cpu_lsu_awprot  = '0;
            assign cpu_lsu_awqos   = '0;
            assign cpu_lsu_wvalid  = 1'b0;
            assign cpu_lsu_wdata   = '0;
            assign cpu_lsu_wstrb   = '0;
            assign cpu_lsu_wlast   = 1'b0;
            assign cpu_lsu_bready  = 1'b0;
            assign cpu_lsu_arvalid = 1'b0;
            assign cpu_lsu_arid    = '0;
            assign cpu_lsu_araddr  = '0;
            assign cpu_lsu_arregion= '0;
            assign cpu_lsu_arlen   = '0;
            assign cpu_lsu_arsize  = '0;
            assign cpu_lsu_arburst = '0;
            assign cpu_lsu_arlock  = '0;
            assign cpu_lsu_arcache = '0;
            assign cpu_lsu_arprot  = '0;
            assign cpu_lsu_arqos   = '0;
            assign cpu_lsu_rready  = 1'b0;
        end
    endgenerate

    // =========================================================================
    // AXI 2x8 Interconnect
    // =========================================================================
    axi_interconnect_wrap_2x8 #(
        .DATA_WIDTH       (DATA_WIDTH),
        .ADDR_WIDTH       (ADDR_WIDTH),
        .STRB_WIDTH       (DATA_WIDTH/8),
        .ID_WIDTH         (ID_WIDTH),
        .M_REGIONS        (1),
        // 16 MiB Aperture per port (24-bit ADDR_WIDTH)
        .M00_BASE_ADDR    (32'h0000_0000), .M00_ADDR_WIDTH(32'd24), // S0: IMEM
        .M01_BASE_ADDR    (32'h1000_0000), .M01_ADDR_WIDTH(32'd24), // S1: DMEM
        .M02_BASE_ADDR    (32'h2000_0000), .M02_ADDR_WIDTH(32'd24), // S2: UART
        .M03_BASE_ADDR    (32'h3000_0000), .M03_ADDR_WIDTH(32'd24), // S3: Timer
        .M04_BASE_ADDR    (32'h4000_0000), .M04_ADDR_WIDTH(32'd24), // S4: GPIO
        .M05_BASE_ADDR    (32'h5000_0000), .M05_ADDR_WIDTH(32'd24), // S5: FIFO
        .M06_BASE_ADDR    (32'h6000_0000), .M06_ADDR_WIDTH(32'd24), // S6: DMA Config
        .M07_BASE_ADDR    (32'h7000_0000), .M07_ADDR_WIDTH(32'd24)  // S7: PLIC
    ) u_interconnect (
        .clk              (clk),
        .rst              (rst),

        // Slave 0: CPU LSU (or external bus injection)
        .s00_axi_awid     (s00_axi_awid),
        .s00_axi_awaddr   (s00_axi_awaddr),
        .s00_axi_awlen    (s00_axi_awlen),
        .s00_axi_awsize   (s00_axi_awsize),
        .s00_axi_awburst  (s00_axi_awburst),
        .s00_axi_awlock   (s00_axi_awlock),
        .s00_axi_awcache  (s00_axi_awcache),
        .s00_axi_awprot   (s00_axi_awprot),
        .s00_axi_awqos    (s00_axi_awqos),
        .s00_axi_awuser   (1'b0),
        .s00_axi_awvalid  (s00_axi_awvalid),
        .s00_axi_awready  (s00_axi_awready),

        .s00_axi_wdata    (s00_axi_wdata),
        .s00_axi_wstrb    (s00_axi_wstrb),
        .s00_axi_wlast    (s00_axi_wlast),
        .s00_axi_wuser    (1'b0),
        .s00_axi_wvalid   (s00_axi_wvalid),
        .s00_axi_wready   (s00_axi_wready),

        .s00_axi_bid      (s00_axi_bid),
        .s00_axi_bresp    (s00_axi_bresp),
        .s00_axi_buser    (),
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
        .s00_axi_aruser   (1'b0),
        .s00_axi_arvalid  (s00_axi_arvalid),
        .s00_axi_arready  (s00_axi_arready),

        .s00_axi_rid      (s00_axi_rid),
        .s00_axi_rdata    (s00_axi_rdata),
        .s00_axi_rresp    (s00_axi_rresp),
        .s00_axi_rlast    (s00_axi_rlast),
        .s00_axi_ruser    (),
        .s00_axi_rvalid   (s00_axi_rvalid),
        .s00_axi_rready   (s00_axi_rready),

        // Slave 1: DMA Master
        .s01_axi_awid     (s01_axi_awid),
        .s01_axi_awaddr   (s01_axi_awaddr),
        .s01_axi_awlen    (s01_axi_awlen),
        .s01_axi_awsize   (s01_axi_awsize),
        .s01_axi_awburst  (s01_axi_awburst),
        .s01_axi_awlock   (s01_axi_awlock),
        .s01_axi_awcache  (s01_axi_awcache),
        .s01_axi_awprot   (s01_axi_awprot),
        .s01_axi_awqos    (s01_axi_awqos),
        .s01_axi_awuser   (1'b0),
        .s01_axi_awvalid  (s01_axi_awvalid),
        .s01_axi_awready  (s01_axi_awready),

        .s01_axi_wdata    (s01_axi_wdata),
        .s01_axi_wstrb    (s01_axi_wstrb),
        .s01_axi_wlast    (s01_axi_wlast),
        .s01_axi_wuser    (1'b0),
        .s01_axi_wvalid   (s01_axi_wvalid),
        .s01_axi_wready   (s01_axi_wready),

        .s01_axi_bid      (s01_axi_bid),
        .s01_axi_bresp    (s01_axi_bresp),
        .s01_axi_buser    (),
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
        .s01_axi_aruser   (1'b0),
        .s01_axi_arvalid  (s01_axi_arvalid),
        .s01_axi_arready  (s01_axi_arready),

        .s01_axi_rid      (s01_axi_rid),
        .s01_axi_rdata    (s01_axi_rdata),
        .s01_axi_rresp    (s01_axi_rresp),
        .s01_axi_rlast    (s01_axi_rlast),
        .s01_axi_ruser    (),
        .s01_axi_rvalid   (s01_axi_rvalid),
        .s01_axi_rready   (s01_axi_rready),

        // Masters m00..m07
        .m00_axi_awid     (m00_axi_awid),
        .m00_axi_awaddr   (m00_axi_awaddr),
        .m00_axi_awlen    (m00_axi_awlen),
        .m00_axi_awsize   (m00_axi_awsize),
        .m00_axi_awburst  (m00_axi_awburst),
        .m00_axi_awlock   (m00_axi_awlock),
        .m00_axi_awcache  (m00_axi_awcache),
        .m00_axi_awprot   (m00_axi_awprot),
        .m00_axi_awqos    (),
        .m00_axi_awregion (),
        .m00_axi_awuser   (),
        .m00_axi_awvalid  (m00_axi_awvalid),
        .m00_axi_awready  (m00_axi_awready),
        .m00_axi_wdata    (m00_axi_wdata),
        .m00_axi_wstrb    (m00_axi_wstrb),
        .m00_axi_wlast    (m00_axi_wlast),
        .m00_axi_wuser    (),
        .m00_axi_wvalid   (m00_axi_wvalid),
        .m00_axi_wready   (m00_axi_wready),
        .m00_axi_bid      (m00_axi_bid),
        .m00_axi_bresp    (m00_axi_bresp),
        .m00_axi_buser    (1'b0),
        .m00_axi_bvalid   (m00_axi_bvalid),
        .m00_axi_bready   (m00_axi_bready),
        .m00_axi_arid     (m00_axi_arid),
        .m00_axi_araddr   (m00_axi_araddr),
        .m00_axi_arlen    (m00_axi_arlen),
        .m00_axi_arsize   (m00_axi_arsize),
        .m00_axi_arburst  (m00_axi_arburst),
        .m00_axi_arlock   (m00_axi_arlock),
        .m00_axi_arcache  (m00_axi_arcache),
        .m00_axi_arprot   (m00_axi_arprot),
        .m00_axi_arqos    (),
        .m00_axi_arregion (),
        .m00_axi_aruser   (),
        .m00_axi_arvalid  (m00_axi_arvalid),
        .m00_axi_arready  (m00_axi_arready),
        .m00_axi_rid      (m00_axi_rid),
        .m00_axi_rdata    (m00_axi_rdata),
        .m00_axi_rresp    (m00_axi_rresp),
        .m00_axi_rlast    (m00_axi_rlast),
        .m00_axi_ruser    (1'b0),
        .m00_axi_rvalid   (m00_axi_rvalid),
        .m00_axi_rready   (m00_axi_rready),

        .m01_axi_awid     (m01_axi_awid),
        .m01_axi_awaddr   (m01_axi_awaddr),
        .m01_axi_awlen    (m01_axi_awlen),
        .m01_axi_awsize   (m01_axi_awsize),
        .m01_axi_awburst  (m01_axi_awburst),
        .m01_axi_awlock   (m01_axi_awlock),
        .m01_axi_awcache  (m01_axi_awcache),
        .m01_axi_awprot   (m01_axi_awprot),
        .m01_axi_awqos    (),
        .m01_axi_awregion (),
        .m01_axi_awuser   (),
        .m01_axi_awvalid  (m01_axi_awvalid),
        .m01_axi_awready  (m01_axi_awready),
        .m01_axi_wdata    (m01_axi_wdata),
        .m01_axi_wstrb    (m01_axi_wstrb),
        .m01_axi_wlast    (m01_axi_wlast),
        .m01_axi_wuser    (),
        .m01_axi_wvalid   (m01_axi_wvalid),
        .m01_axi_wready   (m01_axi_wready),
        .m01_axi_bid      (m01_axi_bid),
        .m01_axi_bresp    (m01_axi_bresp),
        .m01_axi_buser    (1'b0),
        .m01_axi_bvalid   (m01_axi_bvalid),
        .m01_axi_bready   (m01_axi_bready),
        .m01_axi_arid     (m01_axi_arid),
        .m01_axi_araddr   (m01_axi_araddr),
        .m01_axi_arlen    (m01_axi_arlen),
        .m01_axi_arsize   (m01_axi_arsize),
        .m01_axi_arburst  (m01_axi_arburst),
        .m01_axi_arlock   (m01_axi_arlock),
        .m01_axi_arcache  (m01_axi_arcache),
        .m01_axi_arprot   (m01_axi_arprot),
        .m01_axi_arqos    (),
        .m01_axi_arregion (),
        .m01_axi_aruser   (),
        .m01_axi_arvalid  (m01_axi_arvalid),
        .m01_axi_arready  (m01_axi_arready),
        .m01_axi_rid      (m01_axi_rid),
        .m01_axi_rdata    (m01_axi_rdata),
        .m01_axi_rresp    (m01_axi_rresp),
        .m01_axi_rlast    (m01_axi_rlast),
        .m01_axi_ruser    (1'b0),
        .m01_axi_rvalid   (m01_axi_rvalid),
        .m01_axi_rready   (m01_axi_rready),

        .m02_axi_awid     (m02_axi_awid),
        .m02_axi_awaddr   (m02_axi_awaddr),
        .m02_axi_awlen    (m02_axi_awlen),
        .m02_axi_awsize   (m02_axi_awsize),
        .m02_axi_awburst  (m02_axi_awburst),
        .m02_axi_awlock   (m02_axi_awlock),
        .m02_axi_awcache  (m02_axi_awcache),
        .m02_axi_awprot   (m02_axi_awprot),
        .m02_axi_awqos    (m02_axi_awqos),
        .m02_axi_awregion (m02_axi_awregion),
        .m02_axi_awuser   (),
        .m02_axi_awvalid  (m02_axi_awvalid),
        .m02_axi_awready  (m02_axi_awready),
        .m02_axi_wdata    (m02_axi_wdata),
        .m02_axi_wstrb    (m02_axi_wstrb),
        .m02_axi_wlast    (m02_axi_wlast),
        .m02_axi_wuser    (),
        .m02_axi_wvalid   (m02_axi_wvalid),
        .m02_axi_wready   (m02_axi_wready),
        .m02_axi_bid      (m02_axi_bid),
        .m02_axi_bresp    (m02_axi_bresp),
        .m02_axi_buser    (1'b0),
        .m02_axi_bvalid   (m02_axi_bvalid),
        .m02_axi_bready   (m02_axi_bready),
        .m02_axi_arid     (m02_axi_arid),
        .m02_axi_araddr   (m02_axi_araddr),
        .m02_axi_arlen    (m02_axi_arlen),
        .m02_axi_arsize   (m02_axi_arsize),
        .m02_axi_arburst  (m02_axi_arburst),
        .m02_axi_arlock   (m02_axi_arlock),
        .m02_axi_arcache  (m02_axi_arcache),
        .m02_axi_arprot   (m02_axi_arprot),
        .m02_axi_arqos    (m02_axi_arqos),
        .m02_axi_arregion (m02_axi_arregion),
        .m02_axi_aruser   (),
        .m02_axi_arvalid  (m02_axi_arvalid),
        .m02_axi_arready  (m02_axi_arready),
        .m02_axi_rid      (m02_axi_rid),
        .m02_axi_rdata    (m02_axi_rdata),
        .m02_axi_rresp    (m02_axi_rresp),
        .m02_axi_rlast    (m02_axi_rlast),
        .m02_axi_ruser    (1'b0),
        .m02_axi_rvalid   (m02_axi_rvalid),
        .m02_axi_rready   (m02_axi_rready),

        .m03_axi_awid     (m03_axi_awid),
        .m03_axi_awaddr   (m03_axi_awaddr),
        .m03_axi_awlen    (m03_axi_awlen),
        .m03_axi_awsize   (m03_axi_awsize),
        .m03_axi_awburst  (m03_axi_awburst),
        .m03_axi_awlock   (m03_axi_awlock),
        .m03_axi_awcache  (m03_axi_awcache),
        .m03_axi_awprot   (m03_axi_awprot),
        .m03_axi_awqos    (m03_axi_awqos),
        .m03_axi_awregion (m03_axi_awregion),
        .m03_axi_awuser   (),
        .m03_axi_awvalid  (m03_axi_awvalid),
        .m03_axi_awready  (m03_axi_awready),
        .m03_axi_wdata    (m03_axi_wdata),
        .m03_axi_wstrb    (m03_axi_wstrb),
        .m03_axi_wlast    (m03_axi_wlast),
        .m03_axi_wuser    (),
        .m03_axi_wvalid   (m03_axi_wvalid),
        .m03_axi_wready   (m03_axi_wready),
        .m03_axi_bid      (m03_axi_bid),
        .m03_axi_bresp    (m03_axi_bresp),
        .m03_axi_buser    (1'b0),
        .m03_axi_bvalid   (m03_axi_bvalid),
        .m03_axi_bready   (m03_axi_bready),
        .m03_axi_arid     (m03_axi_arid),
        .m03_axi_araddr   (m03_axi_araddr),
        .m03_axi_arlen    (m03_axi_arlen),
        .m03_axi_arsize   (m03_axi_arsize),
        .m03_axi_arburst  (m03_axi_arburst),
        .m03_axi_arlock   (m03_axi_arlock),
        .m03_axi_arcache  (m03_axi_arcache),
        .m03_axi_arprot   (m03_axi_arprot),
        .m03_axi_arqos    (m03_axi_arqos),
        .m03_axi_arregion (m03_axi_arregion),
        .m03_axi_aruser   (),
        .m03_axi_arvalid  (m03_axi_arvalid),
        .m03_axi_arready  (m03_axi_arready),
        .m03_axi_rid      (m03_axi_rid),
        .m03_axi_rdata    (m03_axi_rdata),
        .m03_axi_rresp    (m03_axi_rresp),
        .m03_axi_rlast    (m03_axi_rlast),
        .m03_axi_ruser    (1'b0),
        .m03_axi_rvalid   (m03_axi_rvalid),
        .m03_axi_rready   (m03_axi_rready),

        .m04_axi_awid     (m04_axi_awid),
        .m04_axi_awaddr   (m04_axi_awaddr),
        .m04_axi_awlen    (m04_axi_awlen),
        .m04_axi_awsize   (m04_axi_awsize),
        .m04_axi_awburst  (m04_axi_awburst),
        .m04_axi_awlock   (m04_axi_awlock),
        .m04_axi_awcache  (m04_axi_awcache),
        .m04_axi_awprot   (m04_axi_awprot),
        .m04_axi_awqos    (m04_axi_awqos),
        .m04_axi_awregion (m04_axi_awregion),
        .m04_axi_awuser   (),
        .m04_axi_awvalid  (m04_axi_awvalid),
        .m04_axi_awready  (m04_axi_awready),
        .m04_axi_wdata    (m04_axi_wdata),
        .m04_axi_wstrb    (m04_axi_wstrb),
        .m04_axi_wlast    (m04_axi_wlast),
        .m04_axi_wuser    (),
        .m04_axi_wvalid   (m04_axi_wvalid),
        .m04_axi_wready   (m04_axi_wready),
        .m04_axi_bid      (m04_axi_bid),
        .m04_axi_bresp    (m04_axi_bresp),
        .m04_axi_buser    (1'b0),
        .m04_axi_bvalid   (m04_axi_bvalid),
        .m04_axi_bready   (m04_axi_bready),
        .m04_axi_arid     (m04_axi_arid),
        .m04_axi_araddr   (m04_axi_araddr),
        .m04_axi_arlen    (m04_axi_arlen),
        .m04_axi_arsize   (m04_axi_arsize),
        .m04_axi_arburst  (m04_axi_arburst),
        .m04_axi_arlock   (m04_axi_arlock),
        .m04_axi_arcache  (m04_axi_arcache),
        .m04_axi_arprot   (m04_axi_arprot),
        .m04_axi_arqos    (m04_axi_arqos),
        .m04_axi_arregion (m04_axi_arregion),
        .m04_axi_aruser   (),
        .m04_axi_arvalid  (m04_axi_arvalid),
        .m04_axi_arready  (m04_axi_arready),
        .m04_axi_rid      (m04_axi_rid),
        .m04_axi_rdata    (m04_axi_rdata),
        .m04_axi_rresp    (m04_axi_rresp),
        .m04_axi_rlast    (m04_axi_rlast),
        .m04_axi_ruser    (1'b0),
        .m04_axi_rvalid   (m04_axi_rvalid),
        .m04_axi_rready   (m04_axi_rready),

        .m05_axi_awid     (m05_axi_awid),
        .m05_axi_awaddr   (m05_axi_awaddr),
        .m05_axi_awlen    (m05_axi_awlen),
        .m05_axi_awsize   (m05_axi_awsize),
        .m05_axi_awburst  (m05_axi_awburst),
        .m05_axi_awlock   (m05_axi_awlock),
        .m05_axi_awcache  (m05_axi_awcache),
        .m05_axi_awprot   (m05_axi_awprot),
        .m05_axi_awqos    (m05_axi_awqos),
        .m05_axi_awregion (m05_axi_awregion),
        .m05_axi_awuser   (),
        .m05_axi_awvalid  (m05_axi_awvalid),
        .m05_axi_awready  (m05_axi_awready),
        .m05_axi_wdata    (m05_axi_wdata),
        .m05_axi_wstrb    (m05_axi_wstrb),
        .m05_axi_wlast    (m05_axi_wlast),
        .m05_axi_wuser    (),
        .m05_axi_wvalid   (m05_axi_wvalid),
        .m05_axi_wready   (m05_axi_wready),
        .m05_axi_bid      (m05_axi_bid),
        .m05_axi_bresp    (m05_axi_bresp),
        .m05_axi_buser    (1'b0),
        .m05_axi_bvalid   (m05_axi_bvalid),
        .m05_axi_bready   (m05_axi_bready),
        .m05_axi_arid     (m05_axi_arid),
        .m05_axi_araddr   (m05_axi_araddr),
        .m05_axi_arlen    (m05_axi_arlen),
        .m05_axi_arsize   (m05_axi_arsize),
        .m05_axi_arburst  (m05_axi_arburst),
        .m05_axi_arlock   (m05_axi_arlock),
        .m05_axi_arcache  (m05_axi_arcache),
        .m05_axi_arprot   (m05_axi_arprot),
        .m05_axi_arqos    (m05_axi_arqos),
        .m05_axi_arregion (m05_axi_arregion),
        .m05_axi_aruser   (),
        .m05_axi_arvalid  (m05_axi_arvalid),
        .m05_axi_arready  (m05_axi_arready),
        .m05_axi_rid      (m05_axi_rid),
        .m05_axi_rdata    (m05_axi_rdata),
        .m05_axi_rresp    (m05_axi_rresp),
        .m05_axi_rlast    (m05_axi_rlast),
        .m05_axi_ruser    (1'b0),
        .m05_axi_rvalid   (m05_axi_rvalid),
        .m05_axi_rready   (m05_axi_rready),

        .m06_axi_awid     (m06_axi_awid),
        .m06_axi_awaddr   (m06_axi_awaddr),
        .m06_axi_awlen    (m06_axi_awlen),
        .m06_axi_awsize   (m06_axi_awsize),
        .m06_axi_awburst  (m06_axi_awburst),
        .m06_axi_awlock   (m06_axi_awlock),
        .m06_axi_awcache  (m06_axi_awcache),
        .m06_axi_awprot   (m06_axi_awprot),
        .m06_axi_awqos    (m06_axi_awqos),
        .m06_axi_awregion (m06_axi_awregion),
        .m06_axi_awuser   (),
        .m06_axi_awvalid  (m06_axi_awvalid),
        .m06_axi_awready  (m06_axi_awready),
        .m06_axi_wdata    (m06_axi_wdata),
        .m06_axi_wstrb    (m06_axi_wstrb),
        .m06_axi_wlast    (m06_axi_wlast),
        .m06_axi_wuser    (),
        .m06_axi_wvalid   (m06_axi_wvalid),
        .m06_axi_wready   (m06_axi_wready),
        .m06_axi_bid      (m06_axi_bid),
        .m06_axi_bresp    (m06_axi_bresp),
        .m06_axi_buser    (1'b0),
        .m06_axi_bvalid   (m06_axi_bvalid),
        .m06_axi_bready   (m06_axi_bready),
        .m06_axi_arid     (m06_axi_arid),
        .m06_axi_araddr   (m06_axi_araddr),
        .m06_axi_arlen    (m06_axi_arlen),
        .m06_axi_arsize   (m06_axi_arsize),
        .m06_axi_arburst  (m06_axi_arburst),
        .m06_axi_arlock   (m06_axi_arlock),
        .m06_axi_arcache  (m06_axi_arcache),
        .m06_axi_arprot   (m06_axi_arprot),
        .m06_axi_arqos    (m06_axi_arqos),
        .m06_axi_arregion (m06_axi_arregion),
        .m06_axi_aruser   (),
        .m06_axi_arvalid  (m06_axi_arvalid),
        .m06_axi_arready  (m06_axi_arready),
        .m06_axi_rid      (m06_axi_rid),
        .m06_axi_rdata    (m06_axi_rdata),
        .m06_axi_rresp    (m06_axi_rresp),
        .m06_axi_rlast    (m06_axi_rlast),
        .m06_axi_ruser    (1'b0),
        .m06_axi_rvalid   (m06_axi_rvalid),
        .m06_axi_rready   (m06_axi_rready),

        .m07_axi_awid     (m07_axi_awid),
        .m07_axi_awaddr   (m07_axi_awaddr),
        .m07_axi_awlen    (m07_axi_awlen),
        .m07_axi_awsize   (m07_axi_awsize),
        .m07_axi_awburst  (m07_axi_awburst),
        .m07_axi_awlock   (m07_axi_awlock),
        .m07_axi_awcache  (m07_axi_awcache),
        .m07_axi_awprot   (m07_axi_awprot),
        .m07_axi_awqos    (m07_axi_awqos),
        .m07_axi_awregion (m07_axi_awregion),
        .m07_axi_awuser   (),
        .m07_axi_awvalid  (m07_axi_awvalid),
        .m07_axi_awready  (m07_axi_awready),
        .m07_axi_wdata    (m07_axi_wdata),
        .m07_axi_wstrb    (m07_axi_wstrb),
        .m07_axi_wlast    (m07_axi_wlast),
        .m07_axi_wuser    (),
        .m07_axi_wvalid   (m07_axi_wvalid),
        .m07_axi_wready   (m07_axi_wready),
        .m07_axi_bid      (m07_axi_bid),
        .m07_axi_bresp    (m07_axi_bresp),
        .m07_axi_buser    (1'b0),
        .m07_axi_bvalid   (m07_axi_bvalid),
        .m07_axi_bready   (m07_axi_bready),
        .m07_axi_arid     (m07_axi_arid),
        .m07_axi_araddr   (m07_axi_araddr),
        .m07_axi_arlen    (m07_axi_arlen),
        .m07_axi_arsize   (m07_axi_arsize),
        .m07_axi_arburst  (m07_axi_arburst),
        .m07_axi_arlock   (m07_axi_arlock),
        .m07_axi_arcache  (m07_axi_arcache),
        .m07_axi_arprot   (m07_axi_arprot),
        .m07_axi_arqos    (m07_axi_arqos),
        .m07_axi_arregion (m07_axi_arregion),
        .m07_axi_aruser   (),
        .m07_axi_arvalid  (m07_axi_arvalid),
        .m07_axi_arready  (m07_axi_arready),
        .m07_axi_rid      (m07_axi_rid),
        .m07_axi_rdata    (m07_axi_rdata),
        .m07_axi_rresp    (m07_axi_rresp),
        .m07_axi_rlast    (m07_axi_rlast),
        .m07_axi_ruser    (1'b0),
        .m07_axi_rvalid   (m07_axi_rvalid),
        .m07_axi_rready   (m07_axi_rready)
    );

    // =========================================================================
    // M00: Instruction Memory (64 KiB SRAM)
    // =========================================================================
    axi_ram #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (MEM_ADDR_WIDTH),
        .STRB_WIDTH (DATA_WIDTH/8),
        .ID_WIDTH   (ID_WIDTH)
    ) u_imem (
        .clk        (clk),
        .rst        (rst),
        .s_axi_awid (m00_axi_awid),
        .s_axi_awaddr(m00_axi_awaddr[MEM_ADDR_WIDTH-1:0]),
        .s_axi_awlen(m00_axi_awlen),
        .s_axi_awsize(m00_axi_awsize),
        .s_axi_awburst(m00_axi_awburst),
        .s_axi_awlock(m00_axi_awlock),
        .s_axi_awcache(m00_axi_awcache),
        .s_axi_awprot(m00_axi_awprot),
        .s_axi_awvalid(m00_axi_awvalid),
        .s_axi_awready(m00_axi_awready),
        .s_axi_wdata(m00_axi_wdata),
        .s_axi_wstrb(m00_axi_wstrb),
        .s_axi_wlast(m00_axi_wlast),
        .s_axi_wvalid(m00_axi_wvalid),
        .s_axi_wready(m00_axi_wready),
        .s_axi_bid  (m00_axi_bid),
        .s_axi_bresp(m00_axi_bresp),
        .s_axi_bvalid(m00_axi_bvalid),
        .s_axi_bready(m00_axi_bready),
        .s_axi_arid (m00_axi_arid),
        .s_axi_araddr(m00_axi_araddr[MEM_ADDR_WIDTH-1:0]),
        .s_axi_arlen(m00_axi_arlen),
        .s_axi_arsize(m00_axi_arsize),
        .s_axi_arburst(m00_axi_arburst),
        .s_axi_arlock(m00_axi_arlock),
        .s_axi_arcache(m00_axi_arcache),
        .s_axi_arprot(m00_axi_arprot),
        .s_axi_arvalid(m00_axi_arvalid),
        .s_axi_arready(m00_axi_arready),
        .s_axi_rid  (m00_axi_rid),
        .s_axi_rdata(m00_axi_rdata),
        .s_axi_rresp(m00_axi_rresp),
        .s_axi_rlast(m00_axi_rlast),
        .s_axi_rvalid(m00_axi_rvalid),
        .s_axi_rready(m00_axi_rready)
    );

    // =========================================================================
    // M01: Data Memory (64 KiB SRAM)
    // =========================================================================
    axi_ram #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (MEM_ADDR_WIDTH),
        .STRB_WIDTH (DATA_WIDTH/8),
        .ID_WIDTH   (ID_WIDTH)
    ) u_dmem (
        .clk        (clk),
        .rst        (rst),
        .s_axi_awid (m01_axi_awid),
        .s_axi_awaddr(m01_axi_awaddr[MEM_ADDR_WIDTH-1:0]),
        .s_axi_awlen(m01_axi_awlen),
        .s_axi_awsize(m01_axi_awsize),
        .s_axi_awburst(m01_axi_awburst),
        .s_axi_awlock(m01_axi_awlock),
        .s_axi_awcache(m01_axi_awcache),
        .s_axi_awprot(m01_axi_awprot),
        .s_axi_awvalid(m01_axi_awvalid),
        .s_axi_awready(m01_axi_awready),
        .s_axi_wdata(m01_axi_wdata),
        .s_axi_wstrb(m01_axi_wstrb),
        .s_axi_wlast(m01_axi_wlast),
        .s_axi_wvalid(m01_axi_wvalid),
        .s_axi_wready(m01_axi_wready),
        .s_axi_bid  (m01_axi_bid),
        .s_axi_bresp(m01_axi_bresp),
        .s_axi_bvalid(m01_axi_bvalid),
        .s_axi_bready(m01_axi_bready),
        .s_axi_arid (m01_axi_arid),
        .s_axi_araddr(m01_axi_araddr[MEM_ADDR_WIDTH-1:0]),
        .s_axi_arlen(m01_axi_arlen),
        .s_axi_arsize(m01_axi_arsize),
        .s_axi_arburst(m01_axi_arburst),
        .s_axi_arlock(m01_axi_arlock),
        .s_axi_arcache(m01_axi_arcache),
        .s_axi_arprot(m01_axi_arprot),
        .s_axi_arvalid(m01_axi_arvalid),
        .s_axi_arready(m01_axi_arready),
        .s_axi_rid  (m01_axi_rid),
        .s_axi_rdata(m01_axi_rdata),
        .s_axi_rresp(m01_axi_rresp),
        .s_axi_rlast(m01_axi_rlast),
        .s_axi_rvalid(m01_axi_rvalid),
        .s_axi_rready(m01_axi_rready)
    );

    // =========================================================================
    // M02: Real-Time Data Buffer FIFO
    // =========================================================================
    // S5: Real-Time Buffer FIFO (axi_data_buffer_fifo)
    // =========================================================================
    axi_data_buffer_fifo #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH),
        .ID_WIDTH   (ID_WIDTH),
        .FIFO_DEPTH (FIFO_DEPTH)
    ) u_fifo (
        .clk        (clk),
        .rst        (rst),

        // AXI4 Slave
        .s_axi_awid     (m05_axi_awid),
        .s_axi_awaddr   (m05_axi_awaddr),
        .s_axi_awlen    (m05_axi_awlen),
        .s_axi_awsize   (m05_axi_awsize),
        .s_axi_awburst  (m05_axi_awburst),
        .s_axi_awlock   (m05_axi_awlock),
        .s_axi_awcache  (m05_axi_awcache),
        .s_axi_awprot   (m05_axi_awprot),
        .s_axi_awqos    (m05_axi_awqos),
        .s_axi_awregion (m05_axi_awregion),
        .s_axi_awvalid  (m05_axi_awvalid),
        .s_axi_awready  (m05_axi_awready),

        .s_axi_wdata    (m05_axi_wdata),
        .s_axi_wstrb    (m05_axi_wstrb),
        .s_axi_wlast    (m05_axi_wlast),
        .s_axi_wvalid   (m05_axi_wvalid),
        .s_axi_wready   (m05_axi_wready),

        .s_axi_bid      (m05_axi_bid),
        .s_axi_bresp    (m05_axi_bresp),
        .s_axi_bvalid   (m05_axi_bvalid),
        .s_axi_bready   (m05_axi_bready),

        .s_axi_arid     (m05_axi_arid),
        .s_axi_araddr   (m05_axi_araddr),
        .s_axi_arlen    (m05_axi_arlen),
        .s_axi_arsize   (m05_axi_arsize),
        .s_axi_arburst  (m05_axi_arburst),
        .s_axi_arlock   (m05_axi_arlock),
        .s_axi_arcache  (m05_axi_arcache),
        .s_axi_arprot   (m05_axi_arprot),
        .s_axi_arqos    (m05_axi_arqos),
        .s_axi_arregion (m05_axi_arregion),
        .s_axi_arvalid  (m05_axi_arvalid),
        .s_axi_arready  (m05_axi_arready),

        .s_axi_rid      (m05_axi_rid),
        .s_axi_rdata    (m05_axi_rdata),
        .s_axi_rresp    (m05_axi_rresp),
        .s_axi_rlast    (m05_axi_rlast),
        .s_axi_rvalid   (m05_axi_rvalid),
        .s_axi_rready   (m05_axi_rready),

        // Stream input from sensor / testbench
        .stream_in_valid(sample_stream_valid),
        .stream_in_data (sample_stream_data),
        .stream_in_ready(sample_stream_ready),

        // Handshakes
        .dreq           (fifo_dreq),
        .dack           (fifo_dack),
        .irq            (fifo_irq)
    );

    // =========================================================================
    // S6: DMA Configuration Interface (Adapter -> Wrapper)
    // =========================================================================
    logic        dma_reg_wr_en;
    logic        dma_reg_rd_en;
    logic [11:0] dma_reg_addr;
    logic [31:0] dma_reg_wr_data;
    logic [31:0] dma_reg_rd_data;
    logic        dma_reg_rd_valid;

    axi4_to_dma_reg_adapter #(
        .SLAVE_ID_WIDTH (ID_WIDTH),
        .ADDR_WIDTH     (ADDR_WIDTH),
        .DATA_WIDTH     (DATA_WIDTH)
    ) u_dma_reg_adapter (
        .clk            (clk),
        .rst            (rst),

        .s_axi_awid     (m06_axi_awid),
        .s_axi_awaddr   (m06_axi_awaddr),
        .s_axi_awlen    (m06_axi_awlen),
        .s_axi_awsize   (m06_axi_awsize),
        .s_axi_awburst  (m06_axi_awburst),
        .s_axi_awlock   (m06_axi_awlock),
        .s_axi_awcache  (m06_axi_awcache),
        .s_axi_awprot   (m06_axi_awprot),
        .s_axi_awqos    (m06_axi_awqos),
        .s_axi_awregion (m06_axi_awregion),
        .s_axi_awvalid  (m06_axi_awvalid),
        .s_axi_awready  (m06_axi_awready),

        .s_axi_wdata    (m06_axi_wdata),
        .s_axi_wstrb    (m06_axi_wstrb),
        .s_axi_wlast    (m06_axi_wlast),
        .s_axi_wvalid   (m06_axi_wvalid),
        .s_axi_wready   (m06_axi_wready),

        .s_axi_bid      (m06_axi_bid),
        .s_axi_bresp    (m06_axi_bresp),
        .s_axi_bvalid   (m06_axi_bvalid),
        .s_axi_bready   (m06_axi_bready),

        .s_axi_arid     (m06_axi_arid),
        .s_axi_araddr   (m06_axi_araddr),
        .s_axi_arlen    (m06_axi_arlen),
        .s_axi_arsize   (m06_axi_arsize),
        .s_axi_arburst  (m06_axi_arburst),
        .s_axi_arlock   (m06_axi_arlock),
        .s_axi_arcache  (m06_axi_arcache),
        .s_axi_arprot   (m06_axi_arprot),
        .s_axi_arqos    (m06_axi_arqos),
        .s_axi_arregion (m06_axi_arregion),
        .s_axi_arvalid  (m06_axi_arvalid),
        .s_axi_arready  (m06_axi_arready),

        .s_axi_rid      (m06_axi_rid),
        .s_axi_rdata    (m06_axi_rdata),
        .s_axi_rresp    (m06_axi_rresp),
        .s_axi_rlast    (m06_axi_rlast),
        .s_axi_rvalid   (m06_axi_rvalid),
        .s_axi_rready   (m06_axi_rready),

        .reg_wr_en      (dma_reg_wr_en),
        .reg_rd_en      (dma_reg_rd_en),
        .reg_addr       (dma_reg_addr),
        .reg_wr_data    (dma_reg_wr_data),
        .reg_rd_data    (dma_reg_rd_data),
        .reg_rd_valid   (dma_reg_rd_valid)
    );

    dma_axi_master_wrapper #(
        .DATA_W         (DATA_WIDTH),
        .ADDR_W         (ADDR_WIDTH),
        .INTERCONNECT_ID(ID_WIDTH),
        .NUM_CH         (DMA_NUM_CH)
    ) u_dma (
        .clk            (clk),
        .srst           (rst),

        .reg_wr_en      (dma_reg_wr_en),
        .reg_rd_en      (dma_reg_rd_en),
        .reg_addr       (dma_reg_addr),
        .reg_wr_data    (dma_reg_wr_data),
        .reg_rd_data    (dma_reg_rd_data),
        .reg_rd_valid   (dma_reg_rd_valid),

        // Master to Interconnect s01
        .m_axi_awid     (s01_axi_awid),
        .m_axi_awaddr   (s01_axi_awaddr),
        .m_axi_awlen    (s01_axi_awlen),
        .m_axi_awsize   (s01_axi_awsize),
        .m_axi_awburst  (s01_axi_awburst),
        .m_axi_awlock   (s01_axi_awlock),
        .m_axi_awcache  (s01_axi_awcache),
        .m_axi_awprot   (s01_axi_awprot),
        .m_axi_awqos    (s01_axi_awqos),
        .m_axi_awvalid  (s01_axi_awvalid),
        .m_axi_awready  (s01_axi_awready),

        .m_axi_wdata    (s01_axi_wdata),
        .m_axi_wstrb    (s01_axi_wstrb),
        .m_axi_wlast    (s01_axi_wlast),
        .m_axi_wvalid   (s01_axi_wvalid),
        .m_axi_wready   (s01_axi_wready),

        .m_axi_bid      (s01_axi_bid),
        .m_axi_bresp    (s01_axi_bresp),
        .m_axi_bvalid   (s01_axi_bvalid),
        .m_axi_bready   (s01_axi_bready),

        .m_axi_arid     (s01_axi_arid),
        .m_axi_araddr   (s01_axi_araddr),
        .m_axi_arlen    (s01_axi_arlen),
        .m_axi_arsize   (s01_axi_arsize),
        .m_axi_arburst  (s01_axi_arburst),
        .m_axi_arlock   (s01_axi_arlock),
        .m_axi_arcache  (s01_axi_arcache),
        .m_axi_arprot   (s01_axi_arprot),
        .m_axi_arqos    (s01_axi_arqos),
        .m_axi_arvalid  (s01_axi_arvalid),
        .m_axi_arready  (s01_axi_arready),

        .m_axi_rid      (s01_axi_rid),
        .m_axi_rdata    (s01_axi_rdata),
        .m_axi_rresp    (s01_axi_rresp),
        .m_axi_rlast    (s01_axi_rlast),
        .m_axi_rvalid   (s01_axi_rvalid),
        .m_axi_rready   (s01_axi_rready),

        .dreq           (dma_dreq),
        .dack           (dma_dack),
        .irq            (dma_irq)
    );

    // =========================================================================
    // M04: Interrupt Controller (PLIC)
    // =========================================================================
    logic        plic_bus_valid;
    logic        plic_bus_ready;
    logic [25:0] plic_bus_addr;
    logic [31:0] plic_bus_wdata;
    logic [31:0] plic_bus_rdata;
    logic        plic_bus_we;

    axi4_to_plic_bus_adapter #(
        .SLAVE_ID_WIDTH (ID_WIDTH),
        .ADDR_WIDTH     (ADDR_WIDTH),
        .DATA_WIDTH     (DATA_WIDTH),
        .PLIC_ADDR_WIDTH(26)
    ) u_plic_adapter (
        .clk            (clk),
        .rst            (rst),

        .s_axi_awid     (m07_axi_awid),
        .s_axi_awaddr   (m07_axi_awaddr),
        .s_axi_awlen    (m07_axi_awlen),
        .s_axi_awsize   (m07_axi_awsize),
        .s_axi_awburst  (m07_axi_awburst),
        .s_axi_awlock   (m07_axi_awlock),
        .s_axi_awcache  (m07_axi_awcache),
        .s_axi_awprot   (m07_axi_awprot),
        .s_axi_awqos    (m07_axi_awqos),
        .s_axi_awregion (m07_axi_awregion),
        .s_axi_awvalid  (m07_axi_awvalid),
        .s_axi_awready  (m07_axi_awready),

        .s_axi_wdata    (m07_axi_wdata),
        .s_axi_wstrb    (m07_axi_wstrb),
        .s_axi_wlast    (m07_axi_wlast),
        .s_axi_wvalid   (m07_axi_wvalid),
        .s_axi_wready   (m07_axi_wready),

        .s_axi_bid      (m07_axi_bid),
        .s_axi_bresp    (m07_axi_bresp),
        .s_axi_bvalid   (m07_axi_bvalid),
        .s_axi_bready   (m07_axi_bready),

        .s_axi_arid     (m07_axi_arid),
        .s_axi_araddr   (m07_axi_araddr),
        .s_axi_arlen    (m07_axi_arlen),
        .s_axi_arsize   (m07_axi_arsize),
        .s_axi_arburst  (m07_axi_arburst),
        .s_axi_arlock   (m07_axi_arlock),
        .s_axi_arcache  (m07_axi_arcache),
        .s_axi_arprot   (m07_axi_arprot),
        .s_axi_arqos    (m07_axi_arqos),
        .s_axi_arregion (m07_axi_arregion),
        .s_axi_arvalid  (m07_axi_arvalid),
        .s_axi_arready  (m07_axi_arready),

        .s_axi_rid      (m07_axi_rid),
        .s_axi_rdata    (m07_axi_rdata),
        .s_axi_rresp    (m07_axi_rresp),
        .s_axi_rlast    (m07_axi_rlast),
        .s_axi_rvalid   (m07_axi_rvalid),
        .s_axi_rready   (m07_axi_rready),

        .bus_valid      (plic_bus_valid),
        .bus_ready      (plic_bus_ready),
        .bus_addr       (plic_bus_addr),
        .bus_wdata      (plic_bus_wdata),
        .bus_rdata      (plic_bus_rdata),
        .bus_we         (plic_bus_we)
    );

    plic_top #(
        .NUM_SOURCES    (PLIC_NUM_SOURCES),
        .NUM_TARGETS    (PLIC_NUM_TARGETS),
        .PRIO_BITS      (3),
        .ADDR_WIDTH     (26),
        .DATA_WIDTH     (DATA_WIDTH)
    ) u_plic (
        .clk            (clk),
        .srst           (rst),
        .irq_sources    (plic_irq_sources),
        .bus_valid      (plic_bus_valid),
        .bus_ready      (plic_bus_ready),
        .bus_addr       (plic_bus_addr),
        .bus_wdata      (plic_bus_wdata),
        .bus_rdata      (plic_bus_rdata),
        .bus_we         (plic_bus_we),
        .eip            (plic_eip)
    );

    // =========================================================================
    // S2: UART (axi_uart_top via axi4_to_axilite_32_adapter)
    // =========================================================================
    logic [11:0] uart_awid;
    logic [4:0]  uart_awaddr;
    logic        uart_awvalid;
    logic        uart_awready;
    logic [31:0] uart_wdata;
    logic [3:0]  uart_wstrb;
    logic        uart_wvalid;
    logic        uart_wready;
    logic [11:0] uart_bid;
    logic [1:0]  uart_bresp;
    logic        uart_bvalid;
    logic        uart_bready;
    logic [11:0] uart_arid;
    logic [4:0]  uart_araddr;
    logic        uart_arvalid;
    logic        uart_arready;
    logic [11:0] uart_rid;
    logic [31:0] uart_rdata;
    logic [1:0]  uart_rresp;
    logic        uart_rvalid;
    logic        uart_rready;

    axi4_to_axilite_32_adapter #(
        .SLAVE_ID_WIDTH   (ID_WIDTH),
        .ADDR_WIDTH       (ADDR_WIDTH),
        .PERIPH_ID_WIDTH  (12),
        .PERIPH_ADDR_WIDTH(5)
    ) u_uart_adapter (
        .clk              (clk),
        .rst_l            (rst_l),

        .s_axi_awid       (m02_axi_awid),
        .s_axi_awaddr     (m02_axi_awaddr),
        .s_axi_awlen      (m02_axi_awlen),
        .s_axi_awsize     (m02_axi_awsize),
        .s_axi_awburst    (m02_axi_awburst),
        .s_axi_awlock     (m02_axi_awlock),
        .s_axi_awcache    (m02_axi_awcache),
        .s_axi_awprot     (m02_axi_awprot),
        .s_axi_awqos      (m02_axi_awqos),
        .s_axi_awregion   (m02_axi_awregion),
        .s_axi_awvalid    (m02_axi_awvalid),
        .s_axi_awready    (m02_axi_awready),

        .s_axi_wdata      (m02_axi_wdata),
        .s_axi_wstrb      (m02_axi_wstrb),
        .s_axi_wlast      (m02_axi_wlast),
        .s_axi_wvalid     (m02_axi_wvalid),
        .s_axi_wready     (m02_axi_wready),

        .s_axi_bid        (m02_axi_bid),
        .s_axi_bresp      (m02_axi_bresp),
        .s_axi_bvalid     (m02_axi_bvalid),
        .s_axi_bready     (m02_axi_bready),

        .s_axi_arid       (m02_axi_arid),
        .s_axi_araddr     (m02_axi_araddr),
        .s_axi_arlen      (m02_axi_arlen),
        .s_axi_arsize     (m02_axi_arsize),
        .s_axi_arburst    (m02_axi_arburst),
        .s_axi_arlock     (m02_axi_arlock),
        .s_axi_arcache    (m02_axi_arcache),
        .s_axi_arprot     (m02_axi_arprot),
        .s_axi_arqos      (m02_axi_arqos),
        .s_axi_arregion   (m02_axi_arregion),
        .s_axi_arvalid    (m02_axi_arvalid),
        .s_axi_arready    (m02_axi_arready),

        .s_axi_rid        (m02_axi_rid),
        .s_axi_rdata      (m02_axi_rdata),
        .s_axi_rresp      (m02_axi_rresp),
        .s_axi_rlast      (m02_axi_rlast),
        .s_axi_rvalid     (m02_axi_rvalid),
        .s_axi_rready     (m02_axi_rready),

        .m_axi_awid       (uart_awid),
        .m_axi_awaddr     (uart_awaddr),
        .m_axi_awvalid    (uart_awvalid),
        .m_axi_awready    (uart_awready),

        .m_axi_wdata      (uart_wdata),
        .m_axi_wstrb      (uart_wstrb),
        .m_axi_wvalid     (uart_wvalid),
        .m_axi_wready     (uart_wready),

        .m_axi_bid        (uart_bid),
        .m_axi_bresp      (uart_bresp),
        .m_axi_bvalid     (uart_bvalid),
        .m_axi_bready     (uart_bready),

        .m_axi_arid       (uart_arid),
        .m_axi_araddr     (uart_araddr),
        .m_axi_arvalid    (uart_arvalid),
        .m_axi_arready    (uart_arready),

        .m_axi_rid        (uart_rid),
        .m_axi_rdata      (uart_rdata),
        .m_axi_rresp      (uart_rresp),
        .m_axi_rvalid     (uart_rvalid),
        .m_axi_rready     (uart_rready)
    );

    axi_uart_top u_uart (
        .fixed_clk_i      (clk),
        .axi_aclk_i       (clk),
        .axi_aresetn_i    (rst_l),

        .axi_awid_i       (uart_awid),
        .axi_awaddr_i     (uart_awaddr),
        .axi_awvalid_i    (uart_awvalid),
        .axi_awready_o    (uart_awready),

        .axi_wdata_i      (uart_wdata),
        .axi_wstrb_i      (uart_wstrb),
        .axi_wvalid_i     (uart_wvalid),
        .axi_wready_o     (uart_wready),

        .axi_bid_o        (uart_bid),
        .axi_bresp_o      (uart_bresp),
        .axi_bvalid_o     (uart_bvalid),
        .axi_bready_i     (uart_bready),

        .axi_arid_i       (uart_arid),
        .axi_araddr_i     (uart_araddr),
        .axi_arvalid_i    (uart_arvalid),
        .axi_arready_o    (uart_arready),

        .axi_rid_o        (uart_rid),
        .axi_rdata_o      (uart_rdata),
        .axi_rresp_o      (uart_rresp),
        .axi_rvalid_o     (uart_rvalid),
        .axi_rready_i     (uart_rready),

        .read_interrupt_o (uart_irq),
        .uart_tx_o        (uart_tx),
        .uart_rx_i        (uart_rx)
    );

    // =========================================================================
    // S3: Synthesizable 32-bit Timer Peripheral (axi_timer)
    // =========================================================================
    axi_timer #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH),
        .ID_WIDTH   (ID_WIDTH)
    ) u_timer (
        .clk            (clk),
        .rst            (rst),
        .s_axi_awid     (m03_axi_awid),
        .s_axi_awaddr   (m03_axi_awaddr),
        .s_axi_awlen    (m03_axi_awlen),
        .s_axi_awsize   (m03_axi_awsize),
        .s_axi_awburst  (m03_axi_awburst),
        .s_axi_awlock   (m03_axi_awlock),
        .s_axi_awcache  (m03_axi_awcache),
        .s_axi_awprot   (m03_axi_awprot),
        .s_axi_awqos    (m03_axi_awqos),
        .s_axi_awregion (m03_axi_awregion),
        .s_axi_awvalid  (m03_axi_awvalid),
        .s_axi_awready  (m03_axi_awready),
        .s_axi_wdata    (m03_axi_wdata),
        .s_axi_wstrb    (m03_axi_wstrb),
        .s_axi_wlast    (m03_axi_wlast),
        .s_axi_wvalid   (m03_axi_wvalid),
        .s_axi_wready   (m03_axi_wready),
        .s_axi_bid      (m03_axi_bid),
        .s_axi_bresp    (m03_axi_bresp),
        .s_axi_bvalid   (m03_axi_bvalid),
        .s_axi_bready   (m03_axi_bready),
        .s_axi_arid     (m03_axi_arid),
        .s_axi_araddr   (m03_axi_araddr),
        .s_axi_arlen    (m03_axi_arlen),
        .s_axi_arsize   (m03_axi_arsize),
        .s_axi_arburst  (m03_axi_arburst),
        .s_axi_arlock   (m03_axi_arlock),
        .s_axi_arcache  (m03_axi_arcache),
        .s_axi_arprot   (m03_axi_arprot),
        .s_axi_arqos    (m03_axi_arqos),
        .s_axi_arregion (m03_axi_arregion),
        .s_axi_arvalid  (m03_axi_arvalid),
        .s_axi_arready  (m03_axi_arready),
        .s_axi_rid      (m03_axi_rid),
        .s_axi_rdata    (m03_axi_rdata),
        .s_axi_rresp    (m03_axi_rresp),
        .s_axi_rlast    (m03_axi_rlast),
        .s_axi_rvalid   (m03_axi_rvalid),
        .s_axi_rready   (m03_axi_rready),
        .timer_irq      (timer_irq)
    );

    // =========================================================================
    // S4: Synthesizable 32-bit GPIO Peripheral (axi_gpio)
    // =========================================================================
    axi_gpio #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH),
        .ID_WIDTH   (ID_WIDTH),
        .GPIO_WIDTH (32)
    ) u_gpio (
        .clk            (clk),
        .rst            (rst),
        .s_axi_awid     (m04_axi_awid),
        .s_axi_awaddr   (m04_axi_awaddr),
        .s_axi_awlen    (m04_axi_awlen),
        .s_axi_awsize   (m04_axi_awsize),
        .s_axi_awburst  (m04_axi_awburst),
        .s_axi_awlock   (m04_axi_awlock),
        .s_axi_awcache  (m04_axi_awcache),
        .s_axi_awprot   (m04_axi_awprot),
        .s_axi_awqos    (m04_axi_awqos),
        .s_axi_awregion (m04_axi_awregion),
        .s_axi_awvalid  (m04_axi_awvalid),
        .s_axi_awready  (m04_axi_awready),
        .s_axi_wdata    (m04_axi_wdata),
        .s_axi_wstrb    (m04_axi_wstrb),
        .s_axi_wlast    (m04_axi_wlast),
        .s_axi_wvalid   (m04_axi_wvalid),
        .s_axi_wready   (m04_axi_wready),
        .s_axi_bid      (m04_axi_bid),
        .s_axi_bresp    (m04_axi_bresp),
        .s_axi_bvalid   (m04_axi_bvalid),
        .s_axi_bready   (m04_axi_bready),
        .s_axi_arid     (m04_axi_arid),
        .s_axi_araddr   (m04_axi_araddr),
        .s_axi_arlen    (m04_axi_arlen),
        .s_axi_arsize   (m04_axi_arsize),
        .s_axi_arburst  (m04_axi_arburst),
        .s_axi_arlock   (m04_axi_arlock),
        .s_axi_arcache  (m04_axi_arcache),
        .s_axi_arprot   (m04_axi_arprot),
        .s_axi_arqos    (m04_axi_arqos),
        .s_axi_arregion (m04_axi_arregion),
        .s_axi_arvalid  (m04_axi_arvalid),
        .s_axi_arready  (m04_axi_arready),
        .s_axi_rid      (m04_axi_rid),
        .s_axi_rdata    (m04_axi_rdata),
        .s_axi_rresp    (m04_axi_rresp),
        .s_axi_rlast    (m04_axi_rlast),
        .s_axi_rvalid   (m04_axi_rvalid),
        .s_axi_rready   (m04_axi_rready),
        .gpio_i         (gpio_i),
        .gpio_o         (gpio_o),
        .gpio_oe        (gpio_oe)
    );

endmodule

`default_nettype wire
