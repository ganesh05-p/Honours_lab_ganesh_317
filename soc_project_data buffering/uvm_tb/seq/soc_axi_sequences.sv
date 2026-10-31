// =============================================================================
// File        : soc_axi_sequences.sv
// Description : Base and directed AXI4 sequences derived from CSV test plan.
//
// Sequences provided:
//   soc_axi_base_seq        - base class with helper tasks
//   soc_axi_write32_seq     - single 32-bit write (used by most AXI TCs)
//   soc_axi_read32_seq      - single 32-bit read
//   soc_axi_write_read_seq  - write then read-back for TC_MEM_IMEM_03 / TC_MEM_DMEM_04
//   soc_axi_decerr_seq      - unmapped address read for TC_AXI_DEC_18
// =============================================================================

`ifndef SOC_AXI_SEQUENCES_SV
`define SOC_AXI_SEQUENCES_SV

// -----------------------------------------------------------------------------
// Base sequence — provides convenience tasks axi_write32 / axi_read32
// -----------------------------------------------------------------------------
class soc_axi_base_seq extends uvm_sequence #(soc_axi_seq_item);
    `uvm_object_utils(soc_axi_base_seq)

    function new(string name = "soc_axi_base_seq");
        super.new(name);
    endfunction

    // -------------------------------------------------------------------------
    // Write a single 32-bit word to addr; return BRESP in resp_o
    // -------------------------------------------------------------------------
    task axi_write32(input  logic [31:0] addr,
                     input  logic [31:0] data,
                     output logic [1:0]  resp_o);
        soc_axi_seq_item req;
        req = soc_axi_seq_item::type_id::create("req");
        start_item(req);
        if (!req.randomize() with {
            txn_type   == soc_axi_seq_item::AXI_WRITE;
            req.addr   == addr;
            req.data   == data;
            burst_len  == 8'h00;
            burst_size == 3'b010;
            burst_type == 2'b01;
            wstrb      == 4'hF;
        }) `uvm_fatal("RAND", "soc_axi_seq_item randomize failed")
        finish_item(req);
        resp_o = req.resp;
    endtask

    // -------------------------------------------------------------------------
    // Read a single 32-bit word from addr; return data in rdata_o and RRESP in resp_o
    // -------------------------------------------------------------------------
    task axi_read32(input  logic [31:0] addr,
                    output logic [31:0] rdata_o,
                    output logic [1:0]  resp_o);
        soc_axi_seq_item req;
        req = soc_axi_seq_item::type_id::create("req");
        start_item(req);
        if (!req.randomize() with {
            txn_type   == soc_axi_seq_item::AXI_READ;
            req.addr   == addr;
            burst_len  == 8'h00;
            burst_size == 3'b010;
            burst_type == 2'b01;
        }) `uvm_fatal("RAND", "soc_axi_seq_item randomize failed")
        finish_item(req);
        rdata_o = req.rdata;
        resp_o  = req.resp;
    endtask

    // Default body — override in derived sequences
    virtual task body();
    endtask

endclass : soc_axi_base_seq

// -----------------------------------------------------------------------------
// Single 32-bit write — TC_UART_REG_05, TC_TIMER_07, TC_GPIO_08,
//                        TC_DMA_CFG_12, TC_DMA_ABORT_20
// Usage: set fields before calling start(sequencer)
// -----------------------------------------------------------------------------
class soc_axi_write32_seq extends soc_axi_base_seq;
    `uvm_object_utils(soc_axi_write32_seq)

    logic [31:0] target_addr  = 32'h0000_0000;
    logic [31:0] write_data   = 32'hDEAD_BEEF;
    logic [1:0]  got_resp;

    function new(string name = "soc_axi_write32_seq");
        super.new(name);
    endfunction

    task body();
        axi_write32(target_addr, write_data, got_resp);
        `uvm_info("AXI_SEQ",
            $sformatf("WRITE32 addr=0x%08h data=0x%08h bresp=0x%0h",
                      target_addr, write_data, got_resp), UVM_MEDIUM)
        if (got_resp != 2'b00)
            `uvm_error("AXI_SEQ", "WRITE returned non-OKAY response")
    endtask

endclass : soc_axi_write32_seq

