# RISC-V VeeR EL2 Based Real-Time Data Buffering SoC

## 1. Project Overview & Architecture
This project delivers a complete, synthesizable SystemVerilog System-on-Chip (SoC) designed for real-time sensor data buffering, hardware peak detection, and autonomous Direct Memory Access (DMA) transfer to system memory, monitored by an external UART serial interface and a RISC-V PLIC (Platform-Level Interrupt Controller).

### System Components:
- **Processor**: RISC-V VeeR EL2 (RV32IMC, 32-bit RISC-V core).
- **Bus Infrastructure**: Parameterized 2-Master $\times$ 8-Slave AXI4 Interconnect (`axi_interconnect_wrap_2x8`) supporting concurrent master transactions from the CPU (S00) and the DMA Engine (S01).
- **Core Internal Closely Coupled Memories (VeeR EL2)**:
  - `0xEE00_0000 - 0xEE00_FFFF`: Instruction Closely Coupled Memory (ICCM, 64 KiB) — **Primary executable region** (core boot address `rst_vec = 0xEE00_0000`; IFU fetches from ICCM as external IFU AXI master is tied off).
  - `0xF004_0000 - 0xF004_FFFF`: Data Closely Coupled Memory (DCCM, 64 KiB) — Core local data/stack RAM (`sp`, `.data`, `.bss`).
- **AXI Interconnect Memory Map (16 MiB aperture per slave port)**:
  - `0x0000_0000 - 0x00FF_FFFF`: M00 - External Instruction Memory (IMEM, 64 KiB AXI SRAM)
  - `0x1000_0000 - 0x10FF_FFFF`: M01 - External Data Memory (DMEM, 64 KiB AXI SRAM) — **Autonomous DMA target buffer**
  - `0x2000_0000 - 0x20FF_FFFF`: M02 - Real-Time Vibration Data Buffer FIFO
  - `0x3000_0000 - 0x30FF_FFFF`: M03 - 4-Channel Multi-Mode DMA Controller
  - `0x4000_0000 - 0x40FF_FFFF`: M04 - Platform-Level Interrupt Controller (PLIC)
  - `0x5000_0000 - 0x50FF_FFFF`: M05 - UART Controller (AXI4-Lite IP Core)
  - `0x6000_0000 - 0x60FF_FFFF`: M06 - Hardware Timer Peripheral Responder
  - `0x7000_0000 - 0x70FF_FFFF`: M07 - GPIO Peripheral Responder
- **Real-Time Data Buffering Flow**:
  $$\text{External Sensor Stream} \xrightarrow{} \text{Hardware FIFO} \xrightarrow{} \text{DMA Controller (CH0)} \xrightarrow{} \text{System DMEM (0x1000_0100)} \xrightarrow{} \text{PLIC IRQ} \xrightarrow{} \text{UART TX}$$


---

## 2. IP Deliverables & RTL Enhancements
1. **FIFO Controller (`rtl/fifo/axi_data_buffer_fifo.sv`)**:
   - Synchronous circular buffer supporting simultaneous hardware stream push and AXI read pops.
   - Programmable occupancy threshold, watermark flags (empty, almost empty, almost full, full), and sticky overflow/underflow monitoring.
   - Zero-latency combinational read data multiplexing with handshake-synchronized FIFO pop timing for seamless multi-beat AXI burst transfers.
2. **DMA Controller (`rtl/dma/`)**:
   - 4 independent DMA channels supporting Memory-to-Memory (`XFER_MEM2MEM`), Peripheral-to-Memory (`XFER_PERIPH2MEM`), and Memory-to-Peripheral (`XFER_MEM2PERIPH`) transfers.
   - AXI4 Master wrapper (`dma_axi_master.sv`) generating compliant INCR bursts and handling read/write channel arbitration.
   - Per-channel Transfer Complete (TC) and Error interrupt generation mapped into the system interrupt fabric.
3. **Interrupt Controller (`rtl/interrupt_controller/`)**:
   - Fully synthesizable RISC-V PLIC architecture with priority resolvers, target threshold registers, and per-source enable/pending registers.
   - Sources: DMA IRQ (Source 1), FIFO Threshold/Overflow IRQ (Source 2), UART IRQ (Source 3).
   - Generates CPU external interrupt (`cpu_eip_o`) to VeeR EL2 core.
4. **Preserved UART AXI-Lite Subsystem (`rtl/axi-lite_uart-ipcore-develop/`)**:
   - Unmodified, verified AXI4-Lite UART IP core connected via `axi4_to_axilite_32_adapter.sv`.
5. **Fixed Priority Encoder (`rtl/priority_encoder.v`)**:
   - Replaced flawed recursive tree width truncation with a clean parameterized behavioral priority encoder, restoring AXI arbitration grants for Master Port S01 (DMA).

