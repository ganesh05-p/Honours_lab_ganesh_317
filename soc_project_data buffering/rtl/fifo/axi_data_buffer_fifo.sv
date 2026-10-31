// =============================================================================
// File        : axi_data_buffer_fifo.sv
// Project     : RISC-V VeeR EL2 Based Real-Time Data Buffering SoC
// Description : Real-Time Data Buffering FIFO Peripheral with AXI4 Slave Interface.
//
// Features:
//   1. Software-accessible memory-mapped registers via AXI4 slave port:
//        Offset 0x00: DATA register (Write: push; Read: pop)
//        Offset 0x04: STATUS register (Empty, Full, Almost Empty/Full, Overflow, Underflow)
//        Offset 0x08: COUNT register (Current occupancy and total capacity)
//        Offset 0x0C: CTRL register (Flush, IRQ enable, DREQ enable, Threshold, Stream enable)
//        Offset 0x10: PEAK_OCCUPANCY register (Peak buffer level since reset)
//   2. Direct hardware streaming input (valid/ready handshake for sensor/testbench).
//   3. Hardware DMA request (dreq) generation when occupancy >= programmable threshold.
//   4. Interrupt generation (irq) on programmable threshold hit or overflow.
//   5. Supports single-beat transactions and AXI4 burst reads (enables DMA burst pops).
//
// Reset       : rst - active-HIGH synchronous (matches interconnect).
// =============================================================================

`default_nettype none
`timescale 1ns / 1ps

