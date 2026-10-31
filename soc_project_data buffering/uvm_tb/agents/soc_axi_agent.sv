// =============================================================================
// File        : soc_axi_agent.sv
// Description : UVM Agent for AXI4 Master Interface
//               Contains: sequencer, driver, monitor.
//               Set is_active = UVM_PASSIVE to disable driver/sequencer
//               when used as a pure monitor.
// =============================================================================

`ifndef SOC_AXI_AGENT_SV
`define SOC_AXI_AGENT_SV

class soc_axi_agent extends uvm_agent;
    `uvm_component_utils(soc_axi_agent)

    soc_axi_sequencer sequencer;
    soc_axi_driver    driver;
    soc_axi_monitor   monitor;

    // Analysis port forwarded from monitor
    uvm_analysis_port #(soc_axi_seq_item) ap;

    function new(string name = "soc_axi_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap      = new("ap", this);
        monitor = soc_axi_monitor::type_id::create("monitor", this);
        if (get_is_active() == UVM_ACTIVE) begin
            sequencer = soc_axi_sequencer::type_id::create("sequencer", this);
            driver    = soc_axi_driver::type_id::create("driver", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        monitor.ap.connect(ap);
        if (get_is_active() == UVM_ACTIVE)
            driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction

endclass : soc_axi_agent

`endif // SOC_AXI_AGENT_SV
