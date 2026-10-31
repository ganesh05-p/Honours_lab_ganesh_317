// =============================================================================
// File        : axi4_to_dma_reg_adapter.sv
// Project     : RISC-V VeeR EL2 Based Real-Time Data Buffering SoC
// Description : AXI4 slave (32-bit, ID=8) to dma_top custom register
//               interface adapter.
//
// ┌─────────────────────────────────────────────────────────────────────┐
// │  PROBLEM BEING SOLVED                                               │
// │                                                                     │
// │  dma_top does NOT have an AXI4 slave port.  It exposes a flat,     │
// │  strobe-based register interface:                                   │
// │    reg_wr_en  — one-cycle write-strobe                              │
// │    reg_rd_en  — one-cycle read-strobe                               │
// │    reg_addr   — 12-bit word address (covers 4 KiB)                 │
// │    reg_wr_data — 32-bit write data                                  │
// │    reg_rd_data / reg_rd_valid — read return path                   │
// │                                                                     │
// │  This adapter sits between axi_interconnect_wrap_2x8 master port   │
// │  m03 (DMA_CFG, base 0x3000_0000, window 16 MB) and those signals.  │
// │                                                                     │
// │  ┌──────────────────┐  m03_axi_*  ┌─────────────────────────────┐  │
// │  │  interconnect    │ ──────────► │  axi4_to_dma_reg_adapter    │  │
// │  │  (axi4, 32-bit)  │ ◄────────── │                             │  │
// │  └──────────────────┘             └──────────┬──────────────────┘  │
// │                                              │ reg_wr_en / rd_en   │
// │                                              ▼                     │
// │                                        ┌─────────┐                 │
// │                                        │ dma_top │                 │
// │                                        └─────────┘                 │
// └─────────────────────────────────────────────────────────────────────┘
//
// Protocol contract:
//   • Only single-beat transactions (AWLEN = 0 / ARLEN = 0) are forwarded.
//     Bursts are rejected with SLVERR on the B / R channel.
//   • reg_addr = s_axi_awaddr[13:2]  (byte → 32-bit word, 12 bits).
//   • Write flow  : AW+W accepted → reg_wr_en pulsed for 1 cycle → B sent.
//   • Read flow   : AR accepted → reg_rd_en pulsed for 1 cycle → wait
//                  reg_rd_valid → R sent with reg_rd_data.
//   • AXI IDs are reflected back unchanged.
//   • Write and read state machines operate independently (no mutual
//     exclusion needed; DMA reg file is single-ported but write/read
//     happen in distinct AXI transactions).
//
// Clocking : single synchronous clock domain.
// Reset    : rst — active-HIGH synchronous (matches interconnect).
// =============================================================================

`default_nettype none
`timescale 1ns / 1ps

