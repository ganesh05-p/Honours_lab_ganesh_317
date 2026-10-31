// =============================================================================
// File        : soc_base_test.sv
// Description : UVM Base Test for soc_data_buffering_top
//               Instantiates soc_env and sets virtual interface handles via
//               uvm_config_db. All directed tests extend this class.
// =============================================================================

`ifndef SOC_BASE_TEST_SV
`define SOC_BASE_TEST_SV

class soc_base_test extends uvm_test;
    `uvm_component_utils(soc_base_test)

    soc_env env;

    function new(string name = "soc_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = soc_env::type_id::create("env", this);

        // Virtual interface handles must be set by the top-level testbench
        // before simulation using uvm_config_db #(virtual soc_axi_if)::set(...)
        // The base test reads them back here to confirm they exist.
        begin
            virtual soc_axi_if    axi_vif;
            virtual soc_stream_if stream_vif;
            virtual soc_irq_if    irq_vif;
            if (!uvm_config_db #(virtual soc_axi_if)::get(this, "", "soc_axi_vif", axi_vif))
                `uvm_fatal("CFG", "soc_axi_vif not set in config_db — set from tb_soc_uvm_top")
            if (!uvm_config_db #(virtual soc_stream_if)::get(this, "", "soc_stream_vif", stream_vif))
                `uvm_fatal("CFG", "soc_stream_vif not set in config_db — set from tb_soc_uvm_top")
            if (!uvm_config_db #(virtual soc_irq_if)::get(this, "", "soc_irq_vif", irq_vif))
                `uvm_fatal("CFG", "soc_irq_vif not set in config_db — set from tb_soc_uvm_top")
        end
    endfunction

    task run_phase(uvm_phase phase);
        // Base test: no sequence — override in derived tests
        phase.raise_objection(this);
        #100ns;
        phase.drop_objection(this);
    endtask

    function void report_phase(uvm_phase phase);
        uvm_report_server rs = uvm_report_server::get_server();
        if (rs.get_severity_count(UVM_FATAL) + rs.get_severity_count(UVM_ERROR) == 0)
            `uvm_info("TEST", $sformatf("** TEST PASSED: %s **", get_name()), UVM_NONE)
        else
            `uvm_info("TEST", $sformatf("** TEST FAILED: %s **", get_name()), UVM_NONE)
    endfunction

endclass : soc_base_test

`endif // SOC_BASE_TEST_SV
