`timescale 1ns/1ps

module tb_axi_aes;

    reg         clk;
    reg         reset;

    // AXI write address channel
    reg  [3:0]  AWID;
    reg [31:0]  AWADDR;
    reg  [3:0]  AWLEN;
    reg  [2:0]  AWSIZE;
    reg  [1:0]  AWBURST;
    reg         AWVALID;
    wire        AWREADY;

    // AXI write data channel
    reg  [3:0]  WID;
    reg [31:0]  WDATA;
    reg         WLAST;
    reg         WVALID;
    wire        WREADY;

    // AXI write response channel
    wire [3:0]  BID;
    wire [1:0]  BRESP;
    wire        BVALID;
    reg         BREADY;

    // AXI read address channel
    reg  [3:0]  ARID;
    reg [31:0]  ARADDR;
    reg  [3:0]  ARLEN;
    reg  [2:0]  ARSIZE;
    reg  [1:0]  ARBURST;
    reg         ARVALID;
    wire        ARREADY;

    // AXI read data channel
    wire [3:0]  RID;
    wire [31:0] RDATA;
    wire [1:0]  RRESP;
    wire        RVALID;
    wire        RLAST;
    reg         RREADY;

    integer errors;
    reg [31:0] read_data;

    // AES AXI slave
    aes_axi_slave dut (
        .clk      (clk),
        .reset    (reset),

        .AWID     (AWID),
        .AWADDR   (AWADDR),
        .AWLEN    (AWLEN),
        .AWSIZE   (AWSIZE),
        .AWBURST  (AWBURST),
        .AWVALID  (AWVALID),
        .AWREADY  (AWREADY),

        .WID      (WID),
        .WDATA    (WDATA),
        .WLAST    (WLAST),
        .WVALID   (WVALID),
        .WREADY   (WREADY),

        .BID      (BID),
        .BRESP    (BRESP),
        .BVALID   (BVALID),
        .BREADY   (BREADY),

        .ARID     (ARID),
        .ARADDR   (ARADDR),
        .ARLEN    (ARLEN),
        .ARSIZE   (ARSIZE),
        .ARBURST  (ARBURST),
        .ARVALID  (ARVALID),
        .ARREADY  (ARREADY),

        .RID      (RID),
        .RDATA    (RDATA),
        .RRESP    (RRESP),
        .RVALID   (RVALID),
        .RLAST    (RLAST),
        .RREADY   (RREADY)
    );

    // 100 MHz clock
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // AXI single-beat write
    task axi_write;
        input [31:0] addr;
        input [31:0] data;
        begin
            @(posedge clk);
            AWID    <= 4'h1;
            AWADDR  <= addr;
            AWLEN   <= 4'h0;
            AWSIZE  <= 3'b010;
            AWBURST <= 2'b01;
            AWVALID <= 1'b1;

            while (!AWREADY)
                @(posedge clk);

            @(posedge clk);
            AWVALID <= 1'b0;

            WID     <= 4'h1;
            WDATA   <= data;
            WLAST   <= 1'b1;
            WVALID  <= 1'b1;

            while (!WREADY)
                @(posedge clk);

            @(posedge clk);
            WVALID <= 1'b0;

            BREADY <= 1'b1;
            while (!BVALID)
                @(posedge clk);

            if (BRESP !== 2'b00) begin
                $display("ERROR: AXI write response error at address %h", addr);
                errors = errors + 1;
            end

            @(posedge clk);
            BREADY <= 1'b0;
        end
    endtask

    // AXI single-beat read
    task axi_read;
        input  [31:0] addr;
        output [31:0] data;
        begin
            @(posedge clk);
            ARID    <= 4'h2;
            ARADDR  <= addr;
            ARLEN   <= 4'h0;
            ARSIZE  <= 3'b010;
            ARBURST <= 2'b01;
            ARVALID <= 1'b1;

            while (!ARREADY)
                @(posedge clk);

            @(posedge clk);
            ARVALID <= 1'b0;

            RREADY <= 1'b1;
            while (!RVALID)
                @(posedge clk);

            data = RDATA;

            if (RRESP !== 2'b00) begin
                $display("ERROR: AXI read response error at address %h", addr);
                errors = errors + 1;
            end

            if (!RLAST) begin
                $display("ERROR: AXI read did not assert RLAST");
                errors = errors + 1;
            end

            @(posedge clk);
            RREADY <= 1'b0;
        end
    endtask

    initial begin
        errors = 0;

        AWID    = 0;
        AWADDR  = 0;
        AWLEN   = 0;
        AWSIZE  = 0;
        AWBURST = 0;
        AWVALID = 0;

        WID     = 0;
        WDATA   = 0;
        WLAST   = 0;
        WVALID  = 0;

        BREADY  = 0;

        ARID    = 0;
        ARADDR  = 0;
        ARLEN   = 0;
        ARSIZE  = 0;
        ARBURST = 0;
        ARVALID = 0;

        RREADY  = 0;

        // Active-low reset, same convention as the original AES testbench.
        reset = 1'b0;
        repeat (5) @(posedge clk);
        reset = 1'b1;
        repeat (2) @(posedge clk);

        `ifdef WAVES
            $fsdbDumpfile("dump.fsdb");
            $fsdbDumpvars(0, tb_axi_aes);
        `endif

        $display("\n==============================================");
        $display(" AXI AES SLAVE TEST START");
        $display("==============================================\n");

        // AES-128 standard test vector.
        // KEY  = 000102030405060708090a0b0c0d0e0f
        // DATA = 00112233445566778899aabbccddeeff
        // ENC  = 69c4e0d86a7b0430d8cdb78070b4c55a

        $display("Writing AES key...");
        axi_write(32'h0000_0000, 32'h0c0d0e0f);
        axi_write(32'h0000_0004, 32'h08090a0b);
        axi_write(32'h0000_0008, 32'h04050607);
        axi_write(32'h0000_000c, 32'h00010203);

        $display("Writing plaintext...");
        axi_write(32'h0000_0010, 32'hccddeeff);
        axi_write(32'h0000_0014, 32'h8899aabb);
        axi_write(32'h0000_0018, 32'h44556677);
        axi_write(32'h0000_001c, 32'h00112233);

        $display("Starting AES encryption...");
        axi_write(32'h0000_0020, 32'h0000_0001);

        // Poll STATUS until encryption completes.
        read_data = 0;
        while (read_data[0] !== 1'b1) begin
            axi_read(32'h0000_0024, read_data);
        end

        $display("Encryption completed.");

        // Read ciphertext.
        axi_read(32'h0000_0028, read_data);
        if (read_data !== 32'h70b4c55a) begin
            $display("ERROR: Ciphertext[31:0]  expected 70b4c55a, got %h", read_data);
            errors = errors + 1;
        end

        axi_read(32'h0000_002c, read_data);
        if (read_data !== 32'hd8cdb780) begin
            $display("ERROR: Ciphertext[63:32] expected d8cdb780, got %h", read_data);
            errors = errors + 1;
        end

        axi_read(32'h0000_0030, read_data);
        if (read_data !== 32'h6a7b0430) begin
            $display("ERROR: Ciphertext[95:64] expected 6a7b0430, got %h", read_data);
            errors = errors + 1;
        end

        axi_read(32'h0000_0034, read_data);
        if (read_data !== 32'h69c4e0d8) begin
            $display("ERROR: Ciphertext[127:96] expected 69c4e0d8, got %h", read_data);
            errors = errors + 1;
        end

        if (errors == 0)
            $display("\nPASS: AXI AES encryption test completed with 0 errors.\n");
        else
            $display("\nFAIL: AXI AES test completed with %0d errors.\n", errors);

        $finish;
    end

endmodule
