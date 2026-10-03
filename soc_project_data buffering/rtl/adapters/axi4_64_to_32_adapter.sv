// =============================================================================
// File        : axi4_64_to_32_adapter.sv
// Project     : RISC-V VeeR EL2 Based Real-Time Data Buffering SoC
// Description : AXI4 64-bit data width to 32-bit data width adapter.
//
// This module sits between the VeeR EL2 AXI4 master (64-bit data bus) and
// the existing 32-bit AXI4 interconnect (axi_interconnect_wrap_2x8).
//
// The same module can be instantiated for both LSU and IFU AXI masters by
// setting SLAVE_ID_WIDTH to match pt.LSU_BUS_TAG or pt.IFU_BUS_TAG
// (default 4 for both in the standard VeeR EL2 configuration).
//
// Key conversions performed:
//   - Data   : 64-bit -> 32-bit  (beat splitting: 1x 64-bit -> 2x 32-bit)
//   - WSTRB  : 8-bit  -> 4-bit   (lower [3:0] for beat-0, upper [7:4] for beat-1)
//   - AWLEN  : doubled           (each upstream beat becomes 2 downstream beats)
//   - AWSIZE : capped at 3'b010  (4 bytes = 32-bit maximum)
//   - AWID   : zero-padded from SLAVE_ID_WIDTH to MASTER_ID_WIDTH bits
//   - All other sideband signals (BURST, LOCK, CACHE, PROT, QOS) passed through.
//   - WLAST  : asserted on the high sub-beat of the last upstream beat.
//   - RLAST  : asserted to VeeR when the assembled 64-bit read word is the last.
//
// Read path: pairs of 32-bit downstream beats are re-assembled into one 64-bit
// word before returning to VeeR.  RRESP is the bitwise OR of both sub-beats.
//
// Clocking: single clock domain.
// Reset   : active-low synchronous (matches VeeR rst_l).
// =============================================================================

