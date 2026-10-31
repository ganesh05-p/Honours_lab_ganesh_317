// =============================================================================
// File        : soc_stream_seq_item.sv
// Description : UVM Sequence Item for Sensor Stream Interface
//               Models one or more sensor sample pushes via valid/ready
//               handshake on sample_stream_* top-level ports.
//
// CSV Tests: TC_FIFO_STREAM_09, TC_FIFO_OVF_19, TC_E2E_DATA_17
// =============================================================================

`ifndef SOC_STREAM_SEQ_ITEM_SV
`define SOC_STREAM_SEQ_ITEM_SV

class soc_stream_seq_item extends uvm_sequence_item;
    `uvm_object_utils_begin(soc_stream_seq_item)
        `uvm_field_int(sample_data, UVM_ALL_ON)
        // Observed response — set by driver/monitor after handshake
        `uvm_field_int(ready_seen, UVM_ALL_ON)
    `uvm_object_utils_end

    // -------------------------------------------------------------------------
    // Fields
    // -------------------------------------------------------------------------
    rand logic [31:0] sample_data;  // Sensor vibration sample value
    logic             ready_seen;   // 1 = FIFO accepted sample (ready was high)

    // Constraints
    constraint c_valid_vibration {
        sample_data inside {[0:255]};   // 8-bit sensor range per CSV test vectors
    }

    function new(string name = "soc_stream_seq_item");
        super.new(name);
    endfunction

    function string convert2string();
        return $sformatf("[STREAM] data=0x%08h ready_seen=%0b",
                         sample_data, ready_seen);
    endfunction

endclass : soc_stream_seq_item

`endif // SOC_STREAM_SEQ_ITEM_SV
