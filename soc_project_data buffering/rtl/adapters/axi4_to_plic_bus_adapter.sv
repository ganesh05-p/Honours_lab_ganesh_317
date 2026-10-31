// =============================================================================
// File        : axi4_to_plic_bus_adapter.sv
// Project     : RISC-V VeeR EL2 Based Real-Time Data Buffering SoC
// Description : AXI4 slave (32-bit, ID=8) to plic_top custom bus interface
//               adapter.
//
// ┌─────────────────────────────────────────────────────────────────────┐
// │  PROBLEM BEING SOLVED                                               │
// │                                                                     │
// │  plic_top does NOT have an AXI4 slave port.  It exposes a simple   │
// │  valid/ready register bus:                                          │
// │    bus_valid  — asserted while address + data + we are stable       │
// │    bus_ready  — PLIC asserts when it has accepted the request       │
// │    bus_addr   — 26-bit byte address                                 │
// │    bus_wdata  — 32-bit write data                                   │
// │    bus_rdata  — 32-bit read data (valid when bus_ready & !bus_we)  │
// │    bus_we     — 1 = write, 0 = read                                 │
// │                                                                     │
// │  This adapter sits between axi_interconnect_wrap_2x8 master port   │
// │  m04 (INTCTL, base 0x4000_0000, window 16 MB) and those signals.   │
// │                                                                     │
// │  ┌──────────────────┐  m04_axi_*  ┌────────────────────────────┐   │
// │  │  interconnect    │ ──────────► │  axi4_to_plic_bus_adapter  │   │
// │  │  (axi4, 32-bit)  │ ◄────────── │                            │   │
// │  └──────────────────┘             └─────────────┬──────────────┘   │
// │                                                 │ bus_valid/ready  │
// │                                                 ▼                  │
// │                                           ┌──────────┐             │
// │                                           │ plic_top │             │
// │                                           └──────────┘             │
// └─────────────────────────────────────────────────────────────────────┘
//
// Protocol contract:
//   • Only single-beat transactions (AWLEN = 0 / ARLEN = 0) are forwarded.
//     Bursts are rejected with SLVERR.
//   • bus_addr = s_axi_awaddr[25:0]  (lower 26 bits of the 32-bit address).
//   • Write flow : AW+W accepted → bus_valid=1, bus_we=1, hold until
//                  bus_ready → B channel sent.
//   • Read flow  : AR accepted → bus_valid=1, bus_we=0, hold until
//                  bus_ready → latch bus_rdata → R channel sent.
//   • AXI IDs reflected back unchanged.
//
// Clocking : single synchronous clock domain.
// Reset    : rst — active-HIGH synchronous (matches interconnect).
// =============================================================================

`default_nettype none
`timescale 1ns / 1ps