`default_nettype none

module axi4_64_to_32_adapter #(
    // ID width from VeeR (pt.LSU_BUS_TAG / pt.IFU_BUS_TAG, default 4)
    parameter int SLAVE_ID_WIDTH  = 4,
    // ID width required by the interconnect (axi_interconnect_wrap_2x8 default)
    parameter int MASTER_ID_WIDTH = 8,
    // AXI address width (both VeeR and interconnect use 32-bit addresses)
    parameter int ADDR_WIDTH      = 32
) (
    // -------------------------------------------------------------------------
    // Clock and reset
    // -------------------------------------------------------------------------
    input  logic                        clk,
    input  logic                        rst_l,      // active-low reset (VeeR style)

    // =========================================================================
    // SLAVE side — connects to VeeR EL2 lsu_axi_* / ifu_axi_* (64-bit)
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
    input  logic [63:0]                 s_axi_wdata,
    input  logic [7:0]                  s_axi_wstrb,
    input  logic                        s_axi_wlast,
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
    output logic [63:0]                 s_axi_rdata,
    output logic [1:0]                  s_axi_rresp,
    output logic                        s_axi_rlast,
    output logic                        s_axi_rvalid,
    input  logic                        s_axi_rready,

    // =========================================================================
    // MASTER side — connects to axi_interconnect_wrap_2x8 slave port (32-bit)
    // =========================================================================

    // --- Write address channel ---
    output logic [MASTER_ID_WIDTH-1:0]  m_axi_awid,
    output logic [ADDR_WIDTH-1:0]       m_axi_awaddr,
    output logic [7:0]                  m_axi_awlen,
    output logic [2:0]                  m_axi_awsize,
    output logic [1:0]                  m_axi_awburst,
    output logic                        m_axi_awlock,
    output logic [3:0]                  m_axi_awcache,
    output logic [2:0]                  m_axi_awprot,
    output logic [3:0]                  m_axi_awqos,
    output logic                        m_axi_awvalid,
    input  logic                        m_axi_awready,

    // --- Write data channel ---
    output logic [31:0]                 m_axi_wdata,
    output logic [3:0]                  m_axi_wstrb,
    output logic                        m_axi_wlast,
    output logic                        m_axi_wvalid,
    input  logic                        m_axi_wready,

    // --- Write response channel ---
    input  logic [MASTER_ID_WIDTH-1:0]  m_axi_bid,
    input  logic [1:0]                  m_axi_bresp,
    input  logic                        m_axi_bvalid,
    output logic                        m_axi_bready,

    // --- Read address channel ---
    output logic [MASTER_ID_WIDTH-1:0]  m_axi_arid,
    output logic [ADDR_WIDTH-1:0]       m_axi_araddr,
    output logic [7:0]                  m_axi_arlen,
    output logic [2:0]                  m_axi_arsize,
    output logic [1:0]                  m_axi_arburst,
    output logic                        m_axi_arlock,
    output logic [3:0]                  m_axi_arcache,
    output logic [2:0]                  m_axi_arprot,
    output logic [3:0]                  m_axi_arqos,
    output logic                        m_axi_arvalid,
    input  logic                        m_axi_arready,

    // --- Read data channel ---
    input  logic [MASTER_ID_WIDTH-1:0]  m_axi_rid,
    input  logic [31:0]                 m_axi_rdata,
    input  logic [1:0]                  m_axi_rresp,
    input  logic                        m_axi_rlast,
    input  logic                        m_axi_rvalid,
    output logic                        m_axi_rready
);

    // =========================================================================
    // Internal reset (active-low -> active-high for internal use)
    // =========================================================================
    logic rst;
    assign rst = ~rst_l;

    // =========================================================================
    // TYPE DEFINITIONS
    // =========================================================================

    typedef enum logic [1:0] {
        AW_IDLE  = 2'd0,
        AW_ISSUE = 2'd1,
        AW_DONE  = 2'd2
    } aw_state_t;

    typedef enum logic [1:0] {
        AR_IDLE   = 2'd0,
        AR_ISSUE  = 2'd1,
        AR_ACTIVE = 2'd2
    } ar_state_t;

    // =========================================================================
    // SIGNAL DECLARATIONS — all declared here to avoid forward-reference errors
    // =========================================================================

    // AW FSM
    aw_state_t                  aw_state;
    logic [SLAVE_ID_WIDTH-1:0]  aw_id_q;
    logic [ADDR_WIDTH-1:0]      aw_addr_q;
    logic [7:0]                 aw_len_q;
    logic [2:0]                 aw_size_q;
    logic [1:0]                 aw_burst_q;
    logic                       aw_lock_q;
    logic [3:0]                 aw_cache_q;
    logic [2:0]                 aw_prot_q;
    logic [3:0]                 aw_qos_q;
    logic [7:0]                 aw_len_ds;

    // W channel
    logic                       w_sub_beat;
    logic                       w_burst_done;
    logic [7:0]                 w_beats_remaining;
    logic [63:0]                w_data_q;
    logic [7:0]                 w_strb_q;
    logic                       w_last_q;
    logic                       w_data_held;

    // AR FSM
    ar_state_t                  ar_state;
    logic [SLAVE_ID_WIDTH-1:0]  ar_id_q;
    logic [ADDR_WIDTH-1:0]      ar_addr_q;
    logic [7:0]                 ar_len_q;
    logic [2:0]                 ar_size_q;
    logic [1:0]                 ar_burst_q;
    logic                       ar_lock_q;
    logic [3:0]                 ar_cache_q;
    logic [2:0]                 ar_prot_q;
    logic [3:0]                 ar_qos_q;
    logic [7:0]                 ar_len_ds;

    // R channel
    logic                       r_sub_beat;
    logic [31:0]                r_data_lo_q;
    logic [1:0]                 r_resp_lo_q;
    logic                       r_burst_done;
    logic                       r_valid_out;
    logic [63:0]                r_data_out;
    logic [1:0]                 r_resp_out;
    logic                       r_last_out;
    logic [SLAVE_ID_WIDTH-1:0]  r_id_out;
    logic                       r_out_ready;

    // =========================================================================
    // WRITE ADDRESS CHANNEL FSM
    // =========================================================================

    always_ff @(posedge clk) begin
        if (rst) begin
            aw_state   <= AW_IDLE;
            aw_id_q    <= '0;
            aw_addr_q  <= '0;
            aw_len_q   <= '0;
            aw_size_q  <= '0;
            aw_burst_q <= '0;
            aw_lock_q  <= '0;
            aw_cache_q <= '0;
            aw_prot_q  <= '0;
            aw_qos_q   <= '0;
        end else begin
            case (aw_state)
                AW_IDLE: begin
                    if (s_axi_awvalid) begin
                        aw_id_q    <= s_axi_awid;
                        aw_addr_q  <= s_axi_awaddr;
                        aw_len_q   <= s_axi_awlen;
                        aw_size_q  <= s_axi_awsize;
                        aw_burst_q <= s_axi_awburst;
                        aw_lock_q  <= s_axi_awlock;
                        aw_cache_q <= s_axi_awcache;
                        aw_prot_q  <= s_axi_awprot;
                        aw_qos_q   <= s_axi_awqos;
                        aw_state   <= AW_ISSUE;
                    end
                end
                AW_ISSUE: begin
                    if (m_axi_awready) begin
                        aw_state <= AW_DONE;
                    end
                end
                AW_DONE: begin
                    // Return to IDLE when W channel completes this burst
                    if (w_burst_done) begin
                        aw_state <= AW_IDLE;
                    end
                end
                default: aw_state <= AW_IDLE;
            endcase
        end
    end

    // Accept upstream AW only when IDLE
    assign s_axi_awready = (aw_state == AW_IDLE);

    // Drive downstream AW while in AW_ISSUE
    assign m_axi_awvalid = (aw_state == AW_ISSUE);

    // Doubled burst length: (upstream_len + 1) * 2 - 1
    // aw_len_ds = (aw_len_q << 1) | 8'd1 = {aw_len_q[6:0], 1'b1}
    assign aw_len_ds = {aw_len_q[6:0], 1'b1};

    assign m_axi_awid    = {{(MASTER_ID_WIDTH-SLAVE_ID_WIDTH){1'b0}}, aw_id_q};
    assign m_axi_awaddr  = aw_addr_q;
    assign m_axi_awlen   = aw_len_ds;
    assign m_axi_awsize  = 3'b010;           // 4 bytes fixed
    assign m_axi_awburst = aw_burst_q;
    assign m_axi_awlock  = aw_lock_q;
    assign m_axi_awcache = aw_cache_q;
    assign m_axi_awprot  = aw_prot_q;
    assign m_axi_awqos   = aw_qos_q;

    // =========================================================================
    // WRITE DATA CHANNEL
    // =========================================================================

    always_ff @(posedge clk) begin
        if (rst) begin
            w_sub_beat        <= 1'b0;
            w_data_held       <= 1'b0;
            w_data_q          <= '0;
            w_strb_q          <= '0;
            w_last_q          <= 1'b0;
            w_beats_remaining <= '0;
        end else begin
            // Latch upstream beat when accepted
            if (s_axi_wvalid && s_axi_wready) begin
                w_data_q    <= s_axi_wdata;
                w_strb_q    <= s_axi_wstrb;
                w_last_q    <= s_axi_wlast;
                w_data_held <= 1'b1;
                if (!w_data_held && (w_beats_remaining == 8'd0)) begin
                    w_beats_remaining <= aw_len_q;
                end
            end

            // Advance sub-beat pointer when downstream beat is accepted
            if (m_axi_wvalid && m_axi_wready) begin
                if (w_sub_beat == 1'b1) begin
                    w_sub_beat  <= 1'b0;
                    w_data_held <= 1'b0;
                    if (w_beats_remaining != 8'd0)
                        w_beats_remaining <= w_beats_remaining - 8'd1;
                end else begin
                    w_sub_beat <= 1'b1;
                end
            end
        end
    end

    // Final downstream beat handshake
    assign w_burst_done = m_axi_wvalid && m_axi_wready && m_axi_wlast;

    // Accept upstream W beat when not holding one and AW has been dispatched
    assign s_axi_wready = ~w_data_held &&
                          (aw_state == AW_ISSUE || aw_state == AW_DONE);

    // Drive downstream W when holding a beat
    assign m_axi_wvalid = w_data_held;

    // Mux lower/upper 32-bit halves
    assign m_axi_wdata  = w_sub_beat ? w_data_q[63:32] : w_data_q[31:0];
    assign m_axi_wstrb  = w_sub_beat ? w_strb_q[7:4]   : w_strb_q[3:0];

    // Assert WLAST on the high sub-beat of the last upstream beat
    assign m_axi_wlast  = w_sub_beat && w_last_q;

    // =========================================================================
    // WRITE RESPONSE CHANNEL
    // =========================================================================
    assign s_axi_bid    = m_axi_bid[SLAVE_ID_WIDTH-1:0];
    assign s_axi_bresp  = m_axi_bresp;
    assign s_axi_bvalid = m_axi_bvalid;
    assign m_axi_bready = s_axi_bready;

    // =========================================================================
    // READ ADDRESS CHANNEL FSM
    // =========================================================================

    always_ff @(posedge clk) begin
        if (rst) begin
            ar_state   <= AR_IDLE;
            ar_id_q    <= '0;
            ar_addr_q  <= '0;
            ar_len_q   <= '0;
            ar_size_q  <= '0;
            ar_burst_q <= '0;
            ar_lock_q  <= '0;
            ar_cache_q <= '0;
            ar_prot_q  <= '0;
            ar_qos_q   <= '0;
        end else begin
            case (ar_state)
                AR_IDLE: begin
                    if (s_axi_arvalid) begin
                        ar_id_q    <= s_axi_arid;
                        ar_addr_q  <= s_axi_araddr;
                        ar_len_q   <= s_axi_arlen;
                        ar_size_q  <= s_axi_arsize;
                        ar_burst_q <= s_axi_arburst;
                        ar_lock_q  <= s_axi_arlock;
                        ar_cache_q <= s_axi_arcache;
                        ar_prot_q  <= s_axi_arprot;
                        ar_qos_q   <= s_axi_arqos;
                        ar_state   <= AR_ISSUE;
                    end
                end
                AR_ISSUE: begin
                    if (m_axi_arready) begin
                        ar_state <= AR_ACTIVE;
                    end
                end
                AR_ACTIVE: begin
                    // Return to IDLE when R channel delivers the last beat
                    if (r_burst_done) begin
                        ar_state <= AR_IDLE;
                    end
                end
                default: ar_state <= AR_IDLE;
            endcase
        end
    end

    assign s_axi_arready = (ar_state == AR_IDLE);
    assign m_axi_arvalid = (ar_state == AR_ISSUE);

    // Double upstream ARLEN
    assign ar_len_ds = {ar_len_q[6:0], 1'b1};

    assign m_axi_arid    = {{(MASTER_ID_WIDTH-SLAVE_ID_WIDTH){1'b0}}, ar_id_q};
    assign m_axi_araddr  = ar_addr_q;
    assign m_axi_arlen   = ar_len_ds;
    assign m_axi_arsize  = 3'b010;
    assign m_axi_arburst = ar_burst_q;
    assign m_axi_arlock  = ar_lock_q;
    assign m_axi_arcache = ar_cache_q;
    assign m_axi_arprot  = ar_prot_q;
    assign m_axi_arqos   = ar_qos_q;

    // =========================================================================
    // READ DATA CHANNEL
    // Re-assemble pairs of 32-bit downstream beats into 64-bit VeeR words.
    //   r_sub_beat == 0 : latch lower 32 bits
    //   r_sub_beat == 1 : combine with latched lo, present to VeeR
    // =========================================================================

    always_ff @(posedge clk) begin
        if (rst) begin
            r_sub_beat  <= 1'b0;
            r_data_lo_q <= '0;
            r_resp_lo_q <= '0;
            r_valid_out <= 1'b0;
            r_data_out  <= '0;
            r_resp_out  <= '0;
            r_last_out  <= 1'b0;
            r_id_out    <= '0;
        end else begin
            // Clear valid when upstream consumes the output beat
            if (r_valid_out && r_out_ready) begin
                r_valid_out <= 1'b0;
            end

            if (m_axi_rvalid && m_axi_rready) begin
                if (r_sub_beat == 1'b0) begin
                    // Lower 32-bit half: latch and wait for upper
                    r_data_lo_q <= m_axi_rdata;
                    r_resp_lo_q <= m_axi_rresp;
                    r_sub_beat  <= 1'b1;
                end else begin
                    // Upper 32-bit half: assemble and present to VeeR
                    r_data_out  <= {m_axi_rdata, r_data_lo_q};
                    r_resp_out  <= m_axi_rresp | r_resp_lo_q;  // worst-case merge
                    r_last_out  <= m_axi_rlast;
                    r_id_out    <= m_axi_rid[SLAVE_ID_WIDTH-1:0];
                    r_valid_out <= 1'b1;
                    r_sub_beat  <= 1'b0;
                end
            end
        end
    end

    assign r_out_ready  = s_axi_rready;
    assign r_burst_done = r_valid_out && r_out_ready && r_last_out;

    // Accept downstream R beats when not holding an assembled output waiting for VeeR
    assign m_axi_rready = ~r_valid_out || r_out_ready;

    // VeeR-facing R outputs
    assign s_axi_rvalid = r_valid_out;
    assign s_axi_rdata  = r_data_out;
    assign s_axi_rresp  = r_resp_out;
    assign s_axi_rlast  = r_last_out;
    assign s_axi_rid    = r_id_out;

endmodule : axi4_64_to_32_adapter

`default_nettype wire
