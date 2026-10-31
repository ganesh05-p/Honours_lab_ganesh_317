// =============================================================================
// File        : soc_directed_tests.sv
// Description : Directed UVM tests derived from CSV test plan.
//               One class per CSV test case that requires UVM VIP action.
//
// Test class           | CSV ID          | Interface(s) Used
// ---------------------|-----------------|----------------------------------
// soc_mem_imem_test    | TC_MEM_IMEM_03  | AXI4 (write+read 0x0000_0000)
// soc_mem_dmem_test    | TC_MEM_DMEM_04  | AXI4 (write+read 0x1000_0100)
// soc_uart_reg_test    | TC_UART_REG_05  | AXI4 (write UART LCR 0x2000_000C)
// soc_uart_tx_test     | TC_UART_TX_06   | AXI4 + IRQ/UART observation
// soc_timer_test       | TC_TIMER_07     | AXI4 (write timer regs 0x3000_0000)
// soc_gpio_test        | TC_GPIO_08      | AXI4 (write GPIO 0x4000_0000)
// soc_fifo_stream_test | TC_FIFO_STREAM_09| Stream (push 8 samples)
// soc_fifo_pop_test    | TC_FIFO_SW_POP_10| AXI4 (read 0x5000_0000)
// soc_fifo_irq_test    | TC_FIFO_IRQ_11  | Stream + AXI4 + IRQ obs
// soc_dma_cfg_test     | TC_DMA_CFG_12   | AXI4 (write DMA regs 0x6000_0000)
// soc_dma_irq_test     | TC_DMA_IRQ_14   | AXI4 + IRQ obs
// soc_plic_test_tc15   | TC_PLIC_15      | AXI4 (PLIC 0x7000_0000)
// soc_axi_arb_test     | TC_AXI_ARB_16   | AXI4
// soc_e2e_test_tc17    | TC_E2E_DATA_17  | Stream + AXI4 + IRQ obs
// soc_axi_decerr_test  | TC_AXI_DEC_18   | AXI4 (read 0x8000_0000)
// soc_fifo_ovf_test    | TC_FIFO_OVF_19  | Stream + AXI4 + IRQ obs
// soc_dma_abort_test   | TC_DMA_ABORT_20 | AXI4 (write ABORT bit 0x6000_0000)
// =============================================================================

`ifndef SOC_DIRECTED_TESTS_SV
`define SOC_DIRECTED_TESTS_SV

