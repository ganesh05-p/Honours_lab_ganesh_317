// =============================================================================
// File        : soc_axi_seq_item.sv
// Description : UVM Sequence Item for AXI4 Master Transactions
//               Covers single-beat and burst read/write transactions driven
//               on ext_s00_axi_* top-level port of soc_data_buffering_top.
//
// CSV Tests using this item:
//   TC_MEM_IMEM_03, TC_MEM_DMEM_04, TC_UART_REG_05, TC_TIMER_07,
//   TC_GPIO_08, TC_FIFO_SW_POP_10, TC_DMA_CFG_12, TC_DMA_XFER_13,
//   TC_PLIC_15, TC_AXI_ARB_16, TC_AXI_DEC_18, TC_DMA_ABORT_20
// =============================================================================

`ifndef SOC_AXI_SEQ_ITEM_SV
`define SOC_AXI_SEQ_ITEM_SV

class soc_axi_seq_item extends uvm_sequence_item;
    `uvm_object_utils_begin(soc_axi_seq_item)
        `uvm_field_enum   (axi_txn_type_e,  txn_type,  UVM_ALL_ON)
        `uvm_field_int    (addr,             UVM_ALL_ON)
        `uvm_field_int    (data,             UVM_ALL_ON)
        `uvm_field_int    (wstrb,            UVM_ALL_ON)
        `uvm_field_int    (burst_len,        UVM_ALL_ON)
        `uvm_field_int    (burst_size,       UVM_ALL_ON)
        `uvm_field_int    (burst_type,       UVM_ALL_ON)
        `uvm_field_int    (id,               UVM_ALL_ON)
        // Response (populated by driver after transaction)
        `uvm_field_int    (rdata,            UVM_ALL_ON)
        `uvm_field_int    (resp,             UVM_ALL_ON)
    `uvm_object_utils_end

    // -------------------------------------------------------------------------
    // Transaction type
    // -------------------------------------------------------------------------
    typedef enum logic { AXI_WRITE = 1'b0, AXI_READ = 1'b1 } axi_txn_type_e;

    // -------------------------------------------------------------------------
    // Stimulus fields
    // -------------------------------------------------------------------------
    rand axi_txn_type_e  txn_type;          // READ or WRITE
    rand logic [31:0]    addr;              // Target address
    rand logic [31:0]    data;              // Write data (single beat)
    rand logic [3:0]     wstrb;            // Write byte enables
    rand logic [7:0]     burst_len;        // AXI AWLEN/ARLEN (beats-1)
    rand logic [2:0]     burst_size;       // AXI AWSIZE/ARSIZE
    rand logic [1:0]     burst_type;       // FIXED=0, INCR=1, WRAP=2
    rand logic [7:0]     id;               // AXI ID

    // -------------------------------------------------------------------------
    // Response fields (set by driver after completion)
    // -------------------------------------------------------------------------
    logic [31:0]         rdata;            // Captured read data (single beat)
    logic [1:0]          resp;             // BRESP or RRESP

    // -------------------------------------------------------------------------
    // Constraints
    // -------------------------------------------------------------------------
    // Default: single-beat INCR write to a legal address
    constraint c_default_burst {
        burst_len  == 8'h00;   // single beat
        burst_size == 3'b010;  // 4 bytes
        burst_type == 2'b01;   // INCR
    }

    constraint c_wstrb_full { wstrb == 4'hF; }

    constraint c_addr_aligned {
        addr[1:0] == 2'b00;   // 32-bit aligned
    }

    function new(string name = "soc_axi_seq_item");
        super.new(name);
    endfunction

    function string convert2string();
        return $sformatf("[AXI %s] addr=0x%08h data=0x%08h resp=0x%0h id=%0d len=%0d",
                         txn_type.name(), addr, (txn_type == AXI_READ) ? rdata : data,
                         resp, id, burst_len);
    endfunction

endclass : soc_axi_seq_item

`endif // SOC_AXI_SEQ_ITEM_SV
