// =============================================================================
// File        : soc_axi_sequencer.sv
// Description : UVM Sequencer for AXI4 Master Agent
// =============================================================================

`ifndef SOC_AXI_SEQUENCER_SV
`define SOC_AXI_SEQUENCER_SV

class soc_axi_sequencer extends uvm_sequencer #(soc_axi_seq_item);
    `uvm_component_utils(soc_axi_sequencer)

    function new(string name = "soc_axi_sequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction

endclass : soc_axi_sequencer

`endif // SOC_AXI_SEQUENCER_SV
