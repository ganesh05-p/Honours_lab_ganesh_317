// =============================================================================
// File        : soc_irq_agent.sv
// Description : UVM Agent for IRQ/UART Observation Interface (passive only)
//               Monitor samples fifo_irq, dma_irq, uart_irq, cpu_eip, uart_tx
//               from soc_irq_if and publishes soc_irq_seq_item on analysis port.
//
// Note: This agent is always UVM_PASSIVE — it observes outputs only.
//       No driver or sequencer is instantiated.
// =============================================================================

`ifndef SOC_IRQ_AGENT_SV
`define SOC_IRQ_AGENT_SV

// -----------------------------------------------------------------------------
// Monitor
// -----------------------------------------------------------------------------
class soc_irq_monitor extends uvm_monitor;
    `uvm_component_utils(soc_irq_monitor)

    virtual soc_irq_if vif;
    uvm_analysis_port #(soc_irq_seq_item) ap;

    function new(string name = "soc_irq_monitor", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_config_db #(virtual soc_irq_if)::get(this, "", "soc_irq_vif", vif))
            `uvm_fatal("NO_VIF", "soc_irq_monitor: soc_irq_vif not found in config_db")
    endfunction

    task run_phase(uvm_phase phase);
        soc_irq_seq_item txn;
        logic prev_fifo_irq = 1'b0;
        logic prev_dma_irq  = 1'b0;
        logic prev_uart_tx  = 1'b1;  // UART idle = 1

        forever begin
            @(vif.mon_cb);
            // Publish item on any IRQ assertion edge or uart_tx transition
            if (   (vif.mon_cb.fifo_irq !== prev_fifo_irq)
                || (vif.mon_cb.dma_irq  !== prev_dma_irq)
                || (vif.mon_cb.uart_tx  !== prev_uart_tx)) begin

                txn = soc_irq_seq_item::type_id::create("irq_txn");
                txn.fifo_irq    = vif.mon_cb.fifo_irq;
                txn.dma_irq     = vif.mon_cb.dma_irq;
                txn.uart_irq    = vif.mon_cb.uart_irq;
                txn.cpu_eip     = vif.mon_cb.cpu_eip;
                txn.uart_tx_bit = vif.mon_cb.uart_tx;
                txn.timestamp   = $time;
                ap.write(txn);
                `uvm_info("IRQ_MON", txn.convert2string(), UVM_HIGH)
            end
            prev_fifo_irq = vif.mon_cb.fifo_irq;
            prev_dma_irq  = vif.mon_cb.dma_irq;
            prev_uart_tx  = vif.mon_cb.uart_tx;
        end
    endtask

    // -------------------------------------------------------------------------
    // Convenience: wait for a specific IRQ to assert (with timeout)
    // -------------------------------------------------------------------------
    task wait_for_dma_irq(int timeout_cycles = 200);
        int cnt = 0;
        while (!vif.mon_cb.dma_irq) begin
            @(vif.mon_cb);
            cnt++;
            if (cnt >= timeout_cycles)
                `uvm_error("IRQ_MON",
                    $sformatf("TC_DMA_IRQ_14 FAIL: dma_irq not seen within %0d cycles",
                               timeout_cycles))
        end
        `uvm_info("IRQ_MON",
            $sformatf("TC_DMA_IRQ_14: dma_irq asserted after %0d cycles", cnt), UVM_MEDIUM)
    endtask

    task wait_for_fifo_irq(int timeout_cycles = 100);
        int cnt = 0;
        while (!vif.mon_cb.fifo_irq) begin
            @(vif.mon_cb);
            cnt++;
            if (cnt >= timeout_cycles)
                `uvm_error("IRQ_MON",
                    $sformatf("TC_FIFO_IRQ_11 FAIL: fifo_irq not seen within %0d cycles",
                               timeout_cycles))
        end
        `uvm_info("IRQ_MON",
            $sformatf("TC_FIFO_IRQ_11: fifo_irq asserted after %0d cycles", cnt), UVM_MEDIUM)
    endtask

    task wait_for_uart_start_bit(int timeout_cycles = 10000);
        int cnt = 0;
        // UART idle = 1; start bit = 0
        while (vif.mon_cb.uart_tx !== 1'b0) begin
            @(vif.mon_cb);
            cnt++;
            if (cnt >= timeout_cycles)
                `uvm_error("IRQ_MON",
                    $sformatf("TC_UART_TX_06 FAIL: uart_tx start bit not seen within %0d cycles",
                               timeout_cycles))
        end
        `uvm_info("IRQ_MON",
            $sformatf("TC_UART_TX_06: uart_tx start bit detected at %0t", $time), UVM_MEDIUM)
    endtask

endclass : soc_irq_monitor

// -----------------------------------------------------------------------------
// Agent (passive only)
// -----------------------------------------------------------------------------
class soc_irq_agent extends uvm_agent;
    `uvm_component_utils(soc_irq_agent)

    soc_irq_monitor monitor;
    uvm_analysis_port #(soc_irq_seq_item) ap;

    function new(string name = "soc_irq_agent", uvm_component parent = null);
        super.new(name, parent);
        // Force passive — no driver or sequencer
        is_active = UVM_PASSIVE;
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap      = new("ap", this);
        monitor = soc_irq_monitor::type_id::create("monitor", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        monitor.ap.connect(ap);
    endfunction

endclass : soc_irq_agent

`endif // SOC_IRQ_AGENT_SV
