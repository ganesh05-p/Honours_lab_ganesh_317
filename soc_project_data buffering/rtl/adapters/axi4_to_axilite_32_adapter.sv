// =============================================================================
// File        : axi4_to_axilite_32_adapter.sv
// Project     : RISC-V VeeR EL2 Based Real-Time Data Buffering SoC
// Description : AXI4 32-bit to AXI4-Lite 32-bit protocol adapter.
//
// This module sits between the AXI4 interconnect master port (32-bit) and
// any AXI4-Lite 32-bit peripheral slave.  It is specifically wired to connect
// to axi_uart_top as the first peripheral, and is designed to be reused for
// GPIO, Timer, FIFO, Interrupt Controller, etc. by adjusting parameters.
//
// AXI4-Lite restrictions enforced by this adapter:
//   1. Burst length must be 1 (AWLEN/ARLEN == 0).  Bursts with AWLEN>0
//      receive SLVERR and are not forwarded to the peripheral.
//   2. AXI4 burst-type signals (AWLEN, AWSIZE, AWBURST, ARLEN, ARSIZE,
//      ARBURST) are not driven to the peripheral — they do not exist on
//      AXI4-Lite.
//   3. WLAST from the interconnect is accepted and discarded.
//   4. RLAST to the interconnect is always driven high (single-beat read).
//   5. AW and W channels are buffered independently; the downstream write
//      transaction is issued only when both are available.
//
// ID width mismatch:
//   Slave side (from interconnect): SLAVE_ID_WIDTH = 8 (default)
//   Master side (to peripheral):    PERIPH_ID_WIDTH = 12 (UART default)
//   Downstream ID is zero-padded; response ID is truncated.
//
// Address width:
//   Interconnect issues ADDR_WIDTH=32-bit addresses.
//   Only the lower PERIPH_ADDR_WIDTH bits are forwarded downstream.
//   UART: PERIPH_ADDR_WIDTH=5 (from `_AXI_UART_ADDR_WIDTH_`).
//
// Clocking: single synchronous clock domain.
// Reset   : active-low (matches VeeR and AXI4-Lite peripheral convention).
// =============================================================================