module axi4_to_plic_bus_adapter #(
    parameter int SLAVE_ID_WIDTH  = 8,   // must equal interconnect ID_WIDTH
    parameter int ADDR_WIDTH      = 32,
    parameter int DATA_WIDTH      = 32,  // fixed; must equal PLIC DATA_WIDTH
    parameter int PLIC_ADDR_WIDTH = 26   // must equal PLIC ADDR_WIDTH parameter
) (
    input  logic                        clk,
    input  logic                        rst,        // active-HIGH synchronous

    // =========================================================================
    // SLAVE side — AXI4 32-bit, from axi_interconnect_wrap_2x8 port m04_axi_*
    // =========================================================================

    // Write address channel
    input  logic [SLAVE_ID_WIDTH-1:0]   s_axi_awid,
    input  logic [ADDR_WIDTH-1:0]       s_axi_awaddr,
    input  logic [7:0]                  s_axi_awlen,
    input  logic [2:0]                  s_axi_awsize,
    input  logic [1:0]                  s_axi_awburst,
    input  logic                        s_axi_awlock,
    input  logic [3:0]                  s_axi_awcache,
    input  logic [2:0]                  s_axi_awprot,
    input  logic [3:0]                  s_axi_awqos,
    input  logic [3:0]                  s_axi_awregion,
    input  logic                        s_axi_awvalid,
    output logic                        s_axi_awready,

    // Write data channel
    input  logic [DATA_WIDTH-1:0]       s_axi_wdata,
    input  logic [DATA_WIDTH/8-1:0]     s_axi_wstrb,
    input  logic                        s_axi_wlast,
    input  logic                        s_axi_wvalid,
    output logic                        s_axi_wready,

    // Write response channel
    output logic [SLAVE_ID_WIDTH-1:0]   s_axi_bid,
    output logic [1:0]                  s_axi_bresp,
    output logic                        s_axi_bvalid,
    input  logic                        s_axi_bready,

    // Read address channel
    input  logic [SLAVE_ID_WIDTH-1:0]   s_axi_arid,
    input  logic [ADDR_WIDTH-1:0]       s_axi_araddr,
    input  logic [7:0]                  s_axi_arlen,
    input  logic [2:0]                  s_axi_arsize,
    input  logic [1:0]                  s_axi_arburst,
    input  logic                        s_axi_arlock,
    input  logic [3:0]                  s_axi_arcache,
    input  logic [2:0]                  s_axi_arprot,
    input  logic [3:0]                  s_axi_arqos,
    input  logic [3:0]                  s_axi_arregion,
    input  logic                        s_axi_arvalid,
    output logic                        s_axi_arready,

    // Read data channel
    output logic [SLAVE_ID_WIDTH-1:0]   s_axi_rid,
    output logic [DATA_WIDTH-1:0]       s_axi_rdata,
    output logic [1:0]                  s_axi_rresp,
    output logic                        s_axi_rlast,
    output logic                        s_axi_rvalid,
    input  logic                        s_axi_rready,

    // =========================================================================
    // MASTER side — plic_top custom bus interface
    // =========================================================================
    output logic                         bus_valid,
    input  logic                         bus_ready,
    output logic [PLIC_ADDR_WIDTH-1:0]   bus_addr,
    output logic [DATA_WIDTH-1:0]        bus_wdata,
    input  logic [DATA_WIDTH-1:0]        bus_rdata,
    output logic                         bus_we
);

    // -------------------------------------------------------------------------
    // AXI response codes
    // -------------------------------------------------------------------------
    localparam logic [1:0] RESP_OKAY   = 2'b00;
    localparam logic [1:0] RESP_SLVERR = 2'b10;

    // =========================================================================
    //  UNIFIED FSM
    //  The PLIC bus is not split by direction; a single valid/ready handshake
    //  covers both reads and writes.  We therefore use one FSM that handles
    //  both paths, prioritising writes when both arrive simultaneously.
    //
    //  States:
    //    IDLE    — waiting for AW or AR
    //    WR_ADDR — got AW, waiting for W
    //    WR_DATA — got W (without AW), waiting for AW
    //    BUS_TXN — drive bus_valid (write or read); wait bus_ready
    //    WR_RESP — send B channel
    //    RD_WAIT — latch bus_rdata (combinatorially available when bus_ready)
    //    RD_RESP — send R channel
    // =========================================================================
    typedef enum logic [2:0] {
        ST_IDLE    = 3'd0,
        ST_WR_ADDR = 3'd1,
        ST_WR_DATA = 3'd2,
        ST_BUS_TXN = 3'd3,
        ST_WR_RESP = 3'd4,
        ST_RD_RESP = 3'd5
    } state_t;

    state_t state, state_nxt;

    // Transaction-info registers
    logic [SLAVE_ID_WIDTH-1:0]  txn_id_r;
    logic [PLIC_ADDR_WIDTH-1:0] txn_addr_r;
    logic [DATA_WIDTH-1:0]      txn_wdata_r;
    logic [DATA_WIDTH-1:0]      txn_rdata_r;
    logic                       txn_is_write_r;
    logic                       txn_burst_err_r;

    // Sequential element
    always_ff @(posedge clk) begin
        if (rst) begin
            state           <= ST_IDLE;
            txn_id_r        <= '0;
            txn_addr_r      <= '0;
            txn_wdata_r     <= '0;
            txn_rdata_r     <= '0;
            txn_is_write_r  <= 1'b0;
            txn_burst_err_r <= 1'b0;
        end else begin
            state <= state_nxt;

            // Capture AW info
            if ((state == ST_IDLE || state == ST_WR_DATA) &&
                 s_axi_awvalid && s_axi_awready) begin
                txn_id_r        <= s_axi_awid;
                txn_addr_r      <= s_axi_awaddr[PLIC_ADDR_WIDTH-1:0];
                txn_is_write_r  <= 1'b1;
                txn_burst_err_r <= (s_axi_awlen != 8'h00);
            end

            // Capture AR info (only when not also capturing AW this cycle)
            if (state == ST_IDLE && s_axi_arvalid && s_axi_arready &&
                !(s_axi_awvalid && s_axi_awready)) begin
                txn_id_r        <= s_axi_arid;
                txn_addr_r      <= s_axi_araddr[PLIC_ADDR_WIDTH-1:0];
                txn_is_write_r  <= 1'b0;
                txn_burst_err_r <= (s_axi_arlen != 8'h00);
            end

            // Capture W data
            if ((state == ST_IDLE || state == ST_WR_ADDR) &&
                 s_axi_wvalid && s_axi_wready)
                txn_wdata_r <= s_axi_wdata;

            // Latch PLIC read data when bus transaction completes
            if (state == ST_BUS_TXN && bus_ready && !txn_is_write_r)
                txn_rdata_r <= bus_rdata;
        end
    end

    // Combinational FSM outputs
    always_comb begin
        state_nxt     = state;

        // AXI channel defaults
        s_axi_awready = 1'b0;
        s_axi_wready  = 1'b0;
        s_axi_bvalid  = 1'b0;
        s_axi_bid     = txn_id_r;
        s_axi_bresp   = txn_burst_err_r ? RESP_SLVERR : RESP_OKAY;
        s_axi_arready = 1'b0;
        s_axi_rvalid  = 1'b0;
        s_axi_rid     = txn_id_r;
        s_axi_rdata   = txn_rdata_r;
        s_axi_rresp   = txn_burst_err_r ? RESP_SLVERR : RESP_OKAY;
        s_axi_rlast   = 1'b1;

        // PLIC bus defaults
        bus_valid  = 1'b0;
        bus_addr   = txn_addr_r;
        bus_wdata  = txn_wdata_r;
        bus_we     = txn_is_write_r;

        case (state)
            ST_IDLE: begin
                // Accept both AW+W simultaneously, or AW alone, or AR
                s_axi_awready = 1'b1;
                s_axi_wready  = 1'b1;
                s_axi_arready = !s_axi_awvalid; // AR only when no write pending

                if (s_axi_awvalid && s_axi_wvalid) begin
                    // Write: both channels at once
                    state_nxt = ST_BUS_TXN;
                end else if (s_axi_awvalid) begin
                    // Write: have AW, wait for W
                    s_axi_wready  = 1'b0;
                    s_axi_arready = 1'b0;
                    state_nxt     = ST_WR_ADDR;
                end else if (s_axi_wvalid) begin
                    // Write: have W, wait for AW
                    s_axi_awready = 1'b0;
                    s_axi_arready = 1'b0;
                    state_nxt     = ST_WR_DATA;
                end else if (s_axi_arvalid) begin
                    // Read
                    state_nxt = ST_BUS_TXN;
                end
            end

            ST_WR_ADDR: begin
                // Waiting for W channel (have AW)
                s_axi_wready = 1'b1;
                if (s_axi_wvalid)
                    state_nxt = ST_BUS_TXN;
            end

            ST_WR_DATA: begin
                // Waiting for AW channel (have W)
                s_axi_awready = 1'b1;
                if (s_axi_awvalid)
                    state_nxt = ST_BUS_TXN;
            end

            ST_BUS_TXN: begin
                // Drive PLIC bus; hold until bus_ready (or bypass on burst error)
                if (txn_burst_err_r) begin
                    // Skip PLIC access, go straight to response
                    state_nxt = txn_is_write_r ? ST_WR_RESP : ST_RD_RESP;
                end else begin
                    bus_valid = 1'b1;
                    if (bus_ready)
                        state_nxt = txn_is_write_r ? ST_WR_RESP : ST_RD_RESP;
                end
            end

            ST_WR_RESP: begin
                s_axi_bvalid = 1'b1;
                if (s_axi_bready)
                    state_nxt = ST_IDLE;
            end

            ST_RD_RESP: begin
                s_axi_rvalid = 1'b1;
                if (s_axi_rready)
                    state_nxt = ST_IDLE;
            end

            default: state_nxt = ST_IDLE;
        endcase
    end

endmodule

`default_nettype wire
