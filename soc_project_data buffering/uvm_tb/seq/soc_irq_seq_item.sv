// =============================================================================
// File        : soc_irq_seq_item.sv
// Description : UVM Sequence Item capturing a sampled IRQ/UART observation.
//
// CSV Tests: TC_UART_TX_06, TC_FIFO_IRQ_11, TC_DMA_IRQ_14,
//            TC_PLIC_15, TC_E2E_DATA_17
// =============================================================================

`ifndef SOC_IRQ_SEQ_ITEM_SV
`define SOC_IRQ_SEQ_ITEM_SV

class soc_irq_seq_item extends uvm_sequence_item;
    `uvm_object_utils_begin(soc_irq_seq_item)
        `uvm_field_int(fifo_irq,    UVM_ALL_ON)
        `uvm_field_int(dma_irq,     UVM_ALL_ON)
        `uvm_field_int(uart_irq,    UVM_ALL_ON)
        `uvm_field_int(cpu_eip,     UVM_ALL_ON)
        `uvm_field_int(uart_tx_bit, UVM_ALL_ON)
        `uvm_field_int(timestamp,   UVM_ALL_ON)
    `uvm_object_utils_end

    // Observed signal values at one clock edge
    logic       fifo_irq;
    logic       dma_irq;
    logic       uart_irq;
    logic [1:0] cpu_eip;
    logic       uart_tx_bit;   // Raw serial bit (for UART decode)
    time        timestamp;     // Simulation time of observation

    function new(string name = "soc_irq_seq_item");
        super.new(name);
    endfunction

    function string convert2string();
        return $sformatf("[IRQ @%0t] fifo=%0b dma=%0b uart=%0b eip=0x%0h uart_tx=%0b",
                         timestamp, fifo_irq, dma_irq, uart_irq, cpu_eip, uart_tx_bit);
    endfunction

endclass : soc_irq_seq_item

`endif // SOC_IRQ_SEQ_ITEM_SV