module axi4_to_dma_reg_adapter #(
    parameter int SLAVE_ID_WIDTH = 8,   // must equal interconnect ID_WIDTH
    parameter int ADDR_WIDTH     = 32,
    parameter int DATA_WIDTH     = 32   // fixed; must equal DMA DATA_W
) (
    input  logic                        clk,
    input  logic                        rst,        // active-HIGH synchronous

    // =========================================================================
    // SLAVE side — AXI4 32-bit, from axi_interconnect_wrap_2x8 port m03_axi_*
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
    // MASTER side — dma_top custom register interface
    // =========================================================================
    output logic                        reg_wr_en,
    output logic                        reg_rd_en,
    output logic [11:0]                 reg_addr,
    output logic [DATA_WIDTH-1:0]       reg_wr_data,
    input  logic [DATA_WIDTH-1:0]       reg_rd_data,
    input  logic                        reg_rd_valid
);

    // -------------------------------------------------------------------------
    // AXI response codes
    // -------------------------------------------------------------------------
    localparam logic [1:0] RESP_OKAY   = 2'b00;
    localparam logic [1:0] RESP_SLVERR = 2'b10;

    // =========================================================================
    //  WRITE PATH FSM
    //  States: IDLE → ADDR (got AW, wait W) → EXEC (pulse wr_en) → RESP
    //          IDLE → BOTH (AW+W same cycle) → EXEC → RESP
    // =========================================================================
    typedef enum logic [2:0] {
        WS_IDLE = 3'd0,
        WS_ADDR = 3'd1,   // AW accepted, W not yet
        WS_DATA = 3'd2,   // W accepted, AW not yet
        WS_EXEC = 3'd3,   // issue reg_wr_en
        WS_RESP = 3'd4    // drive B channel
    } wr_state_t;

    wr_state_t wr_state, wr_state_nxt;

    // Captured write-path registers
    logic [SLAVE_ID_WIDTH-1:0] wr_id_r;
    logic [11:0]               wr_reg_addr_r;
    logic [DATA_WIDTH-1:0]     wr_data_r;
    logic [DATA_WIDTH/8-1:0]   wr_strb_r;
    logic                      wr_burst_err_r;   // 1 → AWLEN != 0

    // Sequential
    always_ff @(posedge clk) begin
        if (rst) begin
            wr_state       <= WS_IDLE;
            wr_id_r        <= '0;
            wr_reg_addr_r  <= '0;
            wr_data_r      <= '0;
            wr_strb_r      <= '0;
            wr_burst_err_r <= 1'b0;
        end else begin
            wr_state <= wr_state_nxt;

            // Capture AW payload whenever it is accepted
            if ((wr_state == WS_IDLE || wr_state == WS_DATA) &&
                 s_axi_awvalid && s_axi_awready) begin
                wr_id_r        <= s_axi_awid;
                wr_reg_addr_r  <= s_axi_awaddr[11:0];   // byte addr (12 b) matching dma_reg_file
                wr_burst_err_r <= (s_axi_awlen != 8'h00);
            end

            // Capture W payload whenever it is accepted
            if ((wr_state == WS_IDLE || wr_state == WS_ADDR) &&
                 s_axi_wvalid && s_axi_wready) begin
                wr_data_r <= s_axi_wdata;
                wr_strb_r <= s_axi_wstrb;
            end
        end
    end

    // Combinational
    always_comb begin
        wr_state_nxt  = wr_state;
        s_axi_awready = 1'b0;
        s_axi_wready  = 1'b0;
        s_axi_bvalid  = 1'b0;
        s_axi_bid     = wr_id_r;
        s_axi_bresp   = wr_burst_err_r ? RESP_SLVERR : RESP_OKAY;
        reg_wr_en     = 1'b0;

        case (wr_state)
            WS_IDLE: begin
                s_axi_awready = 1'b1;
                s_axi_wready  = 1'b1;
                if (s_axi_awvalid && s_axi_wvalid)
                    wr_state_nxt = WS_EXEC;       // got both channels at once
                else if (s_axi_awvalid)
                    wr_state_nxt = WS_ADDR;
                else if (s_axi_wvalid)
                    wr_state_nxt = WS_DATA;
            end

            WS_ADDR: begin
                // Waiting for W channel
                s_axi_wready = 1'b1;
                if (s_axi_wvalid)
                    wr_state_nxt = WS_EXEC;
            end

            WS_DATA: begin
                // Waiting for AW channel
                s_axi_awready = 1'b1;
                if (s_axi_awvalid)
                    wr_state_nxt = WS_EXEC;
            end

            WS_EXEC: begin
                // One-cycle register write pulse (skip for burst error)
                reg_wr_en    = !wr_burst_err_r;
                wr_state_nxt = WS_RESP;
            end

            WS_RESP: begin
                s_axi_bvalid = 1'b1;
                if (s_axi_bready)
                    wr_state_nxt = WS_IDLE;
            end

            default: wr_state_nxt = WS_IDLE;
        endcase
    end

    // =========================================================================
    //  READ PATH FSM
    //  States: IDLE → ISSUE (pulse rd_en) → WAIT (for reg_rd_valid) → RDATA
    // =========================================================================
    typedef enum logic [1:0] {
        RS_IDLE  = 2'd0,
        RS_ISSUE = 2'd1,
        RS_WAIT  = 2'd2,
        RS_RDATA = 2'd3
    } rd_state_t;

    rd_state_t rd_state, rd_state_nxt;

    logic [SLAVE_ID_WIDTH-1:0] rd_id_r;
    logic [11:0]               rd_reg_addr_r;
    logic [DATA_WIDTH-1:0]     rd_data_r;
    logic                      rd_burst_err_r;

    // Sequential
    always_ff @(posedge clk) begin
        if (rst) begin
            rd_state      <= RS_IDLE;
            rd_id_r       <= '0;
            rd_reg_addr_r <= '0;
            rd_data_r     <= '0;
            rd_burst_err_r<= 1'b0;
        end else begin
            rd_state <= rd_state_nxt;

            if (rd_state == RS_IDLE && s_axi_arvalid && s_axi_arready) begin
                rd_id_r        <= s_axi_arid;
                rd_reg_addr_r  <= s_axi_araddr[11:0];   // byte addr (12 b) matching dma_reg_file
                rd_burst_err_r <= (s_axi_arlen != 8'h00);
            end

            // Latch read data when reg_rd_valid arrives (or zeros on error)
            if (rd_state == RS_WAIT && (reg_rd_valid || rd_burst_err_r))
                rd_data_r <= rd_burst_err_r ? '0 : reg_rd_data;
        end
    end

    // Combinational
    always_comb begin
        rd_state_nxt  = rd_state;
        s_axi_arready = 1'b0;
        s_axi_rvalid  = 1'b0;
        s_axi_rid     = rd_id_r;
        s_axi_rdata   = rd_data_r;
        s_axi_rresp   = rd_burst_err_r ? RESP_SLVERR : RESP_OKAY;
        s_axi_rlast   = 1'b1;      // always single-beat
        reg_rd_en     = 1'b0;

        case (rd_state)
            RS_IDLE: begin
                s_axi_arready = 1'b1;
                if (s_axi_arvalid)
                    rd_state_nxt = RS_ISSUE;
            end

            RS_ISSUE: begin
                reg_rd_en    = !rd_burst_err_r;
                rd_state_nxt = RS_WAIT;
            end

            RS_WAIT: begin
                if (reg_rd_valid || rd_burst_err_r)
                    rd_state_nxt = RS_RDATA;
            end

            RS_RDATA: begin
                s_axi_rvalid = 1'b1;
                if (s_axi_rready)
                    rd_state_nxt = RS_IDLE;
            end

            default: rd_state_nxt = RS_IDLE;
        endcase
    end

    // =========================================================================
    //  reg_addr mux  — write and read paths share the single address output.
    //  The DMA register file is single-ported; only one strobe fires per cycle.
    // =========================================================================
    always_comb begin
        if (wr_state == WS_EXEC)
            reg_addr = wr_reg_addr_r;
        else
            reg_addr = rd_reg_addr_r;
    end

    // reg_wr_data is driven from the captured write data
    assign reg_wr_data = wr_data_r;

endmodule

`default_nettype wire