`default_nettype none

module axi4_to_axilite_32_adapter #(
    // AXI4 slave side (from interconnect)
    parameter int SLAVE_ID_WIDTH   = 8,   // interconnect default ID_WIDTH
    parameter int ADDR_WIDTH       = 32,  // full AXI4 address width

    // AXI4-Lite master side (to peripheral)
    parameter int PERIPH_ID_WIDTH  = 12,  // axi_uart_top: `_AXI_UART_ID_WIDTH_`
    parameter int PERIPH_ADDR_WIDTH = 5   // axi_uart_top: `_AXI_UART_ADDR_WIDTH_`
) (
    // -------------------------------------------------------------------------
    // Clock and reset
    // -------------------------------------------------------------------------
    input  logic                        clk,
    input  logic                        rst_l,      // active-low reset

    // =========================================================================
    // SLAVE side — AXI4, connects to axi_interconnect_wrap_2x8 master port
    // =========================================================================

    // --- Write address channel ---
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

    // --- Write data channel ---
    input  logic [31:0]                 s_axi_wdata,
    input  logic [3:0]                  s_axi_wstrb,
    input  logic                        s_axi_wlast,   // accepted & discarded
    input  logic                        s_axi_wvalid,
    output logic                        s_axi_wready,

    // --- Write response channel ---
    output logic [SLAVE_ID_WIDTH-1:0]   s_axi_bid,
    output logic [1:0]                  s_axi_bresp,
    output logic                        s_axi_bvalid,
    input  logic                        s_axi_bready,

    // --- Read address channel ---
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

    // --- Read data channel ---
    output logic [SLAVE_ID_WIDTH-1:0]   s_axi_rid,
    output logic [31:0]                 s_axi_rdata,
    output logic [1:0]                  s_axi_rresp,
    output logic                        s_axi_rlast,   // always 1 (single beat)
    output logic                        s_axi_rvalid,
    input  logic                        s_axi_rready,

    // =========================================================================
    // MASTER side — AXI4-Lite, connects to axi_uart_top (or other peripheral)
    // =========================================================================

    // --- Write address channel (AXI4-Lite: no burst signals) ---
    output logic [PERIPH_ID_WIDTH-1:0]   m_axi_awid,
    output logic [PERIPH_ADDR_WIDTH-1:0] m_axi_awaddr,
    output logic                         m_axi_awvalid,
    input  logic                         m_axi_awready,

    // --- Write data channel ---
    output logic [31:0]                  m_axi_wdata,
    output logic [3:0]                   m_axi_wstrb,
    output logic                         m_axi_wvalid,
    input  logic                         m_axi_wready,

    // --- Write response channel ---
    input  logic [PERIPH_ID_WIDTH-1:0]   m_axi_bid,
    input  logic [1:0]                   m_axi_bresp,
    input  logic                         m_axi_bvalid,
    output logic                         m_axi_bready,

    // --- Read address channel (AXI4-Lite: no burst signals) ---
    output logic [PERIPH_ID_WIDTH-1:0]   m_axi_arid,
    output logic [PERIPH_ADDR_WIDTH-1:0] m_axi_araddr,
    output logic                         m_axi_arvalid,
    input  logic                         m_axi_arready,

    // --- Read data channel ---
    input  logic [PERIPH_ID_WIDTH-1:0]   m_axi_rid,
    input  logic [31:0]                  m_axi_rdata,
    input  logic [1:0]                   m_axi_rresp,
    input  logic                         m_axi_rvalid,
    output logic                         m_axi_rready
);

    // =========================================================================
    // LOCAL PARAMETERS
    // =========================================================================
    localparam logic [1:0] RESP_OKAY   = 2'b00;
    localparam logic [1:0] RESP_SLVERR = 2'b10;

    // =========================================================================
    // TYPE DEFINITIONS
    // =========================================================================

    typedef enum logic [2:0] {
        WR_IDLE    = 3'd0,
        WR_WAIT_W  = 3'd1,   // AW buffered, waiting for W
        WR_WAIT_AW = 3'd2,   // W buffered, waiting for AW
        WR_ISSUE   = 3'd3,   // both ready, driving downstream
        WR_WAIT_B  = 3'd4,   // waiting for peripheral B response
        WR_RESP    = 3'd5    // forwarding B to interconnect
    } wr_state_t;

    typedef enum logic [1:0] {
        AR_IDLE   = 2'd0,
        AR_ISSUE  = 2'd1,
        AR_WAIT_R = 2'd2,
        AR_RESP   = 2'd3
    } ar_state_t;

    // =========================================================================
    // SIGNAL DECLARATIONS — all declared here to avoid forward-reference errors
    // =========================================================================

    // Write FSM
    wr_state_t                  wr_state;
    logic [SLAVE_ID_WIDTH-1:0]  wbuf_id;
    logic [ADDR_WIDTH-1:0]      wbuf_addr;
    logic                       wbuf_err;
    logic [31:0]                wbuf_data;
    logic [3:0]                 wbuf_strb;
    logic                       wr_aw_done;
    logic                       wr_w_done;
    logic                       wr_aw_accepted;
    logic                       wr_w_accepted;
    logic [1:0]                 m_axi_bresp_q;

    // Read FSM
    ar_state_t                  ar_state;
    logic [SLAVE_ID_WIDTH-1:0]  rbuf_id;
    logic [ADDR_WIDTH-1:0]      rbuf_addr;
    logic                       rbuf_err;
    logic [31:0]                rbuf_rdata;
    logic [1:0]                 rbuf_rresp;

    // =========================================================================
    // WRITE PATH STATE MACHINE
    // =========================================================================

    always_ff @(posedge clk) begin
        if (!rst_l) begin
            wr_state  <= WR_IDLE;
            wbuf_id   <= '0;
            wbuf_addr <= '0;
            wbuf_err  <= 1'b0;
            wbuf_data <= '0;
            wbuf_strb <= '0;
        end else begin
            case (wr_state)
                // ----------------------------------------------------------------
                WR_IDLE: begin
                    if (s_axi_awvalid && s_axi_wvalid) begin
                        // Both AW and W arrive in the same cycle
                        wbuf_id   <= s_axi_awid;
                        wbuf_addr <= s_axi_awaddr;
                        wbuf_err  <= (s_axi_awlen != 8'd0);
                        wbuf_data <= s_axi_wdata;
                        wbuf_strb <= s_axi_wstrb;
                        wr_state  <= WR_ISSUE;
                    end else if (s_axi_awvalid) begin
                        wbuf_id   <= s_axi_awid;
                        wbuf_addr <= s_axi_awaddr;
                        wbuf_err  <= (s_axi_awlen != 8'd0);
                        wr_state  <= WR_WAIT_W;
                    end else if (s_axi_wvalid) begin
                        wbuf_data <= s_axi_wdata;
                        wbuf_strb <= s_axi_wstrb;
                        wr_state  <= WR_WAIT_AW;
                    end
                end
                // ----------------------------------------------------------------
                WR_WAIT_W: begin
                    if (s_axi_wvalid) begin
                        wbuf_data <= s_axi_wdata;
                        wbuf_strb <= s_axi_wstrb;
                        wr_state  <= WR_ISSUE;
                    end
                end
                // ----------------------------------------------------------------
                WR_WAIT_AW: begin
                    if (s_axi_awvalid) begin
                        wbuf_id   <= s_axi_awid;
                        wbuf_addr <= s_axi_awaddr;
                        wbuf_err  <= (s_axi_awlen != 8'd0);
                        wr_state  <= WR_ISSUE;
                    end
                end
                // ----------------------------------------------------------------
                WR_ISSUE: begin
                    if (wbuf_err) begin
                        // Error path: skip peripheral, go straight to B response
                        wr_state <= WR_RESP;
                    end else if (wr_aw_accepted && wr_w_accepted) begin
                        wr_state <= WR_WAIT_B;
                    end
                end
                // ----------------------------------------------------------------
                WR_WAIT_B: begin
                    if (m_axi_bvalid) begin
                        wr_state <= WR_RESP;
                    end
                end
                // ----------------------------------------------------------------
                WR_RESP: begin
                    if (s_axi_bready) begin
                        wr_state <= WR_IDLE;
                    end
                end
                // ----------------------------------------------------------------
                default: wr_state <= WR_IDLE;
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // Track independent AW and W acceptance within WR_ISSUE
    // AXI4-Lite slave may accept AW and W in different cycles.
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rst_l) begin
            wr_aw_done <= 1'b0;
            wr_w_done  <= 1'b0;
        end else begin
            // Reset acceptance flags at the start of each transaction
            if (wr_state == WR_IDLE || wr_state == WR_WAIT_W ||
                wr_state == WR_WAIT_AW) begin
                wr_aw_done <= 1'b0;
                wr_w_done  <= 1'b0;
            end else if (wr_state == WR_ISSUE) begin
                if (m_axi_awvalid && m_axi_awready) wr_aw_done <= 1'b1;
                if (m_axi_wvalid  && m_axi_wready)  wr_w_done  <= 1'b1;
            end
        end
    end

    // Combinational: include current-cycle handshakes
    assign wr_aw_accepted = wr_aw_done || (m_axi_awvalid && m_axi_awready);
    assign wr_w_accepted  = wr_w_done  || (m_axi_wvalid  && m_axi_wready);

    // -------------------------------------------------------------------------
    // Slave-side AW/W ready
    // -------------------------------------------------------------------------
    assign s_axi_awready = (wr_state == WR_IDLE) || (wr_state == WR_WAIT_AW);
    assign s_axi_wready  = (wr_state == WR_IDLE) || (wr_state == WR_WAIT_W);

    // -------------------------------------------------------------------------
    // Downstream AXI4-Lite write channel outputs
    // -------------------------------------------------------------------------
    assign m_axi_awvalid = (wr_state == WR_ISSUE) && !wbuf_err && !wr_aw_done;
    assign m_axi_awid    = {{(PERIPH_ID_WIDTH-SLAVE_ID_WIDTH){1'b0}}, wbuf_id};
    assign m_axi_awaddr  = wbuf_addr[PERIPH_ADDR_WIDTH-1:0];

    assign m_axi_wvalid  = (wr_state == WR_ISSUE) && !wbuf_err && !wr_w_done;
    assign m_axi_wdata   = wbuf_data;
    assign m_axi_wstrb   = wbuf_strb;

    // -------------------------------------------------------------------------
    // Latch peripheral B response (arrives during WR_WAIT_B)
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rst_l) begin
            m_axi_bresp_q <= RESP_OKAY;
        end else if (m_axi_bvalid && m_axi_bready) begin
            m_axi_bresp_q <= m_axi_bresp;
        end
    end

    assign m_axi_bready = (wr_state == WR_WAIT_B);

    // -------------------------------------------------------------------------
    // Write response back to interconnect
    // -------------------------------------------------------------------------
    assign s_axi_bvalid = (wr_state == WR_RESP);
    assign s_axi_bid    = wbuf_id;
    assign s_axi_bresp  = wbuf_err ? RESP_SLVERR : m_axi_bresp_q;

    // =========================================================================
    // READ PATH STATE MACHINE
    // =========================================================================

    always_ff @(posedge clk) begin
        if (!rst_l) begin
            ar_state   <= AR_IDLE;
            rbuf_id    <= '0;
            rbuf_addr  <= '0;
            rbuf_err   <= 1'b0;
            rbuf_rdata <= '0;
            rbuf_rresp <= RESP_OKAY;
        end else begin
            case (ar_state)
                // ----------------------------------------------------------------
                AR_IDLE: begin
                    if (s_axi_arvalid) begin
                        rbuf_id   <= s_axi_arid;
                        rbuf_addr <= s_axi_araddr;
                        rbuf_err  <= (s_axi_arlen != 8'd0);
                        ar_state  <= AR_ISSUE;
                    end
                end
                // ----------------------------------------------------------------
                AR_ISSUE: begin
                    if (rbuf_err) begin
                        // Error: manufacture SLVERR response, skip peripheral
                        rbuf_rdata <= 32'd0;
                        rbuf_rresp <= RESP_SLVERR;
                        ar_state   <= AR_RESP;
                    end else if (m_axi_arready) begin
                        ar_state <= AR_WAIT_R;
                    end
                end
                // ----------------------------------------------------------------
                AR_WAIT_R: begin
                    if (m_axi_rvalid) begin
                        rbuf_rdata <= m_axi_rdata;
                        rbuf_rresp <= m_axi_rresp;
                        ar_state   <= AR_RESP;
                    end
                end
                // ----------------------------------------------------------------
                AR_RESP: begin
                    if (s_axi_rready) begin
                        ar_state <= AR_IDLE;
                    end
                end
                // ----------------------------------------------------------------
                default: ar_state <= AR_IDLE;
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // Slave-side AR ready
    // -------------------------------------------------------------------------
    assign s_axi_arready = (ar_state == AR_IDLE);

    // -------------------------------------------------------------------------
    // Downstream AXI4-Lite read channel outputs
    // -------------------------------------------------------------------------
    assign m_axi_arvalid = (ar_state == AR_ISSUE) && !rbuf_err;
    assign m_axi_arid    = {{(PERIPH_ID_WIDTH-SLAVE_ID_WIDTH){1'b0}}, rbuf_id};
    assign m_axi_araddr  = rbuf_addr[PERIPH_ADDR_WIDTH-1:0];

    // Accept peripheral R data (one-shot into rbuf)
    assign m_axi_rready  = (ar_state == AR_WAIT_R);

    // -------------------------------------------------------------------------
    // Read response back to interconnect
    // -------------------------------------------------------------------------
    assign s_axi_rvalid = (ar_state == AR_RESP);
    assign s_axi_rid    = rbuf_id;
    assign s_axi_rdata  = rbuf_rdata;
    assign s_axi_rresp  = rbuf_rresp;
    assign s_axi_rlast  = 1'b1;   // always single-beat for AXI4-Lite peripheral

endmodule : axi4_to_axilite_32_adapter

`default_nettype wire
