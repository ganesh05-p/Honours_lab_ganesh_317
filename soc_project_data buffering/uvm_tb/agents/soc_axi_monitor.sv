// =============================================================================
// File        : soc_axi_monitor.sv
// Description : UVM Monitor for AXI4 Master Interface
//               Passively observes all AXI4 channels on soc_axi_if.
//               Broadcasts completed transactions on analysis port for
//               scoreboards and coverage collectors.
// =============================================================================

`ifndef SOC_AXI_MONITOR_SV
`define SOC_AXI_MONITOR_SV

class soc_axi_monitor extends uvm_monitor;
    `uvm_component_utils(soc_axi_monitor)

    virtual soc_axi_if vif;

    // Analysis port — publishes completed soc_axi_seq_item transactions
    uvm_analysis_port #(soc_axi_seq_item) ap;

    function new(string name = "soc_axi_monitor", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_config_db #(virtual soc_axi_if)::get(this, "", "soc_axi_vif", vif))
            `uvm_fatal("NO_VIF", "soc_axi_monitor: soc_axi_vif not found in config_db")
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            soc_axi_seq_item txn;
            txn = soc_axi_seq_item::type_id::create("mon_txn");
            // Detect write vs read using write-address channel as trigger
            fork
                collect_write(txn);
                collect_read(txn);
            join_any
            disable fork;
            ap.write(txn);
        end
    endtask

    // -------------------------------------------------------------------------
    // Collect a write transaction (AW + W + B phases)
    // -------------------------------------------------------------------------
    task collect_write(soc_axi_seq_item txn);
        // Wait for write address valid
        do @(vif.mon_cb); while (!vif.mon_cb.awvalid || !vif.mon_cb.awready);
        txn.txn_type   = soc_axi_seq_item::AXI_WRITE;
        txn.id         = vif.mon_cb.awid;
        txn.addr       = vif.mon_cb.awaddr;
        txn.burst_len  = vif.mon_cb.awlen;
        txn.burst_size = vif.mon_cb.awsize;
        txn.burst_type = vif.mon_cb.awburst;

        // Wait for write data last beat
        do @(vif.mon_cb); while (!vif.mon_cb.wvalid || !vif.mon_cb.wready);
        txn.data  = vif.mon_cb.wdata;
        txn.wstrb = vif.mon_cb.wstrb;

        // Wait for write response
        do @(vif.mon_cb); while (!vif.mon_cb.bvalid || !vif.mon_cb.bready);
        txn.resp = vif.mon_cb.bresp;

        `uvm_info("AXI_MON", txn.convert2string(), UVM_HIGH)
    endtask

    // -------------------------------------------------------------------------
    // Collect a read transaction (AR + R phases)
    // -------------------------------------------------------------------------
    task collect_read(soc_axi_seq_item txn);
        // Wait for read address valid
        do @(vif.mon_cb); while (!vif.mon_cb.arvalid || !vif.mon_cb.arready);
        txn.txn_type   = soc_axi_seq_item::AXI_READ;
        txn.id         = vif.mon_cb.arid;
        txn.addr       = vif.mon_cb.araddr;
        txn.burst_len  = vif.mon_cb.arlen;
        txn.burst_size = vif.mon_cb.arsize;
        txn.burst_type = vif.mon_cb.arburst;

        // Capture first (or only) read data beat
        do @(vif.mon_cb); while (!vif.mon_cb.rvalid || !vif.mon_cb.rready);
        txn.rdata = vif.mon_cb.rdata;
        txn.resp  = vif.mon_cb.rresp;

        `uvm_info("AXI_MON", txn.convert2string(), UVM_HIGH)
    endtask

endclass : soc_axi_monitor

`endif // SOC_AXI_MONITOR_SV
