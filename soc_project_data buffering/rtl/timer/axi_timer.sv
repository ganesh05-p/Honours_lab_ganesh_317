// =============================================================================
// Module: axi_timer.sv
// Project: RISC-V VeeR EL2 Real-Time Data Buffering SoC
// Description: Synthesizable AXI4 32-bit Timer with programmable counter,
//              compare threshold, auto-reload, and interrupt generation.
// =============================================================================

`timescale 1ns/1ps
`default_nettype none

module axi_timer #(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 32,
    parameter int ID_WIDTH   = 8
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

    // Interrupt Output
    output logic                     timer_irq
);

    localparam logic [1:0] RESP_OKAY   = 2'b00;

    // Register Offsets
    localparam logic [7:0] REG_CTRL   = 8'h00;
    localparam logic [7:0] REG_VAL    = 8'h04;
    localparam logic [7:0] REG_CMP    = 8'h08;
    localparam logic [7:0] REG_STATUS = 8'h0C;

    // Registers
    logic        timer_en;
    logic        auto_reload;
    logic        irq_en;
    logic [31:0] counter;
    logic [31:0] cmp_val;
    logic        match_flag;

    assign timer_irq = irq_en && match_flag;

    // -------------------------------------------------------------------------
    // AXI4 Write FSM and Counter State Machine
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
            timer_en      <= 1'b0;
            auto_reload   <= 1'b0;
            irq_en        <= 1'b0;
            counter       <= 32'd0;
            cmp_val       <= 32'hFFFF_FFFF;
            match_flag    <= 1'b0;
        end else begin
            // Counter operation
            if (timer_en) begin
                if (counter >= cmp_val && cmp_val != 32'd0) begin
                    match_flag <= 1'b1;
                    if (auto_reload)
                        counter <= 32'd0;
                    else
                        counter <= counter + 32'd1;
                end else begin
                    counter <= counter + 32'd1;
                end
            end

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
                        REG_CTRL: begin
                            timer_en    <= wr_data_r[0];
                            auto_reload <= wr_data_r[1];
                            irq_en      <= wr_data_r[2];
                        end
                        REG_VAL: begin
                            counter     <= wr_data_r;
                        end
                        REG_CMP: begin
                            cmp_val     <= wr_data_r;
                        end
                        REG_STATUS: begin
                            if (wr_data_r[0]) match_flag <= 1'b0; // W1C
                        end
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
            REG_CTRL:   rdata_comb = {29'b0, irq_en, auto_reload, timer_en};
            REG_VAL:    rdata_comb = counter;
            REG_CMP:    rdata_comb = cmp_val;
            REG_STATUS: rdata_comb = {31'b0, match_flag};
            default:    rdata_comb = 32'h1234_5678; // Backward-compatible default for unconfigured offsets
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

endmodule : axi_timer

`default_nettype wire