---

## 3. UVM Verification Environment (5-Member DV Team)

The verification environment is architected under `uvm_tb/` for parallel execution by a 5-member DV team:

| DV Member | Verification Responsibility | UVM Test Class | Test Objectives & Coverage | Status |
|:---|:---|:---|:---|:---:|
| **Member 1** | FIFO Peripheral Verification | `soc_fifo_test` | Reset empty/full flags, programmed thresholds, SW push/pop ordering, occupancy counter accuracy. | **PASSED** (0 Errors) |
| **Member 2** | DMA Controller Verification | `soc_dma_test` | Configuration registers, AXI burst initiation, address progression, MEM2MEM block transfer, TC interrupt assertion. | **PASSED** (0 Errors) |
| **Member 3** | Interrupt Controller (PLIC) | `soc_plic_test` | Source priority programming, target threshold filtering, source enable masks, pending flag routing to CPU external interrupt. | **PASSED** (0 Errors) |
| **Member 4** | AXI Interconnect & UART | `soc_axi_uart_test` | 2x8 address decoding across all slave ports, AXI handshake protocols, UART AXI-Lite register access and serial character TX. | **PASSED** (0 Errors) |
| **Member 5** | Top SoC End-to-End Regression | `soc_e2e_test` | Full autonomous sensor stream buffering $\rightarrow$ FIFO $\rightarrow$ DMA transfer to DMEM $\rightarrow$ Peak vibration verification (175) $\rightarrow$ UART packet transmission. | **PASSED** (0 Errors) |

---

## 4. How to Run Simulation & Regressions

### Environment Setup
```bash
export VCS_HOME=/home/student/snps_tools_target/vcs/U-2023.03
export VERDI_HOME=/home/student/snps_tools_target/verdi/U-2023.03-SP1
export SNPSLMD_LICENSE_FILE=27021@14.139.1.126
export PATH=$VCS_HOME/bin:$VERDI_HOME/bin:$PATH
export RV_ROOT="/home/student/Documents/317/soc_project_data_buffering/rtl/Cores-VeeR-EL2"
```

### Running Top-Level SoC Directed Testbench
```bash
cd "/home/student/Documents/317/soc_project_data buffering/run"
vcs -full64 -sverilog -timescale=1ns/1ps -debug_access+all -kdb -lca +vcs+lic+wait \
    -top tb_soc_data_buffering_top -o simv -f soc_top.f -l compile.log
./simv
```

### Running UVM Verification Suite
Using the Makefile in `uvm_tb/scripts/`:
```bash
cd "/home/student/Documents/317/soc_project_data buffering/uvm_tb/scripts"

# Run individual member tests:
make test_fifo        # Member 1 (FIFO)
make test_dma         # Member 2 (DMA)
make test_plic        # Member 3 (PLIC)
make test_axi_uart    # Member 4 (AXI & UART)
make test_e2e         # Member 5 (Top SoC End-to-End)

# Run complete 5-member regression:
make regression
```

Or using the automated shell runner:
```bash
cd "/home/student/Documents/317/soc_project_data buffering/uvm_tb/scripts"
./run_uvm.sh soc_e2e_test
```

---

## 5. VeeR EL2 Bare-Metal C Firmware Suite (`sw/`)

A synthesizable bare-metal C test suite is prepared under `sw/` to exercise the complete SoC data-buffering flow natively on the RISC-V VeeR EL2 core:

- **Source Files**:
  - `sw/soc_regs.h`: Hardware register addresses and bitfield definitions matching RTL.
  - `sw/main.c`: Configures PLIC priorities, programs FIFO threshold, pushes 8 sample vibrations, triggers DMA Channel 0 block transfer, waits for completion interrupt, validates DMEM content, detects peak vibration, and outputs the diagnostic string `"PEAK=175\n"` via UART.
  - `sw/startup.s`: CRT0 startup assembly initializing stack pointer, trap vector, and clearing BSS before jumping to `main`.
  - `sw/link.ld`: Linker script targeting VeeR EL2 ICCM (`0xEE00_0000`) and DCCM (`0xF004_0000`).
  - `sw/Makefile`: Automates cross-compilation into ELF, disassembly dump, and Verilog hex generation.

### Toolchain Dependency & Preload Instructions
To compile the C firmware into an instruction memory image:
```bash
cd "/home/student/Documents/317/soc_project_data buffering/sw"
make CROSS_COMPILE=riscv32-unknown-elf-
```
The resulting `main.hex` can be preloaded into the VeeR EL2 ICCM or IMEM via `$readmemh("main.hex", u_imem.ram)` when running with `ENABLE_INTERNAL_CPU = 1'b1`. If `riscv32-unknown-elf-gcc` is not installed on the host system, the testbench directly drives S00 AXI transactions to verify all register and data flows deterministically.

