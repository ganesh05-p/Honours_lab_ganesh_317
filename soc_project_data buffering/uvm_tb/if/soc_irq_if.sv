// =============================================================================
// Interface: soc_irq_if.sv
// Description: Observability Interface for Interrupts and UART Serial TX
// =============================================================================

`ifndef SOC_IRQ_IF_SV
`define SOC_IRQ_IF_SV

interface soc_irq_if (
    input logic clk,
    input logic rst_n
);

    logic       fifo_irq;
    logic       dma_irq;
    logic       uart_irq;
    logic [1:0] cpu_eip;
    logic       uart_tx;

    clocking mon_cb @(posedge clk);
        default input #1ns;
        input fifo_irq, dma_irq, uart_irq, cpu_eip, uart_tx;
    endclocking

    modport monitor (clocking mon_cb, input clk, input rst_n);

endinterface : soc_irq_if

`endif // SOC_IRQ_IF_SV
