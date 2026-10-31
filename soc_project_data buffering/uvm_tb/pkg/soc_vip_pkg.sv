// =============================================================================
// Package: soc_vip_pkg.sv
// Description: Supplementary VIP package containing the generated agent,
//              driver, monitor, sequencer, sequence, and environment templates
//              derived from Docs/soc_test_plan.csv.
//
// This package is intentionally separate from the existing soc_uvm_pkg.sv to
// avoid class name collisions. soc_uvm_pkg.sv defines its own (lighter-weight)
// soc_axi_agent / soc_stream_agent used by the existing 5-member UVM tests.
// This VIP package provides fuller, standalone VIP components for directed
// test cases TC_MEM_IMEM_03 through TC_DMA_ABORT_20.
//
// Included files (generated from CSV interface analysis):
//   Sequence items:
//     seq/soc_axi_seq_item.sv
//     seq/soc_stream_seq_item.sv
//     seq/soc_irq_seq_item.sv
//   Agents:
//     agents/soc_axi_sequencer.sv
//     agents/soc_axi_driver.sv
//     agents/soc_axi_monitor.sv
//     agents/soc_axi_agent.sv
//     agents/soc_stream_agent.sv   (includes sequencer, driver, monitor)
//     agents/soc_irq_agent.sv      (includes monitor only — passive)
//   Sequences:
//     seq/soc_axi_sequences.sv
//     seq/soc_stream_sequences.sv
//   Environment:
//     env/soc_env.sv
//   Tests:
//     tests/soc_base_test.sv
//     tests/soc_directed_tests.sv
//
// Interface signal CSVs (documenting each interface's signal set):
//     if/soc_axi_if_signals.csv
//     if/soc_stream_if_signals.csv
//     if/soc_irq_if_signals.csv
// =============================================================================

`ifndef SOC_VIP_PKG_SV
`define SOC_VIP_PKG_SV

package soc_vip_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // -----------------------------------------------------------------------
    // Sequence Items
    // -----------------------------------------------------------------------
    `include "soc_axi_seq_item.sv"
    `include "soc_stream_seq_item.sv"
    `include "soc_irq_seq_item.sv"

    // -----------------------------------------------------------------------
    // Agent components — AXI4 Master
    // -----------------------------------------------------------------------
    `include "soc_axi_sequencer.sv"
    `include "soc_axi_driver.sv"
    `include "soc_axi_monitor.sv"
    `include "soc_axi_agent.sv"

    // -----------------------------------------------------------------------
    // Agent components — Sensor Stream (sequencer, driver, monitor, agent
    //                    all in one file for the stream interface)
    // -----------------------------------------------------------------------
    `include "soc_stream_agent.sv"

    // -----------------------------------------------------------------------
    // Agent components — IRQ/UART observation (monitor + agent, passive)
    // -----------------------------------------------------------------------
    `include "soc_irq_agent.sv"

    // -----------------------------------------------------------------------
    // Sequences
    // -----------------------------------------------------------------------
    `include "soc_axi_sequences.sv"
    `include "soc_stream_sequences.sv"

    // -----------------------------------------------------------------------
    // Environment
    // -----------------------------------------------------------------------
    `include "soc_env.sv"

    // -----------------------------------------------------------------------
    // Tests
    // -----------------------------------------------------------------------
    `include "soc_base_test.sv"
    `include "soc_directed_tests.sv"

endpackage : soc_vip_pkg

`endif // SOC_VIP_PKG_SV
