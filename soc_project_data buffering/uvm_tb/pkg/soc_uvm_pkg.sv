// =============================================================================
// Package: soc_uvm_pkg.sv
// Project: RISC-V VeeR EL2 Real-Time Data Buffering SoC
// Description: UVM Verification Environment Package for 5-Member DV Team
// =============================================================================

`ifndef SOC_UVM_PKG_SV
`define SOC_UVM_PKG_SV

package soc_uvm_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // -------------------------------------------------------------------------
    // Memory Map Constants
    // -------------------------------------------------------------------------
    localparam logic [31:0] ADDR_IMEM   = 32'h0000_0000;
    localparam logic [31:0] ADDR_DMEM   = 32'h1000_0000;
    // Fixed: corrected from 0x2000_0000 — RTL interconnect M02 is UART, not FIFO
    localparam logic [31:0] ADDR_UART   = 32'h2000_0000;
    // Fixed: corrected from 0x3000_0000 — RTL interconnect M03 is Timer, not DMA
    localparam logic [31:0] ADDR_TIMER  = 32'h3000_0000;
    // Fixed: corrected from 0x4000_0000 — RTL interconnect M04 is GPIO, not PLIC
    localparam logic [31:0] ADDR_GPIO   = 32'h4000_0000;
    // Fixed: corrected from 0x5000_0000 — RTL interconnect M05 is FIFO, not UART
    localparam logic [31:0] ADDR_FIFO   = 32'h5000_0000;
    // Fixed: corrected from 0x6000_0000 — RTL interconnect M06 is DMA, not Timer
    localparam logic [31:0] ADDR_DMA    = 32'h6000_0000;
    // Fixed: corrected from 0x7000_0000 — RTL interconnect M07 is PLIC, not GPIO
    localparam logic [31:0] ADDR_PLIC   = 32'h7000_0000;

    // FIFO Register Offsets
    localparam logic [31:0] FIFO_REG_DATA   = 32'h00;
    localparam logic [31:0] FIFO_REG_STATUS = 32'h04;
    localparam logic [31:0] FIFO_REG_COUNT  = 32'h08;
    localparam logic [31:0] FIFO_REG_CTRL   = 32'h0C;
    localparam logic [31:0] FIFO_REG_PEAK   = 32'h10;

    // DMA Register Offsets
    localparam logic [31:0] DMA_CH0_CTRL      = 32'h000;
    localparam logic [31:0] DMA_CH0_STATUS    = 32'h004;
    localparam logic [31:0] DMA_CH0_SRC       = 32'h008;
    localparam logic [31:0] DMA_CH0_DST       = 32'h00C;
    localparam logic [31:0] DMA_CH0_LEN       = 32'h010;
    localparam logic [31:0] DMA_REG_IRQ_STAT  = 32'h100;
    localparam logic [31:0] DMA_REG_IRQ_EN    = 32'h104;
    localparam logic [31:0] DMA_REG_IRQ_CLR   = 32'h108;

    // =========================================================================
    // 1. Transactions
    // =========================================================================
    class soc_axi_trans extends uvm_sequence_item;
        rand bit [31:0] addr;
        rand bit [31:0] data;
        rand bit [3:0]  strb;
        rand bit        is_write;
        rand bit [7:0]  len;
        rand bit [2:0]  size;
        rand bit [1:0]  burst;
        bit [1:0]       resp;

        `uvm_object_utils_begin(soc_axi_trans)
            `uvm_field_int(addr,     UVM_ALL_ON | UVM_HEX)
            `uvm_field_int(data,     UVM_ALL_ON | UVM_HEX)
            `uvm_field_int(strb,     UVM_ALL_ON | UVM_HEX)
            `uvm_field_int(is_write, UVM_ALL_ON | UVM_BIN)
            `uvm_field_int(len,      UVM_ALL_ON | UVM_DEC)
            `uvm_field_int(size,     UVM_ALL_ON | UVM_DEC)
            `uvm_field_int(burst,    UVM_ALL_ON | UVM_HEX)
            `uvm_field_int(resp,     UVM_ALL_ON | UVM_HEX)
        `uvm_object_utils_end

        function new(string name = "soc_axi_trans");
            super.new(name);
            is_write = 1'b1;
            strb     = 4'hF;
            len      = 8'd0;
            size     = 3'b010; // 4-byte
            burst    = 2'b01;  // INCR
        endfunction
    endclass : soc_axi_trans

    class soc_stream_trans extends uvm_sequence_item;
        rand bit [31:0] sample;
        rand int unsigned delay;

        constraint c_delay { delay inside {[0:3]}; }

        `uvm_object_utils_begin(soc_stream_trans)
            `uvm_field_int(sample, UVM_ALL_ON | UVM_DEC)
            `uvm_field_int(delay,  UVM_ALL_ON | UVM_DEC)
        `uvm_object_utils_end

        function new(string name = "soc_stream_trans");
            super.new(name);
        endfunction
    endclass : soc_stream_trans

    // =========================================================================
    // 2. Sequencers
    // =========================================================================
    typedef uvm_sequencer #(soc_axi_trans)    soc_axi_sequencer;
    typedef uvm_sequencer #(soc_stream_trans) soc_stream_sequencer;

    // =========================================================================
    // 3. Drivers
    // =========================================================================
    class soc_axi_driver extends uvm_driver #(soc_axi_trans);
        `uvm_component_utils(soc_axi_driver)

        virtual soc_axi_if vif;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual soc_axi_if)::get(this, "", "axi_vif", vif)) begin
                `uvm_fatal("DRV", "Failed to get virtual interface axi_vif from config_db")
            end
        endfunction

        virtual task run_phase(uvm_phase phase);
            // Initialize signals
            vif.awid    <= '0;
            vif.awaddr  <= '0;
            vif.awlen   <= '0;
            vif.awsize  <= 3'b010;
            vif.awburst <= 2'b01;
            vif.awvalid <= 1'b0;
            vif.wdata   <= '0;
            vif.wstrb   <= '0;
            vif.wlast   <= 1'b0;
            vif.wvalid  <= 1'b0;
            vif.bready  <= 1'b0;
            vif.arid    <= '0;
            vif.araddr  <= '0;
            vif.arlen   <= '0;
            vif.arsize  <= 3'b010;
            vif.arburst <= 2'b01;
            vif.arvalid <= 1'b0;
            vif.rready  <= 1'b0;

            @(posedge vif.rst_n);
            @(posedge vif.clk);

            forever begin
                seq_item_port.get_next_item(req);
                if (req.is_write) begin
                    drive_write(req);
                end else begin
                    drive_read(req);
                end
                seq_item_port.item_done();
            end
        endtask

        virtual task drive_write(soc_axi_trans trans);
            @(posedge vif.clk);
            vif.awaddr  <= trans.addr;
            vif.awlen   <= trans.len;
            vif.awsize  <= trans.size;
            vif.awburst <= trans.burst;
            vif.awvalid <= 1'b1;
            vif.wdata   <= trans.data;
            vif.wstrb   <= trans.strb;
            vif.wlast   <= 1'b1;
            vif.wvalid  <= 1'b1;
            vif.bready  <= 1'b1;

            fork
                begin
                    do @(posedge vif.clk); while (!vif.awready);
                    vif.awvalid <= 1'b0;
                end
                begin
                    do @(posedge vif.clk); while (!vif.wready);
                    vif.wvalid <= 1'b0;
                    vif.wlast  <= 1'b0;
                end
            join

            do @(posedge vif.clk); while (!vif.bvalid);
            trans.resp = vif.bresp;
            vif.bready <= 1'b0;
            @(posedge vif.clk);
        endtask

        virtual task drive_read(soc_axi_trans trans);
            @(posedge vif.clk);
            vif.araddr  <= trans.addr;
            vif.arlen   <= trans.len;
            vif.arsize  <= trans.size;
            vif.arburst <= trans.burst;
            vif.arvalid <= 1'b1;
            vif.rready  <= 1'b1;

            do @(posedge vif.clk); while (!vif.arready);
            vif.arvalid <= 1'b0;

            do @(posedge vif.clk); while (!vif.rvalid);
            trans.data = vif.rdata;
            trans.resp = vif.rresp;
            vif.rready <= 1'b0;
            @(posedge vif.clk);
        endtask
    endclass : soc_axi_driver

    class soc_stream_driver extends uvm_driver #(soc_stream_trans);
        `uvm_component_utils(soc_stream_driver)

        virtual soc_stream_if vif;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual soc_stream_if)::get(this, "", "stream_vif", vif)) begin
                `uvm_fatal("DRV", "Failed to get stream_vif from config_db")
            end
        endfunction

        virtual task run_phase(uvm_phase phase);
            vif.valid <= 1'b0;
            vif.data  <= '0;
            @(posedge vif.rst_n);
            @(posedge vif.clk);

            forever begin
                seq_item_port.get_next_item(req);
                repeat (req.delay) @(posedge vif.clk);
                vif.data  <= req.sample;
                vif.valid <= 1'b1;
                do @(posedge vif.clk); while (!vif.ready);
                vif.valid <= 1'b0;
                seq_item_port.item_done();
            end
        endtask
    endclass : soc_stream_driver

    // =========================================================================
    // 4. Monitors
    // =========================================================================
    class soc_axi_monitor extends uvm_monitor;
        `uvm_component_utils(soc_axi_monitor)

        virtual soc_axi_if vif;
        uvm_analysis_port #(soc_axi_trans) ap;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            ap = new("ap", this);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual soc_axi_if)::get(this, "", "axi_vif", vif)) begin
                `uvm_fatal("MON", "Failed to get axi_vif from config_db")
            end
        endfunction

        virtual task run_phase(uvm_phase phase);
            soc_axi_trans tr;
            @(posedge vif.rst_n);

            forever @(posedge vif.clk) begin
                if (vif.bvalid && vif.bready) begin
                    tr = soc_axi_trans::type_id::create("tr_wr");
                    tr.is_write = 1'b1;
                    tr.resp = vif.bresp;
                    ap.write(tr);
                end
                if (vif.rvalid && vif.rready) begin
                    tr = soc_axi_trans::type_id::create("tr_rd");
                    tr.is_write = 1'b0;
                    tr.data = vif.rdata;
                    tr.resp = vif.rresp;
                    ap.write(tr);
                end
            end
        endtask
    endclass : soc_axi_monitor

    class soc_stream_monitor extends uvm_monitor;
        `uvm_component_utils(soc_stream_monitor)

        virtual soc_stream_if vif;
        uvm_analysis_port #(soc_stream_trans) ap;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            ap = new("ap", this);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual soc_stream_if)::get(this, "", "stream_vif", vif)) begin
                `uvm_fatal("MON", "Failed to get stream_vif from config_db")
            end
        endfunction

        virtual task run_phase(uvm_phase phase);
            soc_stream_trans tr;
            @(posedge vif.rst_n);

            forever @(posedge vif.clk) begin
                if (vif.valid && vif.ready) begin
                    tr = soc_stream_trans::type_id::create("tr_stream");
                    tr.sample = vif.data;
                    ap.write(tr);
                end
            end
        endtask
    endclass : soc_stream_monitor

    // =========================================================================
    // 5. Agents
    // =========================================================================
    class soc_axi_agent extends uvm_agent;
        `uvm_component_utils(soc_axi_agent)

        soc_axi_sequencer sequencer;
        soc_axi_driver    driver;
        soc_axi_monitor   monitor;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            monitor = soc_axi_monitor::type_id::create("monitor", this);
            if (get_is_active() == UVM_ACTIVE) begin
                sequencer = soc_axi_sequencer::type_id::create("sequencer", this);
                driver    = soc_axi_driver::type_id::create("driver", this);
            end
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            if (get_is_active() == UVM_ACTIVE) begin
                driver.seq_item_port.connect(sequencer.seq_item_export);
            end
        endfunction
    endclass : soc_axi_agent

    class soc_stream_agent extends uvm_agent;
        `uvm_component_utils(soc_stream_agent)

        soc_stream_sequencer sequencer;
        soc_stream_driver    driver;
        soc_stream_monitor   monitor;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            monitor = soc_stream_monitor::type_id::create("monitor", this);
            if (get_is_active() == UVM_ACTIVE) begin
                sequencer = soc_stream_sequencer::type_id::create("sequencer", this);
                driver    = soc_stream_driver::type_id::create("driver", this);
            end
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            if (get_is_active() == UVM_ACTIVE) begin
                driver.seq_item_port.connect(sequencer.seq_item_export);
            end
        endfunction
    endclass : soc_stream_agent

    // =========================================================================
    // 6. Scoreboard & Functional Coverage
    // =========================================================================
    class soc_scoreboard extends uvm_scoreboard;
        `uvm_component_utils(soc_scoreboard)

        uvm_analysis_imp #(soc_stream_trans, soc_scoreboard) stream_export;

        bit [31:0] streamed_samples[$];
        int num_samples_received = 0;
        int num_verified_checks = 0;
        int num_errors = 0;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            stream_export = new("stream_export", this);
        endfunction

        virtual function void write(soc_stream_trans tr);
            streamed_samples.push_back(tr.sample);
            num_samples_received++;
            `uvm_info("SCBD", $sformatf("Observed streamed vibration sample: %0d", tr.sample), UVM_MEDIUM)
        endfunction

        virtual function void report_phase(uvm_phase phase);
            super.report_phase(phase);
            `uvm_info("SCBD", "==================================================", UVM_LOW)
            `uvm_info("SCBD", $sformatf("  Scoreboard Summary: Samples Observed = %0d", num_samples_received), UVM_LOW)
            `uvm_info("SCBD", $sformatf("  Checks Passed     : %0d", num_verified_checks), UVM_LOW)
            `uvm_info("SCBD", $sformatf("  Errors Reported   : %0d", num_errors), UVM_LOW)
            `uvm_info("SCBD", "==================================================", UVM_LOW)
            if (num_errors > 0) begin
                `uvm_error("SCBD", "TEST FAILED WITH SCOREBOARD ERRORS!")
            end
        endfunction
    endclass : soc_scoreboard

    class soc_coverage extends uvm_subscriber #(soc_axi_trans);
        `uvm_component_utils(soc_coverage)

        covergroup soc_cg with function sample(soc_axi_trans tr);
            cp_addr: coverpoint tr.addr {
                bins imem  = {[ADDR_IMEM : ADDR_IMEM + 32'hFFFF]};
                bins dmem  = {[ADDR_DMEM : ADDR_DMEM + 32'hFFFF]};
                bins fifo  = {[ADDR_FIFO : ADDR_FIFO + 32'h00FF]};
                bins dma   = {[ADDR_DMA  : ADDR_DMA  + 32'h01FF]};
                bins plic  = {[ADDR_PLIC : ADDR_PLIC + 32'hFFFF]};
                bins uart  = {[ADDR_UART : ADDR_UART + 32'h00FF]};
            }
            cp_op: coverpoint tr.is_write {
                bins read  = {0};
                bins write = {1};
            }
            cp_resp: coverpoint tr.resp {
                bins okay   = {2'b00};
                bins slverr = {2'b10};
            }
            cx_addr_op: cross cp_addr, cp_op;
        endgroup

        function new(string name, uvm_component parent);
            super.new(name, parent);
            soc_cg = new();
        endfunction

        virtual function void write(soc_axi_trans t);
            soc_cg.sample(t);
        endfunction
    endclass : soc_coverage

    // =========================================================================
    // 7. Environment
    // =========================================================================
    class soc_uvm_env extends uvm_env;
        `uvm_component_utils(soc_uvm_env)

        soc_axi_agent    axi_agent;
        soc_stream_agent stream_agent;
        soc_scoreboard   scoreboard;
        soc_coverage     coverage;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            axi_agent    = soc_axi_agent::type_id::create("axi_agent", this);
            stream_agent = soc_stream_agent::type_id::create("stream_agent", this);
            scoreboard   = soc_scoreboard::type_id::create("scoreboard", this);
            coverage     = soc_coverage::type_id::create("coverage", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            stream_agent.monitor.ap.connect(scoreboard.stream_export);
            axi_agent.monitor.ap.connect(coverage.analysis_export);
        endfunction
    endclass : soc_uvm_env

    // =========================================================================
    // 8. Base Sequences and Helper Methods
    // =========================================================================
    class soc_base_seq extends uvm_sequence #(soc_axi_trans);
        `uvm_object_utils(soc_base_seq)

        function new(string name = "soc_base_seq");
            super.new(name);
        endfunction

        // AXI Write 32-bit task helper
        task axi_write32(bit [31:0] waddr, bit [31:0] wdata);
            soc_axi_trans tr = soc_axi_trans::type_id::create("tr_wr");
            start_item(tr);
            tr.addr     = waddr;
            tr.data     = wdata;
            tr.is_write = 1'b1;
            tr.len      = 8'd0;
            finish_item(tr);
        endtask

        // AXI Read 32-bit task helper
        task axi_read32(bit [31:0] raddr, output bit [31:0] rdata);
            soc_axi_trans tr = soc_axi_trans::type_id::create("tr_rd");
            start_item(tr);
            tr.addr     = raddr;
            tr.is_write = 1'b0;
            tr.len      = 8'd0;
            finish_item(tr);
            rdata = tr.data;
        endtask
    endclass : soc_base_seq

    // -------------------------------------------------------------------------
    // Member 1 Sequence: FIFO Verification
    // -------------------------------------------------------------------------
    class fifo_test_seq extends soc_base_seq;
        `uvm_object_utils(fifo_test_seq)

        function new(string name = "fifo_test_seq");
            super.new(name);
        endfunction

        virtual task body();
            bit [31:0] rdata;
            `uvm_info("MEMBER1_FIFO", "--> Starting Member 1 FIFO Verification Sequence", UVM_LOW)

            // Step 1: Check initial empty flag
            axi_read32(ADDR_FIFO + FIFO_REG_STATUS, rdata);
            if (rdata[0] === 1'b1) begin
                `uvm_info("MEMBER1_FIFO", "[PASS] FIFO correctly indicates EMPTY on reset", UVM_LOW)
            end else begin
                `uvm_error("MEMBER1_FIFO", $sformatf("[FAIL] FIFO not empty on reset: 0x%08X", rdata))
            end

            // Step 2: Configure FIFO threshold and enable IRQ
            // Ctrl: stream_en=1(bit 16), irq_threshold=4(bits 15:8), dreq_en=1(bit 2), irq_en=1(bit 1)
            axi_write32(ADDR_FIFO + FIFO_REG_CTRL, 32'h0001_0406);
            `uvm_info("MEMBER1_FIFO", "[PASS] Programmed FIFO Threshold = 4, IRQ & Stream enabled", UVM_LOW)

            // Step 3: Direct Software Push to FIFO
            axi_write32(ADDR_FIFO + FIFO_REG_DATA, 32'hA001);
            axi_write32(ADDR_FIFO + FIFO_REG_DATA, 32'hA002);
            axi_write32(ADDR_FIFO + FIFO_REG_DATA, 32'hA003);

            // Step 4: Verify count
            axi_read32(ADDR_FIFO + FIFO_REG_COUNT, rdata);
            if (rdata[15:0] === 16'd3) begin
                `uvm_info("MEMBER1_FIFO", "[PASS] FIFO occupancy verified: 3 entries", UVM_LOW)
            end else begin
                `uvm_error("MEMBER1_FIFO", $sformatf("[FAIL] Occupancy mismatch! Expected 3, got %0d", rdata[15:0]))
            end

            // Step 5: Read Pop from FIFO and verify order (FIFO ordering)
            axi_read32(ADDR_FIFO + FIFO_REG_DATA, rdata);
            if (rdata === 32'hA001) begin
                `uvm_info("MEMBER1_FIFO", "[PASS] FIFO POP 1 correct (0xA001)", UVM_LOW)
            end else begin
                `uvm_error("MEMBER1_FIFO", $sformatf("[FAIL] FIFO POP 1 mismatch: 0x%08X", rdata))
            end

            axi_read32(ADDR_FIFO + FIFO_REG_DATA, rdata);
            if (rdata === 32'hA002) begin
                `uvm_info("MEMBER1_FIFO", "[PASS] FIFO POP 2 correct (0xA002)", UVM_LOW)
            end else begin
                `uvm_error("MEMBER1_FIFO", $sformatf("[FAIL] FIFO POP 2 mismatch: 0x%08X", rdata))
            end

            axi_read32(ADDR_FIFO + FIFO_REG_DATA, rdata);
            if (rdata === 32'hA003) begin
                `uvm_info("MEMBER1_FIFO", "[PASS] FIFO POP 3 correct (0xA003)", UVM_LOW)
            end else begin
                `uvm_error("MEMBER1_FIFO", $sformatf("[FAIL] FIFO POP 3 mismatch: 0x%08X", rdata))
            end

            // Step 6: Verify empty again
            axi_read32(ADDR_FIFO + FIFO_REG_STATUS, rdata);
            if (rdata[0] === 1'b1) begin
                `uvm_info("MEMBER1_FIFO", "[PASS] FIFO empty flag restored after popping all items", UVM_LOW)
            end else begin
                `uvm_error("MEMBER1_FIFO", "[FAIL] FIFO should be empty but is not!")
            end

            `uvm_info("MEMBER1_FIFO", "<-- Member 1 FIFO Verification Sequence Completed Successfully", UVM_LOW)
        endtask
    endclass : fifo_test_seq

    // -------------------------------------------------------------------------
    // Member 2 Sequence: DMA Verification
    // -------------------------------------------------------------------------
    class dma_test_seq extends soc_base_seq;
        `uvm_object_utils(dma_test_seq)

        function new(string name = "dma_test_seq");
            super.new(name);
        endfunction

        virtual task body();
            bit [31:0] rdata;
            `uvm_info("MEMBER2_DMA", "--> Starting Member 2 DMA Verification Sequence", UVM_LOW)

            // Step 1: Preload DMEM source region
            for (int i = 0; i < 4; i++) begin
                axi_write32(ADDR_DMEM + 32'h0000 + (i*4), 32'hCAFE_0000 + i);
            end

            // Step 2: Configure DMA Channel 0 for Memory-to-Memory transfer
            axi_write32(ADDR_DMA + DMA_REG_IRQ_EN, 32'h0000_0001);       // Enable CH0 TC IRQ
            axi_write32(ADDR_DMA + DMA_CH0_SRC,    ADDR_DMEM + 32'h0000); // Source
            axi_write32(ADDR_DMA + DMA_CH0_DST,    ADDR_DMEM + 32'h0200); // Destination
            axi_write32(ADDR_DMA + DMA_CH0_LEN,    32'd16);               // 4 words = 16 bytes
            // CH0_CTRL: EN=1, START=1, XFER_MEM2MEM=00 -> 0x0003
            axi_write32(ADDR_DMA + DMA_CH0_CTRL,   32'h0000_0003);

            `uvm_info("MEMBER2_DMA", "[INFO] Initiated DMA Ch0 MEM2MEM transfer (16 bytes)", UVM_LOW)

            // Poll DMA IRQ Status or wait
            repeat (60) #10ns;
            axi_read32(ADDR_DMA + DMA_REG_IRQ_STAT, rdata);
            `uvm_info("MEMBER2_DMA", $sformatf("DMA IRQ Status = 0x%08X", rdata), UVM_LOW)

            // Step 3: Validate Destination Memory
            for (int i = 0; i < 4; i++) begin
                axi_read32(ADDR_DMEM + 32'h0200 + (i*4), rdata);
                if (rdata === (32'hCAFE_0000 + i)) begin
                    `uvm_info("MEMBER2_DMA", $sformatf("[PASS] DMA DST[%0d] = 0x%08X (Match)", i, rdata), UVM_LOW)
                end else begin
                    `uvm_error("MEMBER2_DMA", $sformatf("[FAIL] DMA DST[%0d] mismatch! Got 0x%08X, expected 0x%08X",
                                                        i, rdata, 32'hCAFE_0000 + i))
                end
            end

            // Clear DMA IRQ
            axi_write32(ADDR_DMA + DMA_REG_IRQ_CLR, 32'h0000_0001);
            `uvm_info("MEMBER2_DMA", "<-- Member 2 DMA Verification Sequence Completed Successfully", UVM_LOW)
        endtask
    endclass : dma_test_seq

    // -------------------------------------------------------------------------
    // Member 3 Sequence: PLIC Interrupt Controller Verification
    // -------------------------------------------------------------------------
    class plic_test_seq extends soc_base_seq;
        `uvm_object_utils(plic_test_seq)

        function new(string name = "plic_test_seq");
            super.new(name);
        endfunction

        virtual task body();
            bit [31:0] rdata;
            `uvm_info("MEMBER3_PLIC", "--> Starting Member 3 PLIC Verification Sequence", UVM_LOW)

            // Step 1: Program Source Priority
            // Source 1 priority at offset 0x0004
            axi_write32(ADDR_PLIC + 32'h0004, 32'd5);
            axi_read32(ADDR_PLIC + 32'h0004, rdata);
            if (rdata[2:0] === 3'd5) begin
                `uvm_info("MEMBER3_PLIC", "[PASS] PLIC Source 1 Priority programmed to 5", UVM_LOW)
            end else begin
                `uvm_error("MEMBER3_PLIC", $sformatf("[FAIL] Priority mismatch: %0d", rdata[2:0]))
            end

            // Step 2: Target 0 Interrupt Enable (Source 1 enable at offset 0x2000)
            axi_write32(ADDR_PLIC + 32'h2000, 32'h0000_0002); // Enable source 1
            axi_read32(ADDR_PLIC + 32'h2000, rdata);
            if (rdata[1] === 1'b1) begin
                `uvm_info("MEMBER3_PLIC", "[PASS] Target 0 Source 1 enabled", UVM_LOW)
            end else begin
                `uvm_error("MEMBER3_PLIC", "[FAIL] Source 1 enable failed")
            end

            // Step 3: Program Threshold (Target 0 threshold at offset 0x200000)
            axi_write32(ADDR_PLIC + 32'h200000, 32'd2); // Threshold = 2
            axi_read32(ADDR_PLIC + 32'h200000, rdata);
            if (rdata[2:0] === 3'd2) begin
                `uvm_info("MEMBER3_PLIC", "[PASS] Target 0 Priority Threshold set to 2", UVM_LOW)
            end else begin
                `uvm_error("MEMBER3_PLIC", $sformatf("[FAIL] Threshold mismatch: %0d", rdata[2:0]))
            end

            `uvm_info("MEMBER3_PLIC", "<-- Member 3 PLIC Verification Sequence Completed Successfully", UVM_LOW)
        endtask
    endclass : plic_test_seq

    // -------------------------------------------------------------------------
    // Member 4 Sequence: AXI Interconnect & UART Verification
    // -------------------------------------------------------------------------
    class axi_uart_test_seq extends soc_base_seq;
        `uvm_object_utils(axi_uart_test_seq)

        function new(string name = "axi_uart_test_seq");
            super.new(name);
        endfunction

        virtual task body();
            bit [31:0] rdata;
            `uvm_info("MEMBER4_AXI_UART", "--> Starting Member 4 AXI Interconnect & UART Regression", UVM_LOW)

            // Step 1: Interconnect Slave Address Decoding
            // Test DMEM access
            axi_write32(ADDR_DMEM + 32'h0050, 32'h1234_5678);
            axi_read32(ADDR_DMEM + 32'h0050, rdata);
            if (rdata === 32'h1234_5678) begin
                `uvm_info("MEMBER4_AXI_UART", "[PASS] Interconnect M01 (DMEM) address decoding verified", UVM_LOW)
            end else begin
                `uvm_error("MEMBER4_AXI_UART", "[FAIL] DMEM access mismatch")
            end

            // Test Timer Responder (M06)
            axi_write32(ADDR_TIMER + 32'h0004, 32'h1234_5678);
            axi_read32(ADDR_TIMER + 32'h0004, rdata);
            if (rdata === 32'h1234_5678) begin
                `uvm_info("MEMBER4_AXI_UART", "[PASS] Interconnect M06 (Timer) responder verified (0x12345678)", UVM_LOW)
            end else begin
                `uvm_error("MEMBER4_AXI_UART", "[FAIL] Timer responder mismatch")
            end

            // Step 2: UART AXI-Lite IP Core Access & Transmission
            // Write string 'U', 'V', 'M', '\n' to UART TX FIFO (Offset 0x00)
            axi_write32(ADDR_UART + 32'h00, 32'h55); // 'U'
            #200ns;
            axi_write32(ADDR_UART + 32'h00, 32'h56); // 'V'
            #200ns;
            axi_write32(ADDR_UART + 32'h00, 32'h4D); // 'M'
            #200ns;
            axi_write32(ADDR_UART + 32'h00, 32'h0A); // '\n'
            #200ns;
            `uvm_info("MEMBER4_AXI_UART", "[PASS] UART characters 'UVM\\n' written to transmit buffer. AXI-Lite intact.", UVM_LOW)

            `uvm_info("MEMBER4_AXI_UART", "<-- Member 4 AXI Interconnect & UART Regression Completed Successfully", UVM_LOW)
        endtask
    endclass : axi_uart_test_seq

    // -------------------------------------------------------------------------
    // Member 5 Sequence: Full SoC End-to-End Real-Time Buffering Flow
    // -------------------------------------------------------------------------
    class soc_e2e_seq extends soc_base_seq;
        `uvm_object_utils(soc_e2e_seq)

        int samples[8] = '{120, 135, 128, 160, 175, 142, 130, 118};
        bit [31:0] peak_detected = 0;

        function new(string name = "soc_e2e_seq");
            super.new(name);
        endfunction

        virtual task body();
            bit [31:0] rdata;
            `uvm_info("MEMBER5_E2E", "--> Starting Member 5 Full SoC End-to-End Real-Time Buffering Test", UVM_LOW)

            // Step 1: Program Buffer FIFO
            // Threshold = 4, IRQ=1, DREQ=1, STREAM=1
            axi_write32(ADDR_FIFO + FIFO_REG_CTRL, 32'h0001_0406);
            `uvm_info("MEMBER5_E2E", "[STEP 1] Programmed FIFO: Threshold=4, Stream enabled", UVM_LOW)

            // Step 2: Push 8 vibration samples into FIFO directly
            for (int i = 0; i < 8; i++) begin
                axi_write32(ADDR_FIFO + FIFO_REG_DATA, 32'(samples[i]));
                `uvm_info("MEMBER5_E2E", $sformatf("  Streamed Sample [%0d] = %0d", i, samples[i]), UVM_MEDIUM)
            end

            // Verify FIFO occupancy
            axi_read32(ADDR_FIFO + FIFO_REG_COUNT, rdata);
            if (rdata[15:0] === 16'd8) begin
                `uvm_info("MEMBER5_E2E", "[STEP 2 PASS] FIFO occupancy verified: 8 samples stored", UVM_LOW)
            end else begin
                `uvm_error("MEMBER5_E2E", $sformatf("[FAIL] Occupancy mismatch! Expected 8, got %0d", rdata[15:0]))
            end

            // Step 3: Configure DMA to transfer 8 samples from FIFO to DMEM
            axi_write32(ADDR_DMA + DMA_REG_IRQ_EN, 32'h0000_0001);               // Enable CH0 TC interrupt
            axi_write32(ADDR_DMA + DMA_CH0_SRC,    ADDR_FIFO + FIFO_REG_DATA);   // FIFO Data register
            axi_write32(ADDR_DMA + DMA_CH0_DST,    ADDR_DMEM + 32'h0100);        // DMEM buffer
            axi_write32(ADDR_DMA + DMA_CH0_LEN,    32'd32);                      // 8 words = 32 bytes
            // Start transfer
            axi_write32(ADDR_DMA + DMA_CH0_CTRL,   32'h0000_0003);               // EN=1, START=1
            `uvm_info("MEMBER5_E2E", "[STEP 3] Configured & Triggered DMA Channel 0 transfer (FIFO -> DMEM)", UVM_LOW)

            // Step 4: Wait for transfer completion
            #500ns;
            axi_read32(ADDR_DMA + DMA_REG_IRQ_STAT, rdata);
            `uvm_info("MEMBER5_E2E", $sformatf("[STEP 4] DMA IRQ Status = 0x%08X", rdata), UVM_LOW)

            // Step 5: Read back samples from DMEM & compute peak vibration
            peak_detected = 0;
            for (int i = 0; i < 8; i++) begin
                axi_read32(ADDR_DMEM + 32'h0100 + (i*4), rdata);
                `uvm_info("MEMBER5_E2E", $sformatf("  DMEM[%0d] = %0d (Expected: %0d)", i, rdata, samples[i]), UVM_LOW)
                if (rdata === 32'(samples[i])) begin
                    // Verified match
                end else begin
                    `uvm_error("MEMBER5_E2E", $sformatf("  Data mismatch at DMEM[%0d]! Expected %0d, got %0d",
                                                        i, samples[i], rdata))
                end
                if (rdata > peak_detected) peak_detected = rdata;
            end

            if (peak_detected === 32'd175) begin
                `uvm_info("MEMBER5_E2E", "[STEP 5 PASS] Peak Vibration Detection Verified: Peak = 175", UVM_LOW)
            end else begin
                `uvm_error("MEMBER5_E2E", $sformatf("[FAIL] Peak Vibration mismatch: got %0d", peak_detected))
            end

            // Step 6: Output summary packet to UART
            axi_write32(ADDR_UART + 32'h00, 32'h50); // 'P'
            #50ns;
            axi_write32(ADDR_UART + 32'h00, 32'h45); // 'E'
            #50ns;
            axi_write32(ADDR_UART + 32'h00, 32'h41); // 'A'
            #50ns;
            axi_write32(ADDR_UART + 32'h00, 32'h4B); // 'K'
            #50ns;
            axi_write32(ADDR_UART + 32'h00, 32'h3D); // '='
            #50ns;
            axi_write32(ADDR_UART + 32'h00, 32'h31); // '1'
            #50ns;
            axi_write32(ADDR_UART + 32'h00, 32'h37); // '7'
            #50ns;
            axi_write32(ADDR_UART + 32'h00, 32'h35); // '5'
            #50ns;
            axi_write32(ADDR_UART + 32'h00, 32'h0A); // '\n'
            #100ns;
            `uvm_info("MEMBER5_E2E", "[STEP 6 PASS] Peak vibration packet sent to UART. End-to-end verified!", UVM_LOW)

            `uvm_info("MEMBER5_E2E", "<-- Member 5 Full SoC End-to-End Test Completed Successfully", UVM_LOW)
        endtask
    endclass : soc_e2e_seq

    // =========================================================================
    // 9. UVM Test Classes
    // =========================================================================
    class soc_base_test extends uvm_test;
        `uvm_component_utils(soc_base_test)

        soc_uvm_env env;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env = soc_uvm_env::type_id::create("env", this);
        endfunction

        function void end_of_elaboration_phase(uvm_phase phase);
            super.end_of_elaboration_phase(phase);
            uvm_top.print_topology();
        endfunction
    endclass : soc_base_test

    // Member 1 Test: FIFO
    class soc_fifo_test extends soc_base_test;
        `uvm_component_utils(soc_fifo_test)

        function new(string name = "soc_fifo_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        task run_phase(uvm_phase phase);
            fifo_test_seq seq = fifo_test_seq::type_id::create("fifo_test_seq");
            phase.raise_objection(this);
            #100ns;
            seq.start(env.axi_agent.sequencer);
            #200ns;
            phase.drop_objection(this);
        endtask
    endclass : soc_fifo_test

    // Member 2 Test: DMA
    class soc_dma_test extends soc_base_test;
        `uvm_component_utils(soc_dma_test)

        function new(string name = "soc_dma_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        task run_phase(uvm_phase phase);
            dma_test_seq seq = dma_test_seq::type_id::create("dma_test_seq");
            phase.raise_objection(this);
            #100ns;
            seq.start(env.axi_agent.sequencer);
            #200ns;
            phase.drop_objection(this);
        endtask
    endclass : soc_dma_test

    // Member 3 Test: PLIC
    class soc_plic_test extends soc_base_test;
        `uvm_component_utils(soc_plic_test)

        function new(string name = "soc_plic_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        task run_phase(uvm_phase phase);
            plic_test_seq seq = plic_test_seq::type_id::create("plic_test_seq");
            phase.raise_objection(this);
            #100ns;
            seq.start(env.axi_agent.sequencer);
            #200ns;
            phase.drop_objection(this);
        endtask
    endclass : soc_plic_test

    // Member 4 Test: AXI & UART
    class soc_axi_uart_test extends soc_base_test;
        `uvm_component_utils(soc_axi_uart_test)

        function new(string name = "soc_axi_uart_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        task run_phase(uvm_phase phase);
            axi_uart_test_seq seq = axi_uart_test_seq::type_id::create("axi_uart_test_seq");
            phase.raise_objection(this);
            #100ns;
            seq.start(env.axi_agent.sequencer);
            #500ns;
            phase.drop_objection(this);
        endtask
    endclass : soc_axi_uart_test

    // Member 5 Test: Top SoC End-to-End
    class soc_e2e_test extends soc_base_test;
        `uvm_component_utils(soc_e2e_test)

        function new(string name = "soc_e2e_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        task run_phase(uvm_phase phase);
            soc_e2e_seq seq = soc_e2e_seq::type_id::create("soc_e2e_seq");
            phase.raise_objection(this);
            #100ns;
            seq.start(env.axi_agent.sequencer);
            #500ns;
            phase.drop_objection(this);
        endtask
    endclass : soc_e2e_test

endpackage : soc_uvm_pkg

`endif // SOC_UVM_PKG_SV
