// =============================================================================
// File        : soc_axi_driver.sv
// Description : UVM Driver for AXI4 Master Agent
//               Drives ext_s00_axi_* port of soc_data_buffering_top.
//               Supports single-beat read/write (burst_len==0).
//               Burst support: extend drive_write / drive_read for burst_len>0.
// =============================================================================

`ifndef SOC_AXI_DRIVER_SV
`define SOC_AXI_DRIVER_SV

class soc_axi_driver extends uvm_driver #(soc_axi_seq_item);
    `uvm_component_utils(soc_axi_driver)

    // Virtual interface handle — set via config_db in the test
    virtual soc_axi_if vif;

    function new(string name = "soc_axi_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual soc_axi_if)::get(this, "", "soc_axi_vif", vif))
            `uvm_fatal("NO_VIF", "soc_axi_driver: soc_axi_vif not found in config_db")
    endfunction

    task run_phase(uvm_phase phase);
        soc_axi_seq_item req;
        // Drive all outputs to safe idle state
        idle_bus();
        forever begin
            seq_item_port.get_next_item(req);
            case (req.txn_type)
                soc_axi_seq_item::AXI_WRITE : drive_write(req);
                soc_axi_seq_item::AXI_READ  : drive_read(req);
                default: `uvm_error("DRV", "Unknown transaction type")
            endcase
            seq_item_port.item_done();
        end
    endtask

    // -------------------------------------------------------------------------
    // Idle: de-assert all valid signals
    // -------------------------------------------------------------------------
    task idle_bus();
        @(posedge vif.clk);
        vif.drv_cb.awvalid <= 1'b0;
        vif.drv_cb.wvalid  <= 1'b0;
        vif.drv_cb.bready  <= 1'b1;
        vif.drv_cb.arvalid <= 1'b0;
        vif.drv_cb.rready  <= 1'b1;
        vif.drv_cb.awid    <= '0;
        vif.drv_cb.awaddr  <= '0;
        vif.drv_cb.awlen   <= '0;
        vif.drv_cb.awsize  <= 3'b010;
        vif.drv_cb.awburst <= 2'b01;
        vif.drv_cb.wdata   <= '0;
        vif.drv_cb.wstrb   <= 4'hF;
        vif.drv_cb.wlast   <= 1'b0;
        vif.drv_cb.arid    <= '0;
        vif.drv_cb.araddr  <= '0;
        vif.drv_cb.arlen   <= '0;
        vif.drv_cb.arsize  <= 3'b010;
        vif.drv_cb.arburst <= 2'b01;
    endtask

    // -------------------------------------------------------------------------
    // Single-beat (and burst) AXI write
    // -------------------------------------------------------------------------
    task drive_write(soc_axi_seq_item req);
        // --- Write Address Channel ---
        @(vif.drv_cb);
        vif.drv_cb.awid    <= req.id;
        vif.drv_cb.awaddr  <= req.addr;
        vif.drv_cb.awlen   <= req.burst_len;
        vif.drv_cb.awsize  <= req.burst_size;
        vif.drv_cb.awburst <= req.burst_type;
        vif.drv_cb.awvalid <= 1'b1;
        // Wait for awready handshake
        do @(vif.drv_cb); while (!vif.drv_cb.awready);
        vif.drv_cb.awvalid <= 1'b0;

        // --- Write Data Channel (single beat only; burst_len == 0) ---
        vif.drv_cb.wdata  <= req.data;
        vif.drv_cb.wstrb  <= req.wstrb;
        vif.drv_cb.wlast  <= 1'b1;
        vif.drv_cb.wvalid <= 1'b1;
        do @(vif.drv_cb); while (!vif.drv_cb.wready);
        vif.drv_cb.wvalid <= 1'b0;
        vif.drv_cb.wlast  <= 1'b0;

        // --- Write Response Channel ---
        vif.drv_cb.bready <= 1'b1;
        do @(vif.drv_cb); while (!vif.drv_cb.bvalid);
        req.resp = vif.drv_cb.bresp;
        @(vif.drv_cb);
        vif.drv_cb.bready <= 1'b0;

        `uvm_info("AXI_DRV", req.convert2string(), UVM_HIGH)
    endtask

    // -------------------------------------------------------------------------
    // Single-beat (and burst) AXI read
    // -------------------------------------------------------------------------
    task drive_read(soc_axi_seq_item req);
        // --- Read Address Channel ---
        @(vif.drv_cb);
        vif.drv_cb.arid    <= req.id;
        vif.drv_cb.araddr  <= req.addr;
        vif.drv_cb.arlen   <= req.burst_len;
        vif.drv_cb.arsize  <= req.burst_size;
        vif.drv_cb.arburst <= req.burst_type;
        vif.drv_cb.arvalid <= 1'b1;
        do @(vif.drv_cb); while (!vif.drv_cb.arready);
        vif.drv_cb.arvalid <= 1'b0;

        // --- Read Data Channel ---
        vif.drv_cb.rready <= 1'b1;
        do @(vif.drv_cb); while (!vif.drv_cb.rvalid);
        req.rdata = vif.drv_cb.rdata;
        req.resp  = vif.drv_cb.rresp;
        @(vif.drv_cb);
        vif.drv_cb.rready <= 1'b0;

        `uvm_info("AXI_DRV", req.convert2string(), UVM_HIGH)
    endtask

endclass : soc_axi_driver

`endif // SOC_AXI_DRIVER_SV
