// =============================================================================
// File        : soc_stream_sequences.sv
// Description : Sensor stream sequences derived from CSV test plan.
//
// Sequences:
//   soc_stream_push_n_seq  - push N configurable samples (TC_FIFO_STREAM_09)
//   soc_stream_e2e_seq     - push the 8 known E2E samples (TC_E2E_DATA_17)
//   soc_stream_overflow_seq - push 65 samples into 64-deep FIFO (TC_FIFO_OVF_19)
// =============================================================================

`ifndef SOC_STREAM_SEQUENCES_SV
`define SOC_STREAM_SEQUENCES_SV

// -----------------------------------------------------------------------------
// Base stream sequence
// -----------------------------------------------------------------------------
class soc_stream_base_seq extends uvm_sequence #(soc_stream_seq_item);
    `uvm_object_utils(soc_stream_base_seq)

    function new(string name = "soc_stream_base_seq");
        super.new(name);
    endfunction

    // Push a single sample; returns after accepted handshake
    task push_sample(logic [31:0] value);
        soc_stream_seq_item req;
        req = soc_stream_seq_item::type_id::create("req");
        start_item(req);
        if (!req.randomize() with { sample_data == value; })
            `uvm_fatal("RAND", "soc_stream_seq_item randomize failed")
        finish_item(req);
    endtask

    virtual task body();
    endtask

endclass : soc_stream_base_seq

// -----------------------------------------------------------------------------
// Push N samples with configurable values — TC_FIFO_STREAM_09
// Set sample_values[] before calling start(sequencer).
// Default: 8 samples per CSV test procedure.
// -----------------------------------------------------------------------------
class soc_stream_push_n_seq extends soc_stream_base_seq;
    `uvm_object_utils(soc_stream_push_n_seq)

    // Configurable list of sample values
    logic [31:0] sample_values[] = '{120, 135, 128, 160, 175, 142, 130, 118};

    function new(string name = "soc_stream_push_n_seq");
        super.new(name);
    endfunction

    task body();
        `uvm_info("STREAM_SEQ",
            $sformatf("TC_FIFO_STREAM_09: pushing %0d samples", sample_values.size()), UVM_MEDIUM)
        foreach (sample_values[i])
            push_sample(sample_values[i]);
        `uvm_info("STREAM_SEQ",
            $sformatf("TC_FIFO_STREAM_09: all %0d samples pushed", sample_values.size()), UVM_MEDIUM)
    endtask

endclass : soc_stream_push_n_seq

// -----------------------------------------------------------------------------
// E2E known sample sequence — TC_E2E_DATA_17
// Exactly [120, 135, 128, 160, 175, 142, 130, 118] per CSV.
// Peak = 175 at index 4.
// -----------------------------------------------------------------------------
class soc_stream_e2e_seq extends soc_stream_base_seq;
    `uvm_object_utils(soc_stream_e2e_seq)

    localparam int NUM_SAMPLES = 8;
    // CSV TC_E2E_DATA_17 fixed sample set
    logic [31:0] e2e_samples[NUM_SAMPLES] = '{120, 135, 128, 160, 175, 142, 130, 118};

    function new(string name = "soc_stream_e2e_seq");
        super.new(name);
    endfunction

    task body();
        `uvm_info("STREAM_SEQ", "TC_E2E_DATA_17: streaming 8 E2E sensor samples", UVM_MEDIUM)
        foreach (e2e_samples[i]) begin
            push_sample(e2e_samples[i]);
            `uvm_info("STREAM_SEQ",
                $sformatf("  sample[%0d] = %0d", i, e2e_samples[i]), UVM_HIGH)
        end
        `uvm_info("STREAM_SEQ", "TC_E2E_DATA_17: E2E stream complete; expected peak=175", UVM_MEDIUM)
    endtask

endclass : soc_stream_e2e_seq

// -----------------------------------------------------------------------------
// Overflow sequence — TC_FIFO_OVF_19
// Pushes 65 samples into a 64-deep FIFO.
// NOTE: The 65th push should see sample_stream_ready drop to 0.
//       The driver stalls until ready returns — the test must observe
//       the ready=0 condition from the monitor before that point.
// -----------------------------------------------------------------------------
class soc_stream_overflow_seq extends soc_stream_base_seq;
    `uvm_object_utils(soc_stream_overflow_seq)

    localparam int FIFO_DEPTH       = 64;
    localparam int OVERFLOW_PUSHES  = FIFO_DEPTH + 1;  // 65 total

    function new(string name = "soc_stream_overflow_seq");
        super.new(name);
    endfunction

    task body();
        `uvm_info("STREAM_SEQ",
            $sformatf("TC_FIFO_OVF_19: pushing %0d samples into %0d-deep FIFO",
                       OVERFLOW_PUSHES, FIFO_DEPTH), UVM_MEDIUM)
        for (int i = 0; i < OVERFLOW_PUSHES; i++) begin
            push_sample(32'(i + 1));
            if (i == FIFO_DEPTH - 1)
                `uvm_info("STREAM_SEQ",
                    "TC_FIFO_OVF_19: FIFO should now be FULL; next push tests overflow", UVM_MEDIUM)
        end
        `uvm_info("STREAM_SEQ",
            "TC_FIFO_OVF_19: all pushes done; scoreboard should check OVF_STICKY flag", UVM_MEDIUM)
    endtask

endclass : soc_stream_overflow_seq

`endif // SOC_STREAM_SEQUENCES_SV
