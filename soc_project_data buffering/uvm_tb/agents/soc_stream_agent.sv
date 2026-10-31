// =============================================================================
// File        : soc_stream_agent.sv
// Description : UVM Agent for Sensor Stream Interface (soc_stream_if)
//               Contains: sequencer, driver (active), monitor (passive).
//               Drives sample_stream_valid/data into DUT;
//               observes sample_stream_ready back-pressure.
// =============================================================================

`ifndef SOC_STREAM_AGENT_SV
`define SOC_STREAM_AGENT_SV

// -----------------------------------------------------------------------------
// Sequencer
// -----------------------------------------------------------------------------
class soc_stream_sequencer extends uvm_sequencer #(soc_stream_seq_item);
    `uvm_component_utils(soc_stream_sequencer)
    function new(string name = "soc_stream_sequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass : soc_stream_sequencer

// -----------------------------------------------------------------------------
// Driver
// -----------------------------------------------------------------------------
class soc_stream_driver extends uvm_driver #(soc_stream_seq_item);
    `uvm_component_utils(soc_stream_driver)

    virtual soc_stream_if vif;

    function new(string name = "soc_stream_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual soc_stream_if)::get(this, "", "soc_stream_vif", vif))
            `uvm_fatal("NO_VIF", "soc_stream_driver: soc_stream_vif not found in config_db")
    endfunction

    task run_phase(uvm_phase phase);
        soc_stream_seq_item req;
        // Safe idle: de-assert valid
        @(posedge vif.clk);
        vif.drv_cb.valid <= 1'b0;
        vif.drv_cb.data  <= '0;
        forever begin
            seq_item_port.get_next_item(req);
            drive_sample(req);
            seq_item_port.item_done();
        end
    endtask

    // Drive one sample using valid/ready handshake.
    // Waits for ready before deasserting valid (compliant handshake).
    task drive_sample(soc_stream_seq_item req);
        @(vif.drv_cb);
        vif.drv_cb.valid <= 1'b1;
        vif.drv_cb.data  <= req.sample_data;
        // Wait until FIFO accepts (ready high)
        do @(vif.drv_cb); while (!vif.drv_cb.ready);
        req.ready_seen = 1'b1;
        vif.drv_cb.valid <= 1'b0;
        `uvm_info("STREAM_DRV", req.convert2string(), UVM_HIGH)
    endtask

endclass : soc_stream_driver

// -----------------------------------------------------------------------------
// Monitor
// -----------------------------------------------------------------------------
class soc_stream_monitor extends uvm_monitor;
    `uvm_component_utils(soc_stream_monitor)

    virtual soc_stream_if vif;
    uvm_analysis_port #(soc_stream_seq_item) ap;

    function new(string name = "soc_stream_monitor", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_config_db #(virtual soc_stream_if)::get(this, "", "soc_stream_vif", vif))
            `uvm_fatal("NO_VIF", "soc_stream_monitor: soc_stream_vif not found in config_db")
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            soc_stream_seq_item txn;
            txn = soc_stream_seq_item::type_id::create("mon_txn");
            // Wait for accepted handshake (valid AND ready)
            do @(vif.mon_cb); while (!(vif.mon_cb.valid && vif.mon_cb.ready));
            txn.sample_data = vif.mon_cb.data;
            txn.ready_seen  = 1'b1;
            ap.write(txn);
            `uvm_info("STREAM_MON", txn.convert2string(), UVM_HIGH)
        end
    endtask

endclass : soc_stream_monitor

// -----------------------------------------------------------------------------
// Agent
// -----------------------------------------------------------------------------
class soc_stream_agent extends uvm_agent;
    `uvm_component_utils(soc_stream_agent)

    soc_stream_sequencer sequencer;
    soc_stream_driver    driver;
    soc_stream_monitor   monitor;

    uvm_analysis_port #(soc_stream_seq_item) ap;

    function new(string name = "soc_stream_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap      = new("ap", this);
        monitor = soc_stream_monitor::type_id::create("monitor", this);
        if (get_is_active() == UVM_ACTIVE) begin
            sequencer = soc_stream_sequencer::type_id::create("sequencer", this);
            driver    = soc_stream_driver::type_id::create("driver", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        monitor.ap.connect(ap);
        if (get_is_active() == UVM_ACTIVE)
            driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction

endclass : soc_stream_agent

`endif // SOC_STREAM_AGENT_SV
