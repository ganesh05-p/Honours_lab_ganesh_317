/*
 * axi_slave_dummy.v
 *
 * Parameterised dummy AXI4 slave.
 *
 *  - Single-cycle ready on AW / W / AR channels (no back-pressure by default).
 *  - Simple 256-word internal SRAM (word-addressed on ADDR[9:2]).
 *  - Returns OKAY on every transaction.
 *  - Stores write data so read-after-write works correctly.
 *
 * Parameters
 *   DATA_WIDTH  – data bus width (must match interconnect, default 32)
 *   ADDR_WIDTH  – address bus width (default 32)
 *   ID_WIDTH    – AXI ID width (default 8)
 */

`timescale 1ns / 1ps
`default_nettype none

module axi_slave_dummy #
(
    parameter DATA_WIDTH  = 32,
    parameter ADDR_WIDTH  = 32,
    parameter ID_WIDTH    = 8,
    parameter STRB_WIDTH  = (DATA_WIDTH/8),
    parameter MEM_DEPTH   = 256         // number of DATA_WIDTH words in local SRAM
)
(
    input  wire                  clk,
    input  wire                  rst,

    /* ---- Write address channel ---- */
    input  wire [ID_WIDTH-1:0]   s_axi_awid,
    input  wire [ADDR_WIDTH-1:0] s_axi_awaddr,
    input  wire [7:0]            s_axi_awlen,
    input  wire [2:0]            s_axi_awsize,
    input  wire [1:0]            s_axi_awburst,
    input  wire                  s_axi_awlock,
    input  wire [3:0]            s_axi_awcache,
    input  wire [2:0]            s_axi_awprot,
    input  wire [3:0]            s_axi_awqos,
    input  wire [3:0]            s_axi_awregion,
    input  wire                  s_axi_awvalid,
    output reg                   s_axi_awready,

    /* ---- Write data channel ---- */
    input  wire [DATA_WIDTH-1:0] s_axi_wdata,
    input  wire [STRB_WIDTH-1:0] s_axi_wstrb,
    input  wire                  s_axi_wlast,
    input  wire                  s_axi_wvalid,
    output reg                   s_axi_wready,

    /* ---- Write response channel ---- */
    output reg  [ID_WIDTH-1:0]   s_axi_bid,
    output reg  [1:0]            s_axi_bresp,
    output reg                   s_axi_bvalid,
    input  wire                  s_axi_bready,

    /* ---- Read address channel ---- */
    input  wire [ID_WIDTH-1:0]   s_axi_arid,
    input  wire [ADDR_WIDTH-1:0] s_axi_araddr,
    input  wire [7:0]            s_axi_arlen,
    input  wire [2:0]            s_axi_arsize,
    input  wire [1:0]            s_axi_arburst,
    input  wire                  s_axi_arlock,
    input  wire [3:0]            s_axi_arcache,
    input  wire [2:0]            s_axi_arprot,
    input  wire [3:0]            s_axi_arqos,
    input  wire [3:0]            s_axi_arregion,
    input  wire                  s_axi_arvalid,
    output reg                   s_axi_arready,

    /* ---- Read data channel ---- */
    output reg  [ID_WIDTH-1:0]   s_axi_rid,
    output reg  [DATA_WIDTH-1:0] s_axi_rdata,
    output reg  [1:0]            s_axi_rresp,
    output reg                   s_axi_rlast,
    output reg                   s_axi_rvalid,
    input  wire                  s_axi_rready
);

    // -----------------------------------------------------------------------
    // Internal SRAM  (word-addressed, address bits [9:2] used when DW=32)
    // -----------------------------------------------------------------------
    localparam ADDR_LSB = $clog2(DATA_WIDTH/8);   // byte-offset bits to strip

    reg [DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];

    // -----------------------------------------------------------------------
    // Write address capture
    // -----------------------------------------------------------------------
    reg [ID_WIDTH-1:0]   aw_id_r;
    reg [ADDR_WIDTH-1:0] aw_addr_r;
    reg [7:0]            aw_len_r;
    reg                  aw_pending;   // address has been accepted, data not yet done

    // -----------------------------------------------------------------------
    // Write data beat counter
    // -----------------------------------------------------------------------
    reg [7:0] w_beat_cnt;

    // -----------------------------------------------------------------------
    // Read address capture
    // -----------------------------------------------------------------------
    reg [ID_WIDTH-1:0]   ar_id_r;
    reg [ADDR_WIDTH-1:0] ar_addr_r;
    reg [7:0]            ar_len_r;
    reg                  ar_pending;
    reg [7:0]            r_beat_cnt;

    // -----------------------------------------------------------------------
    // Initialise memories (simulation only)
    // -----------------------------------------------------------------------
    integer i;
    initial begin
        for (i = 0; i < MEM_DEPTH; i = i + 1)
            mem[i] = {DATA_WIDTH{1'b0}};
        aw_pending = 1'b0;
        ar_pending = 1'b0;
    end

    // -----------------------------------------------------------------------
    // AW channel  – accept address immediately
    // -----------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            s_axi_awready <= 1'b1;
            aw_pending    <= 1'b0;
        end else begin
            if (s_axi_awvalid && s_axi_awready) begin
                aw_id_r    <= s_axi_awid;
                aw_addr_r  <= s_axi_awaddr;
                aw_len_r   <= s_axi_awlen;
                w_beat_cnt <= 8'd0;
                aw_pending <= 1'b1;
                s_axi_awready <= 1'b0;   // hold off until current burst done
            end
            // Re-open AW once B has been accepted
            if (s_axi_bvalid && s_axi_bready) begin
                s_axi_awready <= 1'b1;
                aw_pending    <= 1'b0;
            end
        end
    end

    // -----------------------------------------------------------------------
    // W channel  – accept data whenever AW has been sampled
    // -----------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            s_axi_wready  <= 1'b0;
            s_axi_bvalid  <= 1'b0;
            s_axi_bid     <= {ID_WIDTH{1'b0}};
            s_axi_bresp   <= 2'b00;
        end else begin
            // Open W-ready once address is captured
            if (aw_pending && !s_axi_bvalid)
                s_axi_wready <= 1'b1;

            if (s_axi_wvalid && s_axi_wready) begin
                // Write to memory with byte-enable
                begin : wr_byte
                    integer b;
                    reg [ADDR_WIDTH-1:0] word_addr;
                    word_addr = (aw_addr_r >> ADDR_LSB) + w_beat_cnt;
                    for (b = 0; b < STRB_WIDTH; b = b + 1)
                        if (s_axi_wstrb[b])
                            mem[word_addr % MEM_DEPTH][b*8 +: 8] <= s_axi_wdata[b*8 +: 8];
                end
                w_beat_cnt <= w_beat_cnt + 1;

                if (s_axi_wlast) begin
                    s_axi_wready <= 1'b0;
                    s_axi_bvalid <= 1'b1;
                    s_axi_bid    <= aw_id_r;
                    s_axi_bresp  <= 2'b00;  // OKAY
                end
            end

            // B handshake done
            if (s_axi_bvalid && s_axi_bready)
                s_axi_bvalid <= 1'b0;
        end
    end

    // -----------------------------------------------------------------------
    // AR channel  – accept address immediately
    // -----------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            s_axi_arready <= 1'b1;
            ar_pending    <= 1'b0;
        end else begin
            if (s_axi_arvalid && s_axi_arready) begin
                ar_id_r    <= s_axi_arid;
                ar_addr_r  <= s_axi_araddr;
                ar_len_r   <= s_axi_arlen;
                r_beat_cnt <= 8'd0;
                ar_pending <= 1'b1;
                s_axi_arready <= 1'b0;
            end
            if (s_axi_rvalid && s_axi_rready && s_axi_rlast) begin
                s_axi_arready <= 1'b1;
                ar_pending    <= 1'b0;
            end
        end
    end

    // -----------------------------------------------------------------------
    // R channel  – return data beat by beat
    // -----------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            s_axi_rvalid <= 1'b0;
            s_axi_rid    <= {ID_WIDTH{1'b0}};
            s_axi_rdata  <= {DATA_WIDTH{1'b0}};
            s_axi_rresp  <= 2'b00;
            s_axi_rlast  <= 1'b0;
        end else begin
            if (ar_pending && !s_axi_rvalid) begin
                // Present first beat immediately
                s_axi_rvalid <= 1'b1;
                s_axi_rid    <= ar_id_r;
                s_axi_rdata  <= mem[((ar_addr_r >> ADDR_LSB) + r_beat_cnt) % MEM_DEPTH];
                s_axi_rresp  <= 2'b00;
                s_axi_rlast  <= (r_beat_cnt == ar_len_r);
            end

            if (s_axi_rvalid && s_axi_rready) begin
                if (s_axi_rlast) begin
                    s_axi_rvalid <= 1'b0;
                    s_axi_rlast  <= 1'b0;
                end else begin
                    // Advance to next beat
                    r_beat_cnt   <= r_beat_cnt + 1;
                    s_axi_rdata  <= mem[((ar_addr_r >> ADDR_LSB) + r_beat_cnt + 1) % MEM_DEPTH];
                    s_axi_rlast  <= ((r_beat_cnt + 1) == ar_len_r);
                end
            end
        end
    end

endmodule

`default_nettype wire
