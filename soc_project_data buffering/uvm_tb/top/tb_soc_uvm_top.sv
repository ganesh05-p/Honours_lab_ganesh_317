// =============================================================================
// Top Testbench: tb_soc_uvm_top.sv
// Project: RISC-V VeeR EL2 Real-Time Data Buffering SoC
// Description: UVM Top Module connecting DUT, Interfaces, and test execution
// =============================================================================

`timescale 1ns/1ps

`include "uvm_macros.svh"

module tb_soc_uvm_top;
    import uvm_pkg::*;
    import soc_uvm_pkg::*;

    // Clock and Reset
    logic clk;
    logic rst_l;

    initial begin
        clk = 1'b0;
        forever #5ns clk = ~clk; // 100 MHz clock
    end

    initial begin
        rst_l = 1'b0;
        #50ns;
        @(posedge clk);
        rst_l = 1'b1;
    end

    // Interfaces
    soc_axi_if #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32),
        .ID_WIDTH(8)
    ) axi_if (
        .clk  (clk),
        .rst_n(rst_l)
    );

    soc_stream_if stream_if (
        .clk  (clk),
        .rst_n(rst_l)
    );

    soc_irq_if irq_if (
        .clk  (clk),
        .rst_n(rst_l)
    );

    // DUT Signals
    logic        uart_rx;
    logic        uart_tx;
    logic        fifo_irq;
    logic        dma_irq;
    logic        uart_irq;
    logic [1:0]  cpu_eip;

    assign uart_rx = 1'b1; // Idle high

    // Connect IRQ interface
    assign irq_if.fifo_irq = fifo_irq;
    assign irq_if.dma_irq  = dma_irq;
    assign irq_if.uart_irq = uart_irq;
    assign irq_if.cpu_eip  = cpu_eip;
    assign irq_if.uart_tx  = uart_tx;

    // Instantiate SoC Top with Direct External Master enabled for UVM DV testing
    soc_data_buffering_top #(
        .ADDR_WIDTH         (32),
        .DATA_WIDTH         (32),
        .ID_WIDTH           (8),
        .CPU_TAG_WIDTH      (4),
        .FIFO_DEPTH         (64),
        .MEM_ADDR_WIDTH     (16),
        .DMA_NUM_CH         (4),
        .PLIC_NUM_SOURCES   (32),
        .PLIC_NUM_TARGETS   (2),
        .ENABLE_INTERNAL_CPU(1'b0) // Direct UVM Bus Master Mode
    ) u_dut (
        .clk                (clk),
        .rst_l              (rst_l),

        // Sensor Streaming Samples
        .sample_stream_valid(stream_if.valid),
        .sample_stream_data (stream_if.data),
        .sample_stream_ready(stream_if.ready),

        // UART
        .uart_tx            (uart_tx),
        .uart_rx            (uart_rx),

        // Interrupts
        .fifo_irq_o         (fifo_irq),
        .dma_irq_o          (dma_irq),
        .uart_irq_o         (uart_irq),
        .cpu_eip_o          (cpu_eip),

        // External AXI Master Port S00 (driven by UVM AXI Agent)
        .ext_s00_axi_awid   (axi_if.awid),
        .ext_s00_axi_awaddr (axi_if.awaddr),
        .ext_s00_axi_awlen  (axi_if.awlen),
        .ext_s00_axi_awsize (axi_if.awsize),
        .ext_s00_axi_awburst(axi_if.awburst),
        .ext_s00_axi_awvalid(axi_if.awvalid),
        .ext_s00_axi_awready(axi_if.awready),
        .ext_s00_axi_wdata  (axi_if.wdata),
        .ext_s00_axi_wstrb  (axi_if.wstrb),
        .ext_s00_axi_wlast  (axi_if.wlast),
        .ext_s00_axi_wvalid (axi_if.wvalid),
        .ext_s00_axi_wready (axi_if.wready),
        .ext_s00_axi_bid    (axi_if.bid),
        .ext_s00_axi_bresp  (axi_if.bresp),
        .ext_s00_axi_bvalid (axi_if.bvalid),
        .ext_s00_axi_bready (axi_if.bready),
        .ext_s00_axi_arid   (axi_if.arid),
        .ext_s00_axi_araddr (axi_if.araddr),
        .ext_s00_axi_arlen  (axi_if.arlen),
        .ext_s00_axi_arsize (axi_if.arsize),
        .ext_s00_axi_arburst(axi_if.arburst),
        .ext_s00_axi_arvalid(axi_if.arvalid),
        .ext_s00_axi_arready(axi_if.arready),
        .ext_s00_axi_rid    (axi_if.rid),
        .ext_s00_axi_rdata  (axi_if.rdata),
        .ext_s00_axi_rresp  (axi_if.rresp),
        .ext_s00_axi_rlast  (axi_if.rlast),
        .ext_s00_axi_rvalid (axi_if.rvalid),
        .ext_s00_axi_rready (axi_if.rready)
    );

    // Initial block: UVM registration & execution
    initial begin
        uvm_config_db#(virtual soc_axi_if)::set(null, "*", "axi_vif", axi_if);
        uvm_config_db#(virtual soc_stream_if)::set(null, "*", "stream_vif", stream_if);
        uvm_config_db#(virtual soc_irq_if)::set(null, "*", "irq_vif", irq_if);

        run_test();
    end

    // Simulation timeout watchdog
    initial begin
        #500us;
        `uvm_fatal("TIMEOUT", "Global simulation watchdog timed out at 500us!")
    end

endmodule : tb_soc_uvm_top