// -----------------------------------------------------------------------------
// Single 32-bit read — TC_FIFO_SW_POP_10, TC_PLIC_15
// -----------------------------------------------------------------------------
class soc_axi_read32_seq extends soc_axi_base_seq;
    `uvm_object_utils(soc_axi_read32_seq)

    logic [31:0] target_addr  = 32'h0000_0000;
    logic [31:0] got_rdata;
    logic [1:0]  got_resp;

    function new(string name = "soc_axi_read32_seq");
        super.new(name);
    endfunction

    task body();
        axi_read32(target_addr, got_rdata, got_resp);
        `uvm_info("AXI_SEQ",
            $sformatf("READ32 addr=0x%08h rdata=0x%08h rresp=0x%0h",
                      target_addr, got_rdata, got_resp), UVM_MEDIUM)
        if (got_resp != 2'b00)
            `uvm_error("AXI_SEQ", "READ returned non-OKAY response")
    endtask

endclass : soc_axi_read32_seq

// -----------------------------------------------------------------------------
// Write then Read-Back — TC_MEM_IMEM_03, TC_MEM_DMEM_04
// Writes test_pattern to target_addr, reads back, checks match.
// -----------------------------------------------------------------------------
class soc_axi_write_read_seq extends soc_axi_base_seq;
    `uvm_object_utils(soc_axi_write_read_seq)

    logic [31:0] target_addr   = 32'h0000_0000;
    logic [31:0] test_pattern  = 32'hA5A5_5A5A;
    logic [31:0] got_rdata;
    logic [1:0]  wr_resp;
    logic [1:0]  rd_resp;

    function new(string name = "soc_axi_write_read_seq");
        super.new(name);
    endfunction

    task body();
        // Write phase
        axi_write32(target_addr, test_pattern, wr_resp);
        if (wr_resp != 2'b00)
            `uvm_error("AXI_SEQ", $sformatf("Write to 0x%08h got BRESP=0x%0h (expected OKAY)",
                                             target_addr, wr_resp))
        // Read-back phase
        axi_read32(target_addr, got_rdata, rd_resp);
        if (rd_resp != 2'b00)
            `uvm_error("AXI_SEQ", $sformatf("Read from 0x%08h got RRESP=0x%0h (expected OKAY)",
                                              target_addr, rd_resp))
        // Data integrity check
        if (got_rdata !== test_pattern)
            `uvm_error("AXI_SEQ", $sformatf(
                "Data mismatch at 0x%08h: wrote 0x%08h, read 0x%08h",
                target_addr, test_pattern, got_rdata))
        else
            `uvm_info("AXI_SEQ", $sformatf(
                "PASS: addr=0x%08h data=0x%08h matches", target_addr, got_rdata), UVM_MEDIUM)
    endtask

endclass : soc_axi_write_read_seq

// -----------------------------------------------------------------------------
// Decode Error sequence — TC_AXI_DEC_18
// Issues a read to 0x8000_0000 and checks RRESP == DECERR (2'b11)
// -----------------------------------------------------------------------------
class soc_axi_decerr_seq extends soc_axi_base_seq;
    `uvm_object_utils(soc_axi_decerr_seq)

    // CSV TC_AXI_DEC_18: unmapped aperture
    localparam logic [31:0] UNMAPPED_ADDR = 32'h8000_0000;

    logic [31:0] got_rdata;
    logic [1:0]  got_resp;

    function new(string name = "soc_axi_decerr_seq");
        super.new(name);
    endfunction

    task body();
        axi_read32(UNMAPPED_ADDR, got_rdata, got_resp);
        `uvm_info("AXI_SEQ",
            $sformatf("DECERR seq: addr=0x%08h rresp=0x%0h", UNMAPPED_ADDR, got_resp), UVM_MEDIUM)
        if (got_resp !== 2'b11)
            `uvm_error("AXI_SEQ", $sformatf(
                "TC_AXI_DEC_18 FAIL: expected RRESP=2'b11 (DECERR), got 0x%0h", got_resp))
        else
            `uvm_info("AXI_SEQ", "TC_AXI_DEC_18 PASS: DECERR received as expected", UVM_MEDIUM)
    endtask

endclass : soc_axi_decerr_seq

`endif // SOC_AXI_SEQUENCES_SV
