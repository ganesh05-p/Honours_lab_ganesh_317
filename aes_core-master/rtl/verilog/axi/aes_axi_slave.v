`timescale 1ns/1ps

module aes_axi_slave (
    input         clk,
    input         reset,

    input  [3:0]  AWID,
    input  [31:0] AWADDR,
    input  [3:0]  AWLEN,
    input  [2:0]  AWSIZE,
    input  [1:0]  AWBURST,
    input         AWVALID,
    output        AWREADY,

    input  [3:0]  WID,
    input  [31:0] WDATA,
    input         WLAST,
    input         WVALID,
    output        WREADY,

    output [3:0]  BID,
    output [1:0]  BRESP,
    output        BVALID,
    input         BREADY,

    input  [3:0]  ARID,
    input  [31:0] ARADDR,
    input  [3:0]  ARLEN,
    input  [2:0]  ARSIZE,
    input  [1:0]  ARBURST,
    input         ARVALID,
    output        ARREADY,

    output [3:0]  RID,
    output [31:0] RDATA,
    output [1:0]  RRESP,
    output        RVALID,
    output        RLAST,
    input         RREADY
);

    /*
     * Register map:
     * 0x00 KEY[31:0]
     * 0x04 KEY[63:32]
     * 0x08 KEY[95:64]
     * 0x0C KEY[127:96]
     *
     * 0x10 DATA_IN[31:0]
     * 0x14 DATA_IN[63:32]
     * 0x18 DATA_IN[95:64]
     * 0x1C DATA_IN[127:96]
     *
     * 0x20 CONTROL
     *      bit 0 = encryption start
     *      bit 1 = decryption start
     *
     * 0x24 STATUS
     *      bit 0 = encryption done
     *      bit 1 = decryption done
     *
     * 0x28 DATA_OUT[31:0]
     * 0x2C DATA_OUT[63:32]
     * 0x30 DATA_OUT[95:64]
     * 0x34 DATA_OUT[127:96]
     */

    localparam [5:0] A_KEY0 = 6'h00;
    localparam [5:0] A_KEY1 = 6'h01;
    localparam [5:0] A_KEY2 = 6'h02;
    localparam [5:0] A_KEY3 = 6'h03;

    localparam [5:0] A_IN0  = 6'h04;
    localparam [5:0] A_IN1  = 6'h05;
    localparam [5:0] A_IN2  = 6'h06;
    localparam [5:0] A_IN3  = 6'h07;

    localparam [5:0] A_CTRL = 6'h08;
    localparam [5:0] A_STAT = 6'h09;

    localparam [5:0] A_OUT0 = 6'h0A;
    localparam [5:0] A_OUT1 = 6'h0B;
    localparam [5:0] A_OUT2 = 6'h0C;
    localparam [5:0] A_OUT3 = 6'h0D;

    reg        aw_pending;
    reg [3:0]  awid_reg;
    reg [31:0] awaddr_reg;

    reg        bvalid_reg;
    reg [3:0]  bid_reg;
    reg [1:0]  bresp_reg;

    reg        rvalid_reg;
    reg [3:0]  rid_reg;
    reg [31:0] rdata_reg;
    reg [1:0]  rresp_reg;
    reg        rlast_reg;

    reg [127:0] key_reg;
    reg [127:0] data_in_reg;
    reg [127:0] data_out_reg;

    reg enc_start;
    reg dec_kld;
    reg dec_ld;

    reg enc_done_reg;
    reg dec_done_reg;

    wire [127:0] enc_out;
    wire [127:0] dec_out;
    wire         enc_done;
    wire         dec_done;

    /*
     * The original OpenCores AES inverse core requires:
     *
     *     kld = one clock pulse
     *     wait for the inverse key schedule
     *     ld  = one clock pulse
     *
     * We preload the inverse AES key at the same time as the
     * encryption is started. Therefore, by the time encryption
     * finishes, the inverse key schedule is already available.
     *
     * This also exactly matches the proven standalone AES testbench,
     * where kld is asserted first and the inverse ld is asserted
     * only after the encryption operation has completed.
     */

    aes_cipher_top u_enc (
        .clk      (clk),
        .rst      (reset),
        .ld       (enc_start),
        .done     (enc_done),
        .key      (key_reg),
        .text_in  (data_in_reg),
        .text_out (enc_out)
    );

    aes_inv_cipher_top u_dec (
        .clk      (clk),
        .rst      (reset),
        .kld      (dec_kld),
        .ld       (dec_ld),
        .done     (dec_done),
        .key      (key_reg),
        .text_in  (data_in_reg),
        .text_out (dec_out)
    );

    function [5:0] addr_word;
        input [31:0] addr;
        begin
            addr_word = addr[7:2];
        end
    endfunction

    assign AWREADY = !aw_pending && !bvalid_reg;
    assign WREADY  = aw_pending && !bvalid_reg;

    assign BID     = bid_reg;
    assign BRESP   = bresp_reg;
    assign BVALID  = bvalid_reg;

    assign ARREADY = !rvalid_reg;

    assign RID     = rid_reg;
    assign RDATA   = rdata_reg;
    assign RRESP   = rresp_reg;
    assign RVALID  = rvalid_reg;
    assign RLAST   = rlast_reg;

    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            aw_pending  <= 1'b0;
            awid_reg    <= 4'b0;
            awaddr_reg  <= 32'b0;

            bvalid_reg  <= 1'b0;
            bid_reg     <= 4'b0;
            bresp_reg   <= 2'b00;

            rvalid_reg  <= 1'b0;
            rid_reg     <= 4'b0;
            rdata_reg   <= 32'b0;
            rresp_reg   <= 2'b00;
            rlast_reg   <= 1'b0;

            key_reg     <= 128'b0;
            data_in_reg <= 128'b0;
            data_out_reg<= 128'b0;

            enc_start   <= 1'b0;
            dec_kld     <= 1'b0;
            dec_ld      <= 1'b0;

            enc_done_reg <= 1'b0;
            dec_done_reg <= 1'b0;
        end
        else begin
            /*
             * AES controls are one-clock pulses.
             */
            enc_start <= 1'b0;
            dec_kld   <= 1'b0;
            dec_ld    <= 1'b0;

            /*
             * AES output capture.
             *
             * The OpenCores AES cores update text_out on the same
             * clock edge on which their done signal is generated.
             * The existing standalone AES testbench uses the value
             * after that clock. The AXI wrapper therefore stores the
             * result directly when done is observed.
             */
            if (enc_done) begin
                data_out_reg <= enc_out;
                enc_done_reg <= 1'b1;
            end

            if (dec_done) begin
                data_out_reg <= dec_out;
                dec_done_reg <= 1'b1;
            end

            /*
             * AXI WRITE ADDRESS
             */
            if (AWVALID && AWREADY) begin
                aw_pending <= 1'b1;
                awid_reg   <= AWID;
                awaddr_reg <= AWADDR;
            end

            /*
             * AXI WRITE DATA
             */
            if (WVALID && WREADY) begin
                case (addr_word(awaddr_reg))

                    A_KEY0:
                        key_reg[31:0] <= WDATA;

                    A_KEY1:
                        key_reg[63:32] <= WDATA;

                    A_KEY2:
                        key_reg[95:64] <= WDATA;

                    A_KEY3:
                        key_reg[127:96] <= WDATA;

                    A_IN0:
                        data_in_reg[31:0] <= WDATA;

                    A_IN1:
                        data_in_reg[63:32] <= WDATA;

                    A_IN2:
                        data_in_reg[95:64] <= WDATA;

                    A_IN3:
                        data_in_reg[127:96] <= WDATA;

                    A_CTRL: begin

                        /*
                         * ENCRYPTION START
                         *
                         * At the same time load the inverse AES key
                         * schedule. This is intentional: the proven
                         * standalone AES testbench also asserts kld
                         * before the encryption completes.
                         */
                        if (WDATA[0]) begin
                            enc_start    <= 1'b1;
                            dec_kld      <= 1'b1;

                            enc_done_reg <= 1'b0;
                            dec_done_reg <= 1'b0;
                        end

                        /*
                         * DECRYPTION START
                         *
                         * The inverse key has already been expanded
                         * during encryption. Only ld is required now.
                         */
                        if (WDATA[1]) begin
                            dec_ld       <= 1'b1;
                            dec_done_reg <= 1'b0;
                        end
                    end

                    default: begin
                    end

                endcase

                aw_pending <= 1'b0;
                bvalid_reg <= 1'b1;
                bid_reg    <= awid_reg;
                bresp_reg  <= 2'b00;
            end

            /*
             * AXI WRITE RESPONSE
             */
            if (bvalid_reg && BREADY)
                bvalid_reg <= 1'b0;

            /*
             * AXI READ
             */
            if (ARVALID && ARREADY) begin
                rid_reg   <= ARID;
                rresp_reg <= 2'b00;
                rlast_reg <= 1'b1;

                case (addr_word(ARADDR))

                    A_KEY0:
                        rdata_reg <= key_reg[31:0];

                    A_KEY1:
                        rdata_reg <= key_reg[63:32];

                    A_KEY2:
                        rdata_reg <= key_reg[95:64];

                    A_KEY3:
                        rdata_reg <= key_reg[127:96];

                    A_IN0:
                        rdata_reg <= data_in_reg[31:0];

                    A_IN1:
                        rdata_reg <= data_in_reg[63:32];

                    A_IN2:
                        rdata_reg <= data_in_reg[95:64];

                    A_IN3:
                        rdata_reg <= data_in_reg[127:96];

                    A_CTRL:
                        rdata_reg <= 32'b0;

                    A_STAT:
                        rdata_reg <= {30'b0, dec_done_reg, enc_done_reg};

                    A_OUT0:
                        rdata_reg <= data_out_reg[31:0];

                    A_OUT1:
                        rdata_reg <= data_out_reg[63:32];

                    A_OUT2:
                        rdata_reg <= data_out_reg[95:64];

                    A_OUT3:
                        rdata_reg <= data_out_reg[127:96];

                    default:
                        rdata_reg <= 32'b0;

                endcase

                rvalid_reg <= 1'b1;
            end

            /*
             * AXI READ RESPONSE
             */
            if (rvalid_reg && RREADY)
                rvalid_reg <= 1'b0;

        end
    end

endmodule