// ============================================================================
// TC_MEM_IMEM_03 — AXI write+read to IMEM (0x0000_0000)
// ============================================================================
class soc_mem_imem_test extends soc_base_test;
    `uvm_component_utils(soc_mem_imem_test)
    function new(string name = "soc_mem_imem_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
        soc_axi_write_read_seq seq;
        phase.raise_objection(this);
        seq = soc_axi_write_read_seq::type_id::create("seq");
        seq.target_addr  = 32'h0000_0000;
        seq.test_pattern = 32'hA5A5_5A5A;
        seq.start(env.axi_agent.sequencer);
        phase.drop_objection(this);
    endtask
endclass

// ============================================================================
// TC_MEM_DMEM_04 — AXI write+read to DMEM (0x1000_0100)
// ============================================================================
class soc_mem_dmem_test extends soc_base_test;
    `uvm_component_utils(soc_mem_dmem_test)
    function new(string name = "soc_mem_dmem_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
        soc_axi_write_read_seq seq;
        phase.raise_objection(this);
        seq = soc_axi_write_read_seq::type_id::create("seq");
        seq.target_addr  = 32'h1000_0100;
        seq.test_pattern = 32'hA5A5_5A5A;
        seq.start(env.axi_agent.sequencer);
        phase.drop_objection(this);
    endtask
endclass

// ============================================================================
// TC_UART_REG_05 — Write UART LCR (0x2000_000C) and read back
// ============================================================================
class soc_uart_reg_test extends soc_base_test;
    `uvm_component_utils(soc_uart_reg_test)
    function new(string name = "soc_uart_reg_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
        soc_axi_write32_seq wr_seq;
        soc_axi_read32_seq  rd_seq;
        phase.raise_objection(this);
        // Write LCR = 0x03 (8N1) at offset 0x0C
        wr_seq = soc_axi_write32_seq::type_id::create("wr_seq");
        wr_seq.target_addr = 32'h2000_000C;
        wr_seq.write_data  = 32'h0000_0003;
        wr_seq.start(env.axi_agent.sequencer);
        // Read back and verify in scoreboard / test body
        rd_seq = soc_axi_read32_seq::type_id::create("rd_seq");
        rd_seq.target_addr = 32'h2000_000C;
        rd_seq.start(env.axi_agent.sequencer);
        if (rd_seq.got_rdata[1:0] !== 2'b11)
            `uvm_error("TC_UART_REG_05", $sformatf(
                "LCR readback mismatch: expected 0x03, got 0x%08h", rd_seq.got_rdata))
        else
            `uvm_info("TC_UART_REG_05", "PASS: UART LCR = 0x03", UVM_MEDIUM)
        phase.drop_objection(this);
    endtask
endclass

// ============================================================================
// TC_UART_TX_06 — Write to UART THR (0x2000_0000) then watch uart_tx
// ============================================================================
class soc_uart_tx_test extends soc_base_test;
    `uvm_component_utils(soc_uart_tx_test)
    function new(string name = "soc_uart_tx_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
        soc_axi_write32_seq wr_seq;
        phase.raise_objection(this);
        // Write 'P' (0x50) to UART THR (offset 0x00)
        wr_seq = soc_axi_write32_seq::type_id::create("wr_seq");
        wr_seq.target_addr = 32'h2000_0000;
        wr_seq.write_data  = 32'h0000_0050;  // ASCII 'P'
        wr_seq.start(env.axi_agent.sequencer);
        // Wait for UART TX start bit — observed by irq_agent monitor
        env.irq_agent.monitor.wait_for_uart_start_bit(10000);
        `uvm_info("TC_UART_TX_06", "PASS: uart_tx start bit detected", UVM_MEDIUM)
        phase.drop_objection(this);
    endtask
endclass

// ============================================================================
// TC_TIMER_07 — Write timer counter and control regs (0x3000_0000)
// ============================================================================
class soc_timer_test extends soc_base_test;
    `uvm_component_utils(soc_timer_test)
    function new(string name = "soc_timer_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
        soc_axi_write32_seq wr_seq;
        soc_axi_read32_seq  rd_seq;
        phase.raise_objection(this);
        // Write timer compare value (offset 0x04)
        wr_seq = soc_axi_write32_seq::type_id::create("wr_cmp");
        wr_seq.target_addr = 32'h3000_0004;
        wr_seq.write_data  = 32'h1234_5678;
        wr_seq.start(env.axi_agent.sequencer);
        // Read back
        rd_seq = soc_axi_read32_seq::type_id::create("rd_cmp");
        rd_seq.target_addr = 32'h3000_0004;
        rd_seq.start(env.axi_agent.sequencer);
        if (rd_seq.got_rdata !== 32'h1234_5678)
            `uvm_error("TC_TIMER_07", $sformatf(
                "Timer reg mismatch: expected 0x12345678, got 0x%08h", rd_seq.got_rdata))
        else
            `uvm_info("TC_TIMER_07", "PASS: timer compare reg holds 0x12345678", UVM_MEDIUM)
        // Enable timer (offset 0x00, CTRL = 0x05)
        wr_seq = soc_axi_write32_seq::type_id::create("wr_ctrl");
        wr_seq.target_addr = 32'h3000_0000;
        wr_seq.write_data  = 32'h0000_0005;
        wr_seq.start(env.axi_agent.sequencer);
        phase.drop_objection(this);
    endtask
endclass

// ============================================================================
// TC_GPIO_08 — Set GPIO direction 0xFF and drive 0xA5 (0x4000_0000)
// ============================================================================
class soc_gpio_test extends soc_base_test;
    `uvm_component_utils(soc_gpio_test)
    function new(string name = "soc_gpio_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
        soc_axi_write32_seq wr_seq;
        phase.raise_objection(this);
        // Write GPIO DIR register (offset 0x08)
        wr_seq = soc_axi_write32_seq::type_id::create("wr_dir");
        wr_seq.target_addr = 32'h4000_0008;
        wr_seq.write_data  = 32'h0000_00FF;
        wr_seq.start(env.axi_agent.sequencer);
        // Write GPIO DATA_OUT register (offset 0x04)
        wr_seq = soc_axi_write32_seq::type_id::create("wr_data");
        wr_seq.target_addr = 32'h4000_0004;
        wr_seq.write_data  = 32'h0000_00A5;
        wr_seq.start(env.axi_agent.sequencer);
        `uvm_info("TC_GPIO_08", "GPIO DIR=0xFF DATA=0xA5 written; check gpio_o/gpio_oe in waveform", UVM_MEDIUM)
        phase.drop_objection(this);
    endtask
endclass

// ============================================================================
// TC_FIFO_STREAM_09 — Push 8 vibration samples via stream interface
// ============================================================================
class soc_fifo_stream_test extends soc_base_test;
    `uvm_component_utils(soc_fifo_stream_test)
    function new(string name = "soc_fifo_stream_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
        soc_axi_write32_seq  cfg_seq;
        soc_stream_push_n_seq stream_seq;
        phase.raise_objection(this);
        // Enable stream and threshold via FIFO CTRL register (AXI write to 0x5000_0004)
        cfg_seq = soc_axi_write32_seq::type_id::create("cfg");
        cfg_seq.target_addr = 32'h5000_0004;  // FIFO_REG_CTRL
        cfg_seq.write_data  = 32'h0000_0511;  // STREAM_EN | THRESH=4 | DREQ_EN | IRQ_EN
        cfg_seq.start(env.axi_agent.sequencer);
        // Push 8 samples
        stream_seq = soc_stream_push_n_seq::type_id::create("stream");
        stream_seq.start(env.stream_agent.sequencer);
        `uvm_info("TC_FIFO_STREAM_09", "8 samples pushed; check FIFO count via AXI read", UVM_MEDIUM)
        phase.drop_objection(this);
    endtask
endclass

// ============================================================================
// TC_FIFO_SW_POP_10 — AXI read from FIFO DATA register (0x5000_0000)
// ============================================================================
class soc_fifo_pop_test extends soc_base_test;
    `uvm_component_utils(soc_fifo_pop_test)
    function new(string name = "soc_fifo_pop_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
        soc_axi_read32_seq rd_seq;
        phase.raise_objection(this);
        rd_seq = soc_axi_read32_seq::type_id::create("rd");
        rd_seq.target_addr = 32'h5000_0000;  // FIFO DATA register
        rd_seq.start(env.axi_agent.sequencer);
        if (rd_seq.got_rdata !== 32'd120)
            `uvm_error("TC_FIFO_SW_POP_10", $sformatf(
                "FIFO pop mismatch: expected 120, got %0d", rd_seq.got_rdata))
        else
            `uvm_info("TC_FIFO_SW_POP_10", "PASS: popped sample = 120", UVM_MEDIUM)
        phase.drop_objection(this);
    endtask
endclass

// ============================================================================
// TC_FIFO_IRQ_11 — Push samples until threshold=4, check fifo_irq_o asserts
// ============================================================================
class soc_fifo_irq_test extends soc_base_test;
    `uvm_component_utils(soc_fifo_irq_test)
    function new(string name = "soc_fifo_irq_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
        soc_axi_write32_seq   cfg_seq;
        soc_stream_push_n_seq push_seq;
        phase.raise_objection(this);
        // Configure threshold = 4, enable IRQ
        cfg_seq = soc_axi_write32_seq::type_id::create("cfg");
        cfg_seq.target_addr = 32'h5000_0004;
        cfg_seq.write_data  = 32'h0000_0401; // THRESH=4, IRQ_EN
        cfg_seq.start(env.axi_agent.sequencer);
        // Push exactly 4 samples
        push_seq = soc_stream_push_n_seq::type_id::create("push");
        push_seq.sample_values = '{120, 135, 128, 160};
        push_seq.start(env.stream_agent.sequencer);
        // Monitor checks fifo_irq assertion
        env.irq_agent.monitor.wait_for_fifo_irq(100);
        `uvm_info("TC_FIFO_IRQ_11", "PASS: fifo_irq asserted at threshold=4", UVM_MEDIUM)
        phase.drop_objection(this);
    endtask
endclass

// ============================================================================
// TC_DMA_CFG_12 — Program DMA CH0 SRC/DST/LEN registers (0x6000_0000)
// ============================================================================
class soc_dma_cfg_test extends soc_base_test;
    `uvm_component_utils(soc_dma_cfg_test)
    function new(string name = "soc_dma_cfg_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
        soc_axi_write32_seq wr_seq;
        phase.raise_objection(this);
        // DMA CH0 SRC = FIFO base (0x5000_0000) — offset 0x08
        wr_seq = soc_axi_write32_seq::type_id::create("src");
        wr_seq.target_addr = 32'h6000_0008;
        wr_seq.write_data  = 32'h5000_0000;
        wr_seq.start(env.axi_agent.sequencer);
        // DMA CH0 DST = DMEM buffer (0x1000_0100) — offset 0x0C
        wr_seq = soc_axi_write32_seq::type_id::create("dst");
        wr_seq.target_addr = 32'h6000_000C;
        wr_seq.write_data  = 32'h1000_0100;
        wr_seq.start(env.axi_agent.sequencer);
        // DMA CH0 LEN = 32 bytes (8 words) — offset 0x10
        wr_seq = soc_axi_write32_seq::type_id::create("len");
        wr_seq.target_addr = 32'h6000_0010;
        wr_seq.write_data  = 32'h0000_0020;  // 32 bytes
        wr_seq.start(env.axi_agent.sequencer);
        `uvm_info("TC_DMA_CFG_12", "DMA CH0 SRC/DST/LEN programmed", UVM_MEDIUM)
        phase.drop_objection(this);
    endtask
endclass

// ============================================================================
// TC_DMA_IRQ_14 — Start DMA and wait for dma_irq_o within 200 cycles
// ============================================================================
class soc_dma_irq_test extends soc_base_test;
    `uvm_component_utils(soc_dma_irq_test)
    function new(string name = "soc_dma_irq_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
        soc_axi_write32_seq wr_seq;
        phase.raise_objection(this);
        // Start DMA CH0 (CTRL = EN | START = 0x03) at offset 0x00
        wr_seq = soc_axi_write32_seq::type_id::create("start");
        wr_seq.target_addr = 32'h6000_0000;
        wr_seq.write_data  = 32'h0000_0003;
        wr_seq.start(env.axi_agent.sequencer);
        // Wait for DMA IRQ
        env.irq_agent.monitor.wait_for_dma_irq(200);
        `uvm_info("TC_DMA_IRQ_14", "PASS: dma_irq asserted within 200 cycles", UVM_MEDIUM)
        phase.drop_objection(this);
    endtask
endclass

// ============================================================================
// TC_PLIC_15 — Configure PLIC, claim/complete interrupt cycle
// ============================================================================
class soc_plic_test_tc15 extends soc_base_test;
    `uvm_component_utils(soc_plic_test_tc15)
    function new(string name = "soc_plic_test_tc15", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
        soc_axi_write32_seq wr_seq;
        soc_axi_read32_seq  rd_seq;
        phase.raise_objection(this);
        // Set DMA source priority = 5 at PLIC_PRIO[1] (0x7000_0004)
        wr_seq = soc_axi_write32_seq::type_id::create("prio");
        wr_seq.target_addr = 32'h7000_0004;
        wr_seq.write_data  = 32'h0000_0005;
        wr_seq.start(env.axi_agent.sequencer);
        // Enable source 1 for target 0 (0x7000_2000)
        wr_seq = soc_axi_write32_seq::type_id::create("ena");
        wr_seq.target_addr = 32'h7000_2000;
        wr_seq.write_data  = 32'h0000_0007;  // enable sources 1,2,3
        wr_seq.start(env.axi_agent.sequencer);
        // Claim interrupt for target 0 (0x7000_200004 — use simplified offset)
        rd_seq = soc_axi_read32_seq::type_id::create("claim");
        rd_seq.target_addr = 32'h7000_1004;  // PLIC claim register target 0
        rd_seq.start(env.axi_agent.sequencer);
        if (rd_seq.got_rdata !== 32'h1)
            `uvm_error("TC_PLIC_15", $sformatf(
                "Claim should return source ID 1, got %0d", rd_seq.got_rdata))
        else
            `uvm_info("TC_PLIC_15", "PASS: claim returned ID=1", UVM_MEDIUM)
        // Complete — write claim register with source ID
        wr_seq = soc_axi_write32_seq::type_id::create("complete");
        wr_seq.target_addr = 32'h7000_1004;
        wr_seq.write_data  = 32'h0000_0001;
        wr_seq.start(env.axi_agent.sequencer);
        phase.drop_objection(this);
    endtask
endclass

// ============================================================================
// TC_AXI_ARB_16 — Concurrent transactions from CPU (S00) and DMA (S01)
//                  In UVM: two parallel sequences on axi_agent
// ============================================================================
class soc_axi_arb_test extends soc_base_test;
    `uvm_component_utils(soc_axi_arb_test)
    function new(string name = "soc_axi_arb_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
        soc_axi_write32_seq wr_seq1, wr_seq2;
        phase.raise_objection(this);
        // Issue two back-to-back writes to different slaves to exercise arbitration
        fork
            begin
                wr_seq1 = soc_axi_write32_seq::type_id::create("s0_wr");
                wr_seq1.target_addr = 32'h0000_0000;  // IMEM
                wr_seq1.write_data  = 32'hDEAD_BEEF;
                wr_seq1.start(env.axi_agent.sequencer);
            end
            begin
                wr_seq2 = soc_axi_write32_seq::type_id::create("s1_wr");
                wr_seq2.target_addr = 32'h1000_0000;  // DMEM
                wr_seq2.write_data  = 32'hCAFE_BABE;
                wr_seq2.start(env.axi_agent.sequencer);
            end
        join
        `uvm_info("TC_AXI_ARB_16",
            "Both AXI transactions completed without deadlock", UVM_MEDIUM)
        phase.drop_objection(this);
    endtask
endclass

// ============================================================================
// TC_E2E_DATA_17 — Full pipeline: stream 8 samples, DMA, verify UART
// ============================================================================
class soc_e2e_test_tc17 extends soc_base_test;
    `uvm_component_utils(soc_e2e_test_tc17)
    function new(string name = "soc_e2e_test_tc17", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
        soc_axi_write32_seq   cfg_seq, dma_start;
        soc_stream_e2e_seq    stream_seq;
        soc_axi_read32_seq    rd_seq;
        logic [31:0]          dmem_val;
        logic [1:0]           resp;
        // Expected E2E samples per CSV TC_E2E_DATA_17
        logic [31:0] expected_samples[8] = '{120, 135, 128, 160, 175, 142, 130, 118};
        int          peak_val = 0;
        int          peak_idx = 0;

        phase.raise_objection(this);

        // 1. Configure FIFO
        cfg_seq = soc_axi_write32_seq::type_id::create("fifo_cfg");
        cfg_seq.target_addr = 32'h5000_0004;
        cfg_seq.write_data  = 32'h0000_0511;
        cfg_seq.start(env.axi_agent.sequencer);

        // 2. Configure DMA CH0 SRC/DST/LEN
        cfg_seq = soc_axi_write32_seq::type_id::create("dma_src");
        cfg_seq.target_addr = 32'h6000_0008; cfg_seq.write_data = 32'h5000_0000;
        cfg_seq.start(env.axi_agent.sequencer);

        cfg_seq = soc_axi_write32_seq::type_id::create("dma_dst");
        cfg_seq.target_addr = 32'h6000_000C; cfg_seq.write_data = 32'h1000_0100;
        cfg_seq.start(env.axi_agent.sequencer);

        cfg_seq = soc_axi_write32_seq::type_id::create("dma_len");
        cfg_seq.target_addr = 32'h6000_0010; cfg_seq.write_data = 32'h0000_0020;
        cfg_seq.start(env.axi_agent.sequencer);

        // 3. Stream 8 samples into FIFO
        stream_seq = soc_stream_e2e_seq::type_id::create("stream");
        stream_seq.start(env.stream_agent.sequencer);

        // 4. Start DMA transfer
        dma_start = soc_axi_write32_seq::type_id::create("dma_go");
        dma_start.target_addr = 32'h6000_0000;
        dma_start.write_data  = 32'h0000_0003;
        dma_start.start(env.axi_agent.sequencer);

        // 5. Wait for DMA IRQ (max 200 cycles)
        env.irq_agent.monitor.wait_for_dma_irq(200);

        // 6. Verify DMEM contents and find peak
        for (int i = 0; i < 8; i++) begin
            rd_seq = soc_axi_read32_seq::type_id::create($sformatf("rd_dmem_%0d", i));
            rd_seq.target_addr = 32'h1000_0100 + (i * 4);
            rd_seq.start(env.axi_agent.sequencer);
            if (rd_seq.got_rdata !== expected_samples[i])
                `uvm_error("TC_E2E_DATA_17", $sformatf(
                    "DMEM[%0d] mismatch: expected %0d, got %0d",
                    i, expected_samples[i], rd_seq.got_rdata))
            if (rd_seq.got_rdata > peak_val) begin
                peak_val = rd_seq.got_rdata;
                peak_idx = i;
            end
        end
        if (peak_val !== 175)
            `uvm_error("TC_E2E_DATA_17", $sformatf(
                "Peak mismatch: expected 175, got %0d at index %0d", peak_val, peak_idx))
        else
            `uvm_info("TC_E2E_DATA_17",
                $sformatf("PASS: all 8 samples correct; peak=%0d at index %0d",
                           peak_val, peak_idx), UVM_MEDIUM)

        // 7. Check UART TX emits start bit ("PEAK=175\n" begins with 'P')
        env.irq_agent.monitor.wait_for_uart_start_bit(10000);
        `uvm_info("TC_E2E_DATA_17", "PASS: UART TX start bit seen", UVM_MEDIUM)

        phase.drop_objection(this);
    endtask
endclass

// ============================================================================
// TC_AXI_DEC_18 — Read to unmapped address returns DECERR
// ============================================================================
class soc_axi_decerr_test extends soc_base_test;
    `uvm_component_utils(soc_axi_decerr_test)
    function new(string name = "soc_axi_decerr_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
        soc_axi_decerr_seq seq;
        phase.raise_objection(this);
        seq = soc_axi_decerr_seq::type_id::create("seq");
        seq.start(env.axi_agent.sequencer);
        phase.drop_objection(this);
    endtask
endclass

// ============================================================================
// TC_FIFO_OVF_19 — Push 65 samples, check OVF_STICKY
// ============================================================================
class soc_fifo_ovf_test extends soc_base_test;
    `uvm_component_utils(soc_fifo_ovf_test)
    function new(string name = "soc_fifo_ovf_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
        soc_axi_write32_seq    cfg_seq;
        soc_stream_overflow_seq ovf_seq;
        soc_axi_read32_seq     rd_seq;
        phase.raise_objection(this);
        // Enable stream
        cfg_seq = soc_axi_write32_seq::type_id::create("cfg");
        cfg_seq.target_addr = 32'h5000_0004;
        cfg_seq.write_data  = 32'h0000_0101;  // STREAM_EN | IRQ_EN
        cfg_seq.start(env.axi_agent.sequencer);
        // Push 65 samples
        ovf_seq = soc_stream_overflow_seq::type_id::create("ovf");
        ovf_seq.start(env.stream_agent.sequencer);
        // Read FIFO STATUS register (offset 0x08)
        rd_seq = soc_axi_read32_seq::type_id::create("rd_status");
        rd_seq.target_addr = 32'h5000_0008;
        rd_seq.start(env.axi_agent.sequencer);
        // Bit 0 = FULL, Bit 1 = OVF_STICKY (per CSV)
        if (!rd_seq.got_rdata[0])
            `uvm_error("TC_FIFO_OVF_19", "FULL flag not set after 64 pushes")
        if (!rd_seq.got_rdata[1])
            `uvm_error("TC_FIFO_OVF_19", "OVF_STICKY flag not set after overflow")
        if (rd_seq.got_rdata[1:0] === 2'b11)
            `uvm_info("TC_FIFO_OVF_19", "PASS: FULL=1 and OVF_STICKY=1", UVM_MEDIUM)
        phase.drop_objection(this);
    endtask
endclass

// ============================================================================
// TC_DMA_ABORT_20 — Initiate DMA then assert ABORT bit
// ============================================================================
class soc_dma_abort_test extends soc_base_test;
    `uvm_component_utils(soc_dma_abort_test)
    function new(string name = "soc_dma_abort_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
        soc_axi_write32_seq wr_seq;
        soc_axi_read32_seq  rd_seq;
        phase.raise_objection(this);
        // Start DMA
        wr_seq = soc_axi_write32_seq::type_id::create("start");
        wr_seq.target_addr = 32'h6000_0000;
        wr_seq.write_data  = 32'h0000_0003;
        wr_seq.start(env.axi_agent.sequencer);
        // Immediately assert ABORT (bit 2 = 0x04)
        wr_seq = soc_axi_write32_seq::type_id::create("abort");
        wr_seq.target_addr = 32'h6000_0000;
        wr_seq.write_data  = 32'h0000_0004;
        wr_seq.start(env.axi_agent.sequencer);
        // Poll DMA CH0 status (offset 0x04) until IDLE (0)
        begin : poll_idle
            int timeout = 0;
            rd_seq = soc_axi_read32_seq::type_id::create("status");
            rd_seq.target_addr = 32'h6000_0004;
            forever begin
                rd_seq.start(env.axi_agent.sequencer);
                if (rd_seq.got_rdata[2:0] === 3'b000) begin
                    `uvm_info("TC_DMA_ABORT_20", "PASS: DMA channel returned to IDLE", UVM_MEDIUM)
                    break;
                end
                timeout++;
                if (timeout > 100)
                    `uvm_error("TC_DMA_ABORT_20", "DMA channel did not return IDLE within 100 polls")
                #10ns;
            end
        end
        phase.drop_objection(this);
    endtask
endclass

`endif // SOC_DIRECTED_TESTS_SV
