// =============================================================================
// File        : soc_env.sv
// Description : Top-Level UVM Environment for soc_data_buffering_top
//               Instantiates all three agents required by the CSV test plan:
//                 - soc_axi_agent    (active: drives ext_s00_axi_* port)
//                 - soc_stream_agent (active: drives sample_stream_* port)
//                 - soc_irq_agent    (passive: monitors IRQ/UART outputs)
// =============================================================================

`ifndef SOC_ENV_SV
`define SOC_ENV_SV

class soc_env extends uvm_env;
    `uvm_component_utils(soc_env)

    // Agents
    soc_axi_agent    axi_agent;     // AXI4 master injection
    soc_stream_agent stream_agent;  // Sensor stream stimulus
    soc_irq_agent    irq_agent;     // IRQ/UART observation

    function new(string name = "soc_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        axi_agent    = soc_axi_agent::type_id::create("axi_agent", this);
        stream_agent = soc_stream_agent::type_id::create("stream_agent", this);
        irq_agent    = soc_irq_agent::type_id::create("irq_agent", this);

        // Set is_active = UVM_ACTIVE for driving agents
        uvm_config_db #(uvm_active_passive_enum)::set(this, "axi_agent",    "is_active", UVM_ACTIVE);
        uvm_config_db #(uvm_active_passive_enum)::set(this, "stream_agent", "is_active", UVM_ACTIVE);
        // irq_agent is always passive (set in its constructor)
    endfunction

    // connect_phase: scoreboards / coverage can be connected here in derived envs
    function void connect_phase(uvm_phase phase);
    endfunction

endclass : soc_env

`endif // SOC_ENV_SV
