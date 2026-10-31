// =============================================================================
// Module: axi_gpio.sv
// Project: RISC-V VeeR EL2 Real-Time Data Buffering SoC
// Description: Synthesizable AXI4 32-bit General Purpose I/O (GPIO) Controller
//              with input, output, direction, bit-set, and bit-clear registers.
// =============================================================================

`timescale 1ns/1ps
`default_nettype none

module axi_gpio #(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 32,
    parameter int ID_WIDTH   = 8,
    parameter int GPIO_WIDTH = 32
) (
    input  logic                     clk,
    input  logic                     rst,

    // AXI4 Write Address Channel
    input  logic [ID_WIDTH-1:0]      s_axi_awid,
    input  logic [ADDR_WIDTH-1:0]    s_axi_awaddr,
    input  logic [7:0]               s_axi_awlen,
    input  logic [2:0]               s_axi_awsize,
    input  logic [1:0]               s_axi_awburst,
    input  logic                     s_axi_awlock,
    input  logic [3:0]               s_axi_awcache,
    input  logic [2:0]               s_axi_awprot,
    input  logic [3:0]               s_axi_awqos,
    input  logic [3:0]               s_axi_awregion,
    input  logic                     s_axi_awvalid,
    output logic                     s_axi_awready,

    // AXI4 Write Data Channel
    input  logic [DATA_WIDTH-1:0]    s_axi_wdata,
    input  logic [DATA_WIDTH/8-1:0]  s_axi_wstrb,
    input  logic                     s_axi_wlast,
    input  logic                     s_axi_wvalid,
    output logic                     s_axi_wready,

    // AXI4 Write Response Channel
    output logic [ID_WIDTH-1:0]      s_axi_bid,
    output logic [1:0]               s_axi_bresp,
    output logic                     s_axi_bvalid,
    input  logic                     s_axi_bready,

    // AXI4 Read Address Channel
    input  logic [ID_WIDTH-1:0]      s_axi_arid,
    input  logic [ADDR_WIDTH-1:0]    s_axi_araddr,
    input  logic [7:0]               s_axi_arlen,
    input  logic [2:0]               s_axi_arsize,
    input  logic [1:0]               s_axi_arburst,
    input  logic                     s_axi_arlock,
    input  logic [3:0]               s_axi_arcache,
    input  logic [2:0]               s_axi_arprot,
    input  logic [3:0]               s_axi_arqos,
    input  logic [3:0]               s_axi_arregion,
    input  logic                     s_axi_arvalid,
    output logic                     s_axi_arready,

    // AXI4 Read Data Channel
    output logic [ID_WIDTH-1:0]      s_axi_rid,
    output logic [DATA_WIDTH-1:0]    s_axi_rdata,
    output logic [1:0]               s_axi_rresp,
    output logic                     s_axi_rlast,
    output logic                     s_axi_rvalid,
    input  logic                     s_axi_rready,

    // External GPIO Physical Pins
    input  logic [GPIO_WIDTH-1:0]    gpio_i,
    output logic [GPIO_WIDTH-1:0]    gpio_o,
    output logic [GPIO_WIDTH-1:0]    gpio_oe
);

    localparam logic [1:0] RESP_OKAY   = 2'b00;

    // Register Offsets
    localparam logic [7:0] REG_DATA_IN  = 8'h00;
    localparam logic [7:0] REG_DATA_OUT = 8'h04;
    localparam logic [7:0] REG_DIR      = 8'h08;
    localparam logic [7:0] REG_SET      = 8'h0C;
    localparam logic [7:0] REG_CLEAR    = 8'h10;

    // Registers
    logic [GPIO_WIDTH-1:0] data_out_r;
    logic [GPIO_WIDTH-1:0] dir_r;
    logic [GPIO_WIDTH-1:0] data_in_sync1;
    logic [GPIO_WIDTH-1:0] data_in_sync2;

    assign gpio_o  = data_out_r;
    assign gpio_oe = dir_r;

    // Input synchronizer
    always_ff @(posedge clk) begin
        if (rst) begin
            data_in_sync1 <= '0;
            data_in_sync2 <= '0;
        end else begin
            data_in_sync1 <= gpio_i;
            data_in_sync2 <= data_in_sync1;
        end
    end

    // -------------------------------------------------------------------------
    // AXI4 Write FSM
    // -------------------------------------------------------------------------
    typedef enum logic [1:0] {
        W_IDLE,
        W_EXEC,
        W_RESP
    } wr_state_t;

    wr_state_t wr_state;
    logic [ID_WIDTH-1:0] wr_id_r;
    logic [7:0]          wr_addr_r;
    logic [31:0]         wr_data_r;

    always_ff @(posedge clk) begin
        if (rst) begin
            wr_state      <= W_IDLE;
            s_axi_awready <= 1'b0;
            s_axi_wready  <= 1'b0;
            s_axi_bvalid  <= 1'b0;
            s_axi_bid     <= '0;
            s_axi_bresp   <= RESP_OKAY;
            wr_id_r       <= '0;
            wr_addr_r     <= '0;
            wr_data_r     <= '0;
            data_out_r    <= '0;
            dir_r         <= '0;
        end else begin
            case (wr_state)
                W_IDLE: begin
                    s_axi_awready <= 1'b1;
                    s_axi_wready  <= 1'b1;

                    if (s_axi_awvalid && s_axi_awready && s_axi_wvalid && s_axi_wready) begin
                        wr_id_r       <= s_axi_awid;
                        wr_addr_r     <= s_axi_awaddr[7:0];
                        wr_data_r     <= s_axi_wdata;
                        s_axi_awready <= 1'b0;
                        s_axi_wready  <= 1'b0;
                        wr_state      <= W_EXEC;
                    end else if (s_axi_awvalid && s_axi_awready) begin
                        wr_id_r       <= s_axi_awid;
                        wr_addr_r     <= s_axi_awaddr[7:0];
                        s_axi_awready <= 1'b0;
                    end else if (s_axi_wvalid && s_axi_wready) begin
                        wr_data_r     <= s_axi_wdata;
                        s_axi_wready  <= 1'b0;
                        if (!s_axi_awready) begin
                            wr_state <= W_EXEC;
                        end
                    end
                end

                W_EXEC: begin
                    case (wr_addr_r)
                        REG_DATA_OUT: data_out_r <= wr_data_r[GPIO_WIDTH-1:0];
                        REG_DIR:      dir_r      <= wr_data_r[GPIO_WIDTH-1:0];
                        REG_SET:      data_out_r <= data_out_r | wr_data_r[GPIO_WIDTH-1:0];
                        REG_CLEAR:    data_out_r <= data_out_r & ~wr_data_r[GPIO_WIDTH-1:0];
                        default: ;
                    endcase
                    s_axi_bid    <= wr_id_r;
                    s_axi_bresp  <= RESP_OKAY;
                    s_axi_bvalid <= 1'b1;
                    wr_state     <= W_RESP;
                end

                W_RESP: begin
                    if (s_axi_bready && s_axi_bvalid) begin
                        s_axi_bvalid  <= 1'b0;
                        s_axi_awready <= 1'b1;
                        s_axi_wready  <= 1'b1;
                        wr_state      <= W_IDLE;
                    end
                end
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // AXI4 Read FSM
    // -------------------------------------------------------------------------
    typedef enum logic [1:0] {
        R_IDLE,
        R_BURST
    } rd_state_t;

    rd_state_t rd_state;
    logic [ID_WIDTH-1:0] rd_id_r;
    logic [7:0]          rd_addr_r;
    logic [7:0]          rd_len_r;
    logic [7:0]          rd_beat_cnt;

    // Combinational read data multiplexer
    logic [31:0] rdata_comb;
    always_comb begin
        case (rd_addr_r)
            REG_DATA_IN:  rdata_comb = {{(32-GPIO_WIDTH){1'b0}}, data_in_sync2};
            REG_DATA_OUT: rdata_comb = {{(32-GPIO_WIDTH){1'b0}}, data_out_r};
            REG_DIR:      rdata_comb = {{(32-GPIO_WIDTH){1'b0}}, dir_r};
            default:      rdata_comb = 32'h0;
        endcase
    end
    assign s_axi_rdata = rdata_comb;

    always_ff @(posedge clk) begin
        if (rst) begin
            rd_state      <= R_IDLE;
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rid     <= '0;
            s_axi_rresp   <= RESP_OKAY;
            s_axi_rlast   <= 1'b0;
            rd_id_r       <= '0;
            rd_addr_r     <= '0;
            rd_len_r      <= '0;
            rd_beat_cnt   <= '0;
        end else begin
            case (rd_state)
                R_IDLE: begin
                    s_axi_arready <= 1'b1;

                    if (s_axi_arvalid && s_axi_arready) begin
                        s_axi_arready <= 1'b0;
                        rd_id_r       <= s_axi_arid;
                        rd_addr_r     <= s_axi_araddr[7:0];
                        rd_len_r      <= s_axi_arlen;
                        rd_beat_cnt   <= 8'd0;

                        s_axi_rid     <= s_axi_arid;
                        s_axi_rresp   <= RESP_OKAY;
                        s_axi_rlast   <= (s_axi_arlen == 0);
                        s_axi_rvalid  <= 1'b1;
                        rd_state      <= R_BURST;
                    end
                end

                R_BURST: begin
                    if (s_axi_rready && s_axi_rvalid) begin
                        if (rd_beat_cnt == rd_len_r) begin
                            s_axi_rvalid  <= 1'b0;
                            s_axi_rlast   <= 1'b0;
                            s_axi_arready <= 1'b1;
                            rd_state      <= R_IDLE;
                        end else begin
                            rd_beat_cnt <= rd_beat_cnt + 1'b1;
                            s_axi_rlast <= (rd_beat_cnt + 1'b1 == rd_len_r);
                        end
                    end
                end
            endcase
        end
    end

endmodule : axi_gpio

`default_nettype wire