module axi_data_buffer_fifo #(
    parameter int DATA_WIDTH         = 32,
    parameter int ADDR_WIDTH         = 32,
    parameter int ID_WIDTH           = 8,
    parameter int FIFO_DEPTH         = 64,   // Depth in 32-bit words (power-of-2)
    parameter int ALMOST_FULL_DIFF   = 4,    // full - ALMOST_FULL_DIFF = almost full
    parameter int ALMOST_EMPTY_VAL   = 4     // count <= ALMOST_EMPTY_VAL = almost empty
) (
    input  logic                     clk,
    input  logic                     rst,

    // =========================================================================
    // AXI4 Slave Interface (connects to interconnect M02)
    // =========================================================================

    // Write Address Channel
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

    // Write Data Channel
    input  logic [DATA_WIDTH-1:0]    s_axi_wdata,
    input  logic [DATA_WIDTH/8-1:0]  s_axi_wstrb,
    input  logic                     s_axi_wlast,
    input  logic                     s_axi_wvalid,
    output logic                     s_axi_wready,

    // Write Response Channel
    output logic [ID_WIDTH-1:0]      s_axi_bid,
    output logic [1:0]               s_axi_bresp,
    output logic                     s_axi_bvalid,
    input  logic                     s_axi_bready,

    // Read Address Channel
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

    // Read Data Channel
    output logic [ID_WIDTH-1:0]      s_axi_rid,
    output logic [DATA_WIDTH-1:0]    s_axi_rdata,
    output logic [1:0]               s_axi_rresp,
    output logic                     s_axi_rlast,
    output logic                     s_axi_rvalid,
    input  logic                     s_axi_rready,

    // =========================================================================
    // Direct Hardware Stream Input (Sensor / Testbench sample generation)
    // =========================================================================
    input  logic                     stream_in_valid,
    input  logic [DATA_WIDTH-1:0]    stream_in_data,
    output logic                     stream_in_ready,

    // =========================================================================
    // Hardware Handshakes and Interrupt
    // =========================================================================
    output logic                     dreq,       // DMA transfer request
    input  logic                     dack,       // DMA acknowledge
    output logic                     irq         // Interrupt to PLIC / CPU
);

    // -------------------------------------------------------------------------
    // Local parameters
    // -------------------------------------------------------------------------
    localparam logic [1:0] RESP_OKAY   = 2'b00;
    localparam logic [1:0] RESP_SLVERR = 2'b10;

    localparam int PTR_BITS = $clog2(FIFO_DEPTH);
    localparam int CNT_BITS = $clog2(FIFO_DEPTH + 1);

    // Register Byte Offsets
    localparam logic [7:0] REG_DATA   = 8'h00;
    localparam logic [7:0] REG_STATUS = 8'h04;
    localparam logic [7:0] REG_COUNT  = 8'h08;
    localparam logic [7:0] REG_CTRL   = 8'h0C;
    localparam logic [7:0] REG_PEAK   = 8'h10;

    // -------------------------------------------------------------------------
    // FIFO Memory and Pointers
    // -------------------------------------------------------------------------
    logic [DATA_WIDTH-1:0] mem [0:FIFO_DEPTH-1];
    logic [PTR_BITS-1:0]   wr_ptr;
    logic [PTR_BITS-1:0]   rd_ptr;
    logic [CNT_BITS-1:0]   count;
    logic [CNT_BITS-1:0]   peak_count;

    logic                  fifo_empty;
    logic                  fifo_full;
    logic                  fifo_almost_empty;
    logic                  fifo_almost_full;

    assign fifo_empty        = (count == 0);
    assign fifo_full         = (count == FIFO_DEPTH);
    assign fifo_almost_empty = (count <= ALMOST_EMPTY_VAL);
    assign fifo_almost_full  = (count >= (FIFO_DEPTH - ALMOST_FULL_DIFF));

    // -------------------------------------------------------------------------
    // Control & Status Signals
    // -------------------------------------------------------------------------
    logic        irq_en;
    logic        dreq_en;
    logic [7:0]  irq_threshold;
    logic        stream_en;
    logic        soft_flush;
    logic        overflow_sticky;
    logic        underflow_sticky;
    logic        overflow_pulse;
    logic        underflow_pulse;
    logic        clear_overflow;
    logic        clear_underflow;

    // -------------------------------------------------------------------------
    // FIFO Operations (Push & Pop)
    // -------------------------------------------------------------------------
    logic        sw_push;
    logic [31:0] sw_push_data;
    logic        hw_push;
    logic [31:0] hw_push_data;
    logic        fifo_push;
    logic [31:0] fifo_push_data;

    logic        fifo_pop;
    logic [31:0] fifo_pop_data;

    // Stream ready logic
    assign stream_in_ready = stream_en && !fifo_full;
    assign hw_push         = stream_in_valid && stream_in_ready;
    assign hw_push_data    = stream_in_data;

    // Hardware stream has priority if both stream and sw push attempt simultaneously
    assign fifo_push      = hw_push || sw_push;
    assign fifo_push_data = hw_push ? hw_push_data : sw_push_data;

    // Read pop data from RAM
    assign fifo_pop_data  = mem[rd_ptr];

    // Status word
    logic [DATA_WIDTH-1:0] status_word;
    assign status_word = {
        25'b0,
        underflow_sticky,                                       // bit 6
        overflow_sticky,                                        // bit 5
        (32'(count) >= 32'(irq_threshold)),                     // bit 4: threshold hit
        fifo_almost_full,                                       // bit 3
        fifo_almost_empty,                                      // bit 2
        fifo_full,                                              // bit 1
        fifo_empty                                              // bit 0
    };

    // Count word
    logic [DATA_WIDTH-1:0] count_word;
    assign count_word = {
        16'(FIFO_DEPTH),                        // [31:16] Total capacity
        16'(count)                              // [15:0]  Current occupancy
    };

    // Control word
    logic [DATA_WIDTH-1:0] ctrl_word;
    assign ctrl_word = {
        15'b0,
        stream_en,                              // bit 16
        irq_threshold,                          // bits [15:8]
        5'b0,
        dreq_en,                                // bit 2
        irq_en,                                 // bit 1
        1'b0                                    // bit 0 (flush write-only)
    };

    // Hardware handshakes and interrupt
    assign dreq = dreq_en && (32'(count) >= 32'(irq_threshold)) && (count > 0);
    assign irq  = irq_en  && ((32'(count) >= 32'(irq_threshold)) || overflow_sticky);

    // Sticky status registers management
    always_ff @(posedge clk) begin
        if (rst) begin
            overflow_sticky  <= 1'b0;
            underflow_sticky <= 1'b0;
        end else if (soft_flush) begin
            overflow_sticky  <= 1'b0;
            underflow_sticky <= 1'b0;
        end else begin
            if (clear_overflow)
                overflow_sticky <= 1'b0;
            else if (overflow_pulse)
                overflow_sticky <= 1'b1;

            if (clear_underflow)
                underflow_sticky <= 1'b0;
            else if (underflow_pulse)
                underflow_sticky <= 1'b1;
        end
    end

    // =========================================================================
    // AXI Write Path FSM
    // =========================================================================
    typedef enum logic [1:0] {
        W_IDLE,
        W_EXEC,
        W_RESP
    } wr_state_t;

    wr_state_t wr_state;
    logic [ID_WIDTH-1:0]     wr_id_r;
    logic [7:0]              wr_addr_r;
    logic [DATA_WIDTH-1:0]   wr_data_r;
    logic [DATA_WIDTH/8-1:0] wr_strb_r;

    always_ff @(posedge clk) begin
        if (rst) begin
            wr_state        <= W_IDLE;
            s_axi_awready   <= 1'b0;
            s_axi_wready    <= 1'b0;
            s_axi_bvalid    <= 1'b0;
            s_axi_bid       <= '0;
            s_axi_bresp     <= RESP_OKAY;
            wr_id_r         <= '0;
            wr_addr_r       <= '0;
            wr_data_r       <= '0;
            wr_strb_r       <= '0;
            sw_push         <= 1'b0;
            sw_push_data    <= '0;
            irq_en          <= 1'b1;        // Default enabled
            dreq_en         <= 1'b1;        // Default enabled
            irq_threshold   <= 8'd4;        // Default threshold: 4 samples
            stream_en       <= 1'b1;        // Default enabled
            soft_flush      <= 1'b0;
            clear_overflow  <= 1'b0;
            clear_underflow <= 1'b0;
            overflow_pulse  <= 1'b0;
        end else begin
            sw_push         <= 1'b0;
            soft_flush      <= 1'b0;
            clear_overflow  <= 1'b0;
            clear_underflow <= 1'b0;
            overflow_pulse  <= 1'b0;

            // Stream overflow detection
            if (stream_in_valid && stream_en && fifo_full) begin
                overflow_pulse <= 1'b1;
            end

            case (wr_state)
                W_IDLE: begin
                    s_axi_awready <= 1'b1;
                    s_axi_wready  <= 1'b1;

                    if (s_axi_awvalid && s_axi_awready && s_axi_wvalid && s_axi_wready) begin
                        wr_id_r       <= s_axi_awid;
                        wr_addr_r     <= s_axi_awaddr[7:0];
                        wr_data_r     <= s_axi_wdata;
                        wr_strb_r     <= s_axi_wstrb;
                        s_axi_awready <= 1'b0;
                        s_axi_wready  <= 1'b0;
                        wr_state      <= W_EXEC;
                    end else if (s_axi_awvalid && s_axi_awready) begin
                        wr_id_r       <= s_axi_awid;
                        wr_addr_r     <= s_axi_awaddr[7:0];
                        s_axi_awready <= 1'b0;
                    end else if (s_axi_wvalid && s_axi_wready) begin
                        wr_data_r     <= s_axi_wdata;
                        wr_strb_r     <= s_axi_wstrb;
                        s_axi_wready  <= 1'b0;
                        if (!s_axi_awready) begin
                            wr_state <= W_EXEC;
                        end
                    end
                end

                W_EXEC: begin
                    case (wr_addr_r)
                        REG_DATA: begin
                            if (!fifo_full) begin
                                sw_push      <= 1'b1;
                                sw_push_data <= wr_data_r;
                            end else begin
                                overflow_pulse <= 1'b1;
                            end
                        end

                        REG_STATUS: begin
                            // W1C to clear sticky flags
                            if (wr_data_r[5]) clear_overflow  <= 1'b1;
                            if (wr_data_r[6]) clear_underflow <= 1'b1;
                        end

                        REG_CTRL: begin
                            if (wr_data_r[0]) begin
                                soft_flush <= 1'b1;
                            end
                            irq_en        <= wr_data_r[1];
                            dreq_en       <= wr_data_r[2];
                            irq_threshold <= wr_data_r[15:8];
                            stream_en     <= wr_data_r[16];
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

    // =========================================================================
    // AXI Read Path Registers & Declarations
    // =========================================================================
    typedef enum logic [1:0] {
        R_IDLE,
        R_BURST
    } rd_state_t;

    rd_state_t rd_state;
    logic [ID_WIDTH-1:0]   rd_id_r;
    logic [7:0]            rd_addr_r;
    logic [7:0]            rd_len_r;
    logic [7:0]            rd_beat_cnt;

    // Combinational read data multiplexer
    logic [DATA_WIDTH-1:0] rdata_comb;
    always_comb begin
        case (rd_addr_r)
            REG_DATA:   rdata_comb = fifo_empty ? '0 : mem[rd_ptr];
            REG_STATUS: rdata_comb = status_word;
            REG_COUNT:  rdata_comb = count_word;
            REG_CTRL:   rdata_comb = ctrl_word;
            REG_PEAK:   rdata_comb = {16'b0, 16'(peak_count)};
            default:    rdata_comb = '0;
        endcase
    end
    assign s_axi_rdata = rdata_comb;

    // Pop on actual read handshake
    assign fifo_pop = (rd_state == R_BURST) && s_axi_rvalid && s_axi_rready && (rd_addr_r == REG_DATA) && !fifo_empty;

    always_ff @(posedge clk) begin
        if (rst) begin
            rd_state        <= R_IDLE;
            s_axi_arready   <= 1'b0;
            s_axi_rvalid    <= 1'b0;
            s_axi_rid       <= '0;
            s_axi_rresp     <= RESP_OKAY;
            s_axi_rlast     <= 1'b0;
            rd_id_r         <= '0;
            rd_addr_r       <= '0;
            rd_len_r        <= '0;
            rd_beat_cnt     <= '0;
            underflow_pulse <= 1'b0;
        end else begin
            underflow_pulse <= 1'b0;

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

                        if ((s_axi_araddr[7:0] == REG_DATA) && fifo_empty) begin
                            underflow_pulse <= 1'b1;
                        end

                        rd_state      <= R_BURST;
                    end
                end

                R_BURST: begin
                    if (s_axi_rready && s_axi_rvalid) begin
                        if ((rd_addr_r == REG_DATA) && fifo_empty) begin
                            underflow_pulse <= 1'b1;
                        end

                        if (rd_beat_cnt == rd_len_r) begin
                            // Burst completed
                            s_axi_rvalid  <= 1'b0;
                            s_axi_rlast   <= 1'b0;
                            s_axi_arready <= 1'b1;
                            rd_state      <= R_IDLE;
                        end else begin
                            // Next burst beat
                            rd_beat_cnt <= rd_beat_cnt + 1'b1;
                            s_axi_rlast <= (rd_beat_cnt + 1'b1 == rd_len_r);
                        end
                    end
                end
            endcase
        end
    end

    // =========================================================================
    // Synchronous FIFO Buffer Core
    // =========================================================================
    always_ff @(posedge clk) begin
        if (rst) begin
            wr_ptr     <= '0;
            rd_ptr     <= '0;
            count      <= '0;
            peak_count <= '0;
        end else if (soft_flush) begin
            // Soft reset / flush
            wr_ptr <= '0;
            rd_ptr <= '0;
            count  <= '0;
        end else begin
            case ({fifo_push && !fifo_full, fifo_pop && !fifo_empty})
                2'b10: begin
                    // Write only
                    mem[wr_ptr] <= fifo_push_data;
                    wr_ptr      <= wr_ptr + 1'b1;
                    count       <= count + 1'b1;
                    if (count + 1'b1 > peak_count) begin
                        peak_count <= count + 1'b1;
                    end
                end

                2'b01: begin
                    // Read only
                    rd_ptr <= rd_ptr + 1'b1;
                    count  <= count - 1'b1;
                end

                2'b11: begin
                    // Simultaneous write and read
                    mem[wr_ptr] <= fifo_push_data;
                    wr_ptr      <= wr_ptr + 1'b1;
                    rd_ptr      <= rd_ptr + 1'b1;
                    // Count remains unchanged
                end

                default: ;
            endcase
        end
    end

endmodule

`default_nettype wire
