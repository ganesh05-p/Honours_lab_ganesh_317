# RISC-V VeeR EL2 Based Real-Time Data Buffering SoC

[![Project](https://img.shields.io/badge/Project-VeeR--EL2--Data--Buffering--SoC-blue)](https://github.com/ganesh05-p/Honours_lab_ganesh_317)
[![RTL](https://img.shields.io/badge/RTL-Verilog-green)](https://github.com/ganesh05-p/Honours_lab_ganesh_317/tree/main/soc_project_data%20buffering/rtl)
[![Interconnect](https://img.shields.io/badge/Interconnect-AXI4%202x8-orange)](https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/soc_project_data%20buffering/rtl/axi_interconnect_wrap_2x8.v)
[![Sim](https://img.shields.io/badge/Simulation-VCS%20%7C%20Verdi-lightgrey)](https://github.com/ganesh05-p/Honours_lab_ganesh_317/tree/main/soc_project_data%20buffering/run)
[![Status](https://img.shields.io/badge/Status-Work%20in%20progress-yellow)](#11-known-limitations-and-current-status)

**RISC-V VeeR EL2 Based Real-Time Data Buffering SoC — an AXI4 interconnect-centric SoC build-out, currently at the "interconnect proven, peripherals vendored but not yet wired in" stage, working toward I2C / AES-128 / UART integration and an eventual VeeR EL2 RISC-V CPU top**

**Repository:** [github.com/ganesh05-p/Honours_lab_ganesh_317](https://github.com/ganesh05-p/Honours_lab_ganesh_317)

## Table of Contents
- [Project](#project)
- [Author](#author)
- [Highlights](#highlights)
- [Architecture (current)](#architecture-current)
- [Diagrams](#diagrams)
- [Placeholder Address Map (interconnect testbench)](#placeholder-address-map-interconnect-testbench)
- [1. Project overview and current goals](#1-project-overview-and-current-goals)
- [2. Implemented vs planned/stubbed blocks](#2-implemented-vs-plannedstubbed-blocks)
- [3. Detailed architecture and data/control flow](#3-detailed-architecture-and-datacontrol-flow)
- [4. Repository layout](#4-repository-layout-current)
- [5. Module/file responsibility table](#5-modulefile-responsibility-table)
- [6. AES AXI experiment (standalone, not yet merged)](#6-aes-axi-experiment-standalone-not-yet-merged)
- [7. Simulation prerequisites and exact flows](#7-simulation-prerequisites-and-exact-flows)
- [8. Verification strategy and covered scenarios](#8-verification-strategy-and-covered-scenarios)
- [9. Wrapper generator usage](#9-wrapper-generator-usage-scriptsaxi_interconnect_wrappy)
- [10. Imported IP — sources, references & licenses](#10-imported-ip-notes-i2c--aes--uart--sources-and-references)
- [11. Known limitations and current status](#11-known-limitations-and-current-status)
- [12. Contribution/dev guidance and provenance notes](#12-contributiondev-guidance-and-provenance-notes)
- [13. Quick reference commands](#13-quick-reference-commands)
- [Documents Index](#documents-index)

---

## Project
**RISC-V VeeR EL2 Based Real-Time Data Buffering SoC** — a lab/honours project working toward an AXI4 interconnect-centric SoC that will route CPU and DMA-style masters to a WISHBONE I2C master, an AES-128 encrypt/decrypt core, and an AXI-Lite UART, with an eventual VeeR EL2 RISC-V CPU as the driving master. At the current commit, the AXI4 crossbar itself is built and self-checking-tested against parameterised dummy slaves, and the three peripheral IP cores are vendored into the repo — but the AXI wrapper/bridge work that would connect them to the crossbar, and the VeeR EL2 core integration implied by the project title, are not yet in place. See [§2](#2-implemented-vs-plannedstubbed-blocks) and [§11](#11-known-limitations-and-current-status) for the exact gap list.

## Author
- **GitHub:** [@ganesh05-p](https://github.com/ganesh05-p)

## Highlights
- **AXI4 interconnect** ([`axi_interconnect_wrap_2x8.v`](https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/soc_project_data%20buffering/rtl/axi_interconnect_wrap_2x8.v)) — Alex Forencich's parameterised AXI4 crossbar (`axi_interconnect.v` + `arbiter.v` + `priority_encoder.v`), port-expanded to 2 slave-side masters (`s00`, `s01`) × 8 master-side targets (`m00`..`m07`), each on a 16 MB (`2^24`) address window
- **Self-checking standalone testbench** ([`tb_axi_interconnect_wrap_2x8.v`](<https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/soc_project_data%20buffering/tb%20files/tb_axi_interconnect_wrap_2x8.v>)) — drives the `s00` master through 3 writes + 3 reads against a placeholder 8-region SoC address map (IMEM/DMEM/FIFO/DMA/INTCTL/UART/TIMER/GPIO) implemented as generic dummy slaves, with a pass/fail counter printed at the end of the run
- **Parameterised dummy AXI4 slave** ([`axi_slave_dummy.v`](<https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/soc_project_data%20buffering/tb%20files/axi_slave_dummy.v>)) — single-cycle-ready AXI4 slave backed by a 256-word local SRAM, used to stand in for every peripheral until the real IP is wired in
- **Three vendored peripheral IP cores, not yet AXI-integrated into the crossbar above:**
  - **I2C** — OpenCores WISHBONE rev B.2 I2C master ([`i2c-master/`](https://github.com/ganesh05-p/Honours_lab_ganesh_317/tree/main/i2c-master)), Verilog + VHDL variants, with its own WISHBONE testbench; no AXI-to-WISHBONE bridge exists in the repo yet
  - **AES-128** — Secworks-style AES core ([`aes_core-master/`](https://github.com/ganesh05-p/Honours_lab_ganesh_317/tree/main/aes_core-master)), extended with an experimental, standalone [`aes_axi_slave.v`](https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/aes_core-master/rtl/verilog/axi/aes_axi_slave.v) AXI4 wrapper and its own encrypt+decrypt AXI testbench — this lives outside `soc_project_data buffering` and has **not** been merged into the 2×8 crossbar above (see [§6](#6-aes-axi-experiment-standalone-not-yet-merged))
  - **UART** — the `axi-lite_uart-ipcore` MIT-licensed AXI4-Lite UART core ([`axi-lite_uart-ipcore-develop/`](https://github.com/ganesh05-p/Honours_lab_ganesh_317/tree/main/axi-lite_uart-ipcore-develop)), vendored as-is with its own Makefile-driven build/test flow; no AXI4-full wrapper exists yet
- **Reference documentation already checked in** for the intended end state — a RISC-V VeeR EL2 PRM, an architecture/control-path write-up, and the AES/I2C/UART datasheets — under [`soc_project_data buffering/Docs/`](<https://github.com/ganesh05-p/Honours_lab_ganesh_317/tree/main/soc_project_data%20buffering/Docs>), ahead of the RTL that will eventually match them
- **Wrapper generator** ([`axi_interconnect_wrap.py`](<https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/soc_project_data%20buffering/scripts/axi_interconnect_wrap.py>)) — the same Jinja2 script used to generate `axi_interconnect_wrap_2x8.v`, ready to regenerate a wider wrapper (e.g. 2×11) once more peripherals are ready to attach

## Architecture (current)
Only the crossbar + dummy-slave stage exists today; there is no SoC top module yet:

```text
                         ┌───────────────────────────────┐
  s00 (TB-driven AXI4) ─►│                                │──► m00  IMEM     (0x0000_0000, dummy)
  s01 (unused in TB)  ─►│  axi_interconnect_wrap_2x8      │──► m01  DMEM     (0x1000_0000, dummy)
                         │      (2 masters × 8 slaves)    │──► m02  FIFO     (0x2000_0000, dummy)
                         │                                │──► m03  DMA      (0x3000_0000, dummy)
                         │                                │──► m04  INTCTL   (0x4000_0000, dummy)
                         │                                │──► m05  UART     (0x5000_0000, dummy)
                         │                                │──► m06  TIMER    (0x6000_0000, dummy)
                         │                                │──► m07  GPIO     (0x7000_0000, dummy)
                         └───────────────────────────────┘
```

Every `mXX` target above is currently the same generic [`axi_slave_dummy.v`](<https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/soc_project_data%20buffering/tb%20files/axi_slave_dummy.v>) instance — the names in the diagram describe where the real I2C, AES, UART, DMA, etc. blocks are planned to land, not what is driving those ports today. Separately, and not shown above because it isn't wired into this crossbar, the AES core has its own experimental AXI slave and its own standalone interconnect test (see [§6](#6-aes-axi-experiment-standalone-not-yet-merged)). No VeeR EL2 core, no CPU-facing SoC top, and no AXI-to-WISHBONE I2C bridge exist in the repository yet.

## Diagrams
<p align="center">
  <a href="https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/axi-lite_uart-ipcore-develop/documentation/axi-uart.png">
    <img src="https://raw.githubusercontent.com/ganesh05-p/Honours_lab_ganesh_317/main/axi-lite_uart-ipcore-develop/documentation/axi-uart.png" alt="AXI-Lite UART IP block diagram" width="500"/>
  </a>
  <br/><sub>AXI‑Lite UART IP block diagram, vendored with the core (see also the source <code>.vsdx</code> alongside it)</sub>
</p>

There is no top-level SoC block diagram checked into the repo yet — the ASCII sketch above is the closest thing until the crossbar has real peripherals attached and a diagram is added under `soc_project_data buffering/Docs/`.

---

## Placeholder Address Map (interconnect testbench)
As exercised by [`tb_axi_interconnect_wrap_2x8.v`](<https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/soc_project_data%20buffering/tb%20files/tb_axi_interconnect_wrap_2x8.v>) (each window is `2^24` = 16 MB, all targets currently `axi_slave_dummy.v`):

| Slave | Base Address | Planned Function | Current backing |
|---|---|---|---|
| m00 | `0x0000_0000` | Instruction Memory | dummy AXI slave |
| m01 | `0x1000_0000` | Data Memory | dummy AXI slave |
| m02 | `0x2000_0000` | FIFO | dummy AXI slave |
| m03 | `0x3000_0000` | DMA Controller | dummy AXI slave |
| m04 | `0x4000_0000` | Interrupt Controller | dummy AXI slave |
| m05 | `0x5000_0000` | UART | dummy AXI slave |
| m06 | `0x6000_0000` | Timer | dummy AXI slave |
| m07 | `0x7000_0000` | GPIO | dummy AXI slave |

---

## 1) Project overview and current goals
The repository is building toward an AXI4 interconnect-centric SoC in stages:

1. AXI4 interconnect behavior (decode, arbitration, routing) — **built and self-checking-tested** against dummy slaves
2. AXI4-to-WISHBONE bridging so the vendored OpenCores I2C master can sit on the crossbar — **not started**
3. An AXI4 register-mapped wrapper for the AES-128 core, integrated at a crossbar port — **an experimental version exists, but only against a different, separate interconnect instance outside `soc_project_data buffering`** (see [§6](#6-aes-axi-experiment-standalone-not-yet-merged))
4. An AXI4-full wrapper around the AXI4-Lite UART core, integrated at a crossbar port — **not started**
5. A VeeR EL2 RISC-V CPU driving the crossbar as `s00`, matching the reference PRM already checked into `Docs/` — **not started**
6. Reproducible VCS/Verdi simulation flows per sub-block — **in place for the bare interconnect test; not yet extended to the peripherals**

## 2) Implemented vs planned/stubbed blocks

### Implemented and tested
- [`soc_project_data buffering/rtl/priority_encoder.v`](<https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/soc_project_data%20buffering/rtl/priority_encoder.v>), [`arbiter.v`](<https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/soc_project_data%20buffering/rtl/arbiter.v>), [`axi_interconnect.v`](<https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/soc_project_data%20buffering/rtl/axi_interconnect.v>), [`axi_interconnect_wrap_2x8.v`](<https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/soc_project_data%20buffering/rtl/axi_interconnect_wrap_2x8.v>) — the crossbar itself
- [`tb files/axi_slave_dummy.v`](<https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/soc_project_data%20buffering/tb%20files/axi_slave_dummy.v>) and [`tb_axi_interconnect_wrap_2x8.v`](<https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/soc_project_data%20buffering/tb%20files/tb_axi_interconnect_wrap_2x8.v>) — the verification around it (3 writes + 3 reads, single master, pass/fail counters)

### Vendored, standalone, not yet AXI-integrated with the crossbar above
- [`i2c-master/`](https://github.com/ganesh05-p/Honours_lab_ganesh_317/tree/main/i2c-master) — full OpenCores I2C master RTL (Verilog + VHDL) plus its own WISHBONE-level bench (`wb_master_model.v`, `i2c_slave_model.v`); no `axi_to_wb_bridge`-style module exists anywhere in the repo
- [`aes_core-master/`](https://github.com/ganesh05-p/Honours_lab_ganesh_317/tree/main/aes_core-master) — full AES-128 cipher/inverse-cipher RTL, FuseSoC core file, sky130 synthesis script, plus an **experimental** AXI4 slave wrapper and encrypt/decrypt AXI testbench (see [§6](#6-aes-axi-experiment-standalone-not-yet-merged)) that is separate from, and not wired into, `soc_project_data buffering`'s crossbar
- [`axi-lite_uart-ipcore-develop/`](https://github.com/ganesh05-p/Honours_lab_ganesh_317/tree/main/axi-lite_uart-ipcore-develop) — the AXI4-Lite UART core with its own CI/Makefile-based lint/build/test flow, unmodified from upstream; no AXI4-full wrapper (an `axi_uart_slave.v`-style module) exists yet
- A second, nested copy of `axi-lite_uart-ipcore-develop/` is also present under [`soc_project_data buffering/rtl/`](<https://github.com/ganesh05-p/Honours_lab_ganesh_317/tree/main/soc_project_data%20buffering/rtl/axi-lite_uart-ipcore-develop>) — a duplicate of the top-level copy, not referenced by `run/run.f`

### Not started
- VeeR EL2 RISC-V core integration — no `Cores-VeeR-EL2/` directory, no CPU-facing SoC top module, despite the reference PRM already being checked into `Docs/`
- A unified `soc_top.v` wiring the real I2C/AES/UART blocks (rather than dummy slaves) onto the crossbar
- Any top-level SoC block diagram matching the eventual architecture

## 3) Detailed architecture and data/control flow

### Interconnect testbench (`tb_axi_interconnect_wrap_2x8.v`)
1. A single external AXI4 master port, `s00`, drives `axi_interconnect_wrap_2x8` (the second port, `s01`, is instantiated but left idle by the current TB)
2. The interconnect decodes/arbitrates/routes to `m00`–`m07`, each a `axi_slave_dummy` instance backed by a 256-word local SRAM
3. The TB issues three writes (`0xDEAD_BEEF`→FIFO, `0xCAFE_BABE`→DMA, `0x1234_5678`→INTCTL) followed by three matching reads, checking each returned value and printing PASS/FAIL plus a final tally

### AES AXI experiment (`aes_core-master/bench/verilog/axi_aes_interconnect_top.v`)
1. A separate testbench instantiates `aes_axi_slave.v` behind a *different* AXI interconnect module (`interconnect`, from a `verilog_axi-interconnect-master` source tree referenced by an absolute path — see [§11](#11-known-limitations-and-current-status)), not the `axi_interconnect_wrap_2x8` used elsewhere in this repo
2. It writes an AES-128 key and plaintext, triggers encryption, polls a status register, reads back the ciphertext, then feeds that ciphertext back in for decryption and confirms the original plaintext is recovered
3. This confirms the AES core works behind an AXI4 slave in isolation, but the result has not yet been folded into `soc_project_data buffering`'s crossbar or address map

## 4) Repository layout (current)
```text
Honours_lab_ganesh_317/
├── README.md
├── aes_core-master/                        # vendored AES-128 core + a standalone AXI experiment
│   ├── aes_core.core                       # FuseSoC core file (asics.ws::aes:1.1)
│   ├── rtl/verilog/
│   │   ├── aes_cipher_top.v, aes_inv_cipher_top.v, aes_sbox.v, aes_inv_sbox.v,
│   │   │   aes_key_expand_128.v, aes_rcon.v, timescale.v
│   │   └── axi/aes_axi_slave.v             # experimental AXI4 slave wrapper (not in soc crossbar)
│   ├── bench/verilog/
│   │   ├── test_bench_top.v                # plain AES core bench
│   │   ├── tb_axi_aes.v                    # AES AXI slave bench (standalone)
│   │   └── axi_aes_interconnect_top.v      # AXI interconnect + AES bench (uses a different interconnect IP)
│   ├── sim/axi_aes/run/run.f               # references an absolute path off-repo, see §11
│   ├── sim/rtl_sim/{bin,run}/              # plain-AES-core VCS/Verdi run collateral
│   ├── syn/bin/*.dc                        # Synopsys DC synthesis scripts
│   └── doc/aes.pdf
├── axi-lite_uart-ipcore-develop/            # vendored axi-lite_uart-ipcore (MIT), unmodified
│   ├── LICENSE, Makefile, README.md, project.config
│   ├── documentation/ (axi-uart.png, axi-uart.vsdx)
│   ├── scripts/ (CI/lint/build helper scripts)
│   └── src/
│       ├── include/ (axi_uart.vh, axi_uart_defines.vh)
│       ├── rtl/ (axi_uart_top.v, axi_internal_fifo.v, uart_controller.v,
│       │         uart_receiver.v, uart_transmitter.v, uart_parity_bit_compute.v, tb_axi_uart_top.v)
│       └── sim/ (filelist.f, verdi_config_file)
├── i2c-master/                              # vendored OpenCores I2C master (WISHBONE), unmodified
│   ├── i2c.core                            # FuseSoC core file
│   ├── rtl/verilog/ (i2c_master_top.v, i2c_master_byte_ctrl.v, i2c_master_bit_ctrl.v, i2c_master_defines.v)
│   ├── rtl/vhdl/ (VHDL variant of the same core)
│   ├── bench/verilog/ (tst_bench_top.v, wb_master_model.v, i2c_slave_model.v)
│   ├── sim/i2c_verilog/run/run.f
│   ├── software/include/oc_i2c_master.h
│   └── doc/i2c_specs.pdf
└── soc_project_data buffering/              # the actual interconnect-centric SoC work-in-progress
    ├── Docs/                               # reference docs for the eventual full SoC
    │   ├── Architecture_Introduction_Control_Path.docx
    │   ├── RISC architecture.pdf
    │   ├── RISCV-veer-El2 core/RISC-V_VeeR_EL2_PRM.pdf
    │   ├── aes core/aes.pdf
    │   ├── i2c master/i2c_specs.pdf
    │   └── uart/ (axi-uart.png, axi-uart.vsdx)
    ├── rtl/
    │   ├── priority_encoder.v, arbiter.v, axi_interconnect.v, axi_interconnect_wrap_2x8.v
    │   └── axi-lite_uart-ipcore-develop/    # duplicate nested copy, see §11
    ├── tb files/
    │   ├── axi_slave_dummy.v
    │   └── tb_axi_interconnect_wrap_2x8.v
    ├── run/
    │   ├── Makefile                        # compile / sim / verdi / clean targets
    │   └── run.f                           # VCS filelist for the interconnect TB
    └── scripts/
        └── axi_interconnect_wrap.py        # Jinja2 wrapper generator (also used to build 2x8 above)
```
> Browse live: [`aes_core-master/`](https://github.com/ganesh05-p/Honours_lab_ganesh_317/tree/main/aes_core-master) · [`axi-lite_uart-ipcore-develop/`](https://github.com/ganesh05-p/Honours_lab_ganesh_317/tree/main/axi-lite_uart-ipcore-develop) · [`i2c-master/`](https://github.com/ganesh05-p/Honours_lab_ganesh_317/tree/main/i2c-master) · [`soc_project_data buffering/`](<https://github.com/ganesh05-p/Honours_lab_ganesh_317/tree/main/soc_project_data%20buffering>)

## 5) Module/file responsibility table
| File | Responsibility |
|---|---|
| [`soc_project_data buffering/rtl/priority_encoder.v`](<https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/soc_project_data%20buffering/rtl/priority_encoder.v>) | Generic priority encoder used by the arbiter |
| [`soc_project_data buffering/rtl/arbiter.v`](<https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/soc_project_data%20buffering/rtl/arbiter.v>) | Arbitration between the two slave-side masters |
| [`soc_project_data buffering/rtl/axi_interconnect.v`](<https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/soc_project_data%20buffering/rtl/axi_interconnect.v>) | Core AXI routing/decode/arbitration/response logic |
| [`soc_project_data buffering/rtl/axi_interconnect_wrap_2x8.v`](<https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/soc_project_data%20buffering/rtl/axi_interconnect_wrap_2x8.v>) | Port-expanded wrapper: 2 slave-side + 8 master-side AXI4 ports, per-master base-address/window parameters |
| [`soc_project_data buffering/tb files/axi_slave_dummy.v`](<https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/soc_project_data%20buffering/tb%20files/axi_slave_dummy.v>) | Parameterised single-beat-friendly AXI4 slave stub: 256-word local SRAM, OKAY on every transaction, read-after-write correctness |
| [`soc_project_data buffering/tb files/tb_axi_interconnect_wrap_2x8.v`](<https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/soc_project_data%20buffering/tb%20files/tb_axi_interconnect_wrap_2x8.v>) | Self-checking interconnect testbench: 3 writes + 3 reads through `s00`, pass/fail tally |
| [`i2c-master/rtl/verilog/i2c_master_top.v`](https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/i2c-master/rtl/verilog/i2c_master_top.v) | WISHBONE rev B.2 I2C master core (OpenCores, Richard Herveille) |
| [`aes_core-master/rtl/verilog/aes_cipher_top.v`](https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/aes_core-master/rtl/verilog/aes_cipher_top.v) / [`aes_inv_cipher_top.v`](https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/aes_core-master/rtl/verilog/aes_inv_cipher_top.v) | AES-128 forward/inverse cipher datapaths |
| [`aes_core-master/rtl/verilog/axi/aes_axi_slave.v`](https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/aes_core-master/rtl/verilog/axi/aes_axi_slave.v) | Experimental AXI4 register-mapped AES-128 slave (KEY/DATA_IN/CONTROL/STATUS registers) — standalone, not yet in the SoC crossbar |
| [`axi-lite_uart-ipcore-develop/src/rtl/axi_uart_top.v`](https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/axi-lite_uart-ipcore-develop/src/rtl/axi_uart_top.v) | AXI4-Lite UART core: register file, TX/RX FIFOs |
| [`soc_project_data buffering/run/run.f`](<https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/soc_project_data%20buffering/run/run.f>) | VCS filelist for the interconnect testbench |
| [`soc_project_data buffering/run/Makefile`](<https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/soc_project_data%20buffering/run/Makefile>) | `compile` / `sim` / `verdi` / `clean` targets wrapping the VCS + Verdi flow |
| [`soc_project_data buffering/scripts/axi_interconnect_wrap.py`](<https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/soc_project_data%20buffering/scripts/axi_interconnect_wrap.py>) | Jinja2 generator for `axi_interconnect_wrap_MxN.v` (`-p`, `-n`, `-o`) — used to produce the 2×8 wrapper, and reusable for a wider one later |

## 6) AES AXI experiment (standalone, not yet merged)
`aes_core-master` contains a self-contained AXI4 wrapper around the AES-128 core, register-mapped as follows (from [`aes_axi_slave.v`](https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/aes_core-master/rtl/verilog/axi/aes_axi_slave.v)):

| Offset | Register | Contents |
|---|---|---|
| `0x00`–`0x0C` | `KEY[31:0]`..`KEY[127:96]` | AES-128 key, word-addressed |
| `0x10`–`0x1C` | `DATA_IN[31:0]`..`DATA_IN[127:96]` | Plaintext/ciphertext input |
| `0x20` | `CONTROL` | `[0]`=start encryption, `[1]`=start decryption |
| `0x24` | `STATUS` | `[0]`=encryption done, `[1]`=decryption done |

[`tb_axi_aes.v`](https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/aes_core-master/bench/verilog/tb_axi_aes.v) exercises this wrapper directly, and [`axi_aes_interconnect_top.v`](https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/aes_core-master/bench/verilog/axi_aes_interconnect_top.v) repeats the same encrypt-then-decrypt round trip through a *different* AXI interconnect module (`interconnect`, sourced from a `verilog_axi-interconnect-master` tree referenced by an absolute path in [`sim/axi_aes/run/run.f`](https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/aes_core-master/sim/axi_aes/run/run.f) — see [§11](#11-known-limitations-and-current-status)). Neither testbench uses the `axi_interconnect_wrap_2x8` crossbar in `soc_project_data buffering`, so this AES-behind-AXI result is proven in isolation but not yet part of the main SoC build.

## 7) Simulation prerequisites and exact flows

### Prerequisites
- Synopsys VCS + Verdi
- `soc_project_data buffering/run/Makefile` resolves `VERDI_HOME` from `which verdi` by default; set it explicitly if Verdi isn't on `PATH`

### AXI4 interconnect standalone test (`soc_project_data buffering/run/`)
```bash
cd "soc_project_data buffering/run"
make compile   # vcs -full64 -sverilog ... -f run.f -l compile.log
make sim       # ./simv, generates inter.fsdb
make verdi     # verdi -ssf inter.fsdb &
make clean     # remove csrc/, simv, simv.daidir, novas.*, compile.log, etc.
# or simply:
make           # clean → compile → sim
```

### AES core + AXI wrapper, standalone (`aes_core-master/`)
```bash
cd aes_core-master/sim/rtl_sim/run
vcs -sverilog -full64 -f run.f -o simv_aes && ./simv_aes     # plain AES cipher/inverse-cipher check

cd ../../axi_aes/run
# NOTE: run.f currently references an absolute path from the original
# development machine (see §11) — repoint it at a local checkout of
# verilog_axi-interconnect-master, or at axi_interconnect_wrap_2x8.v, before compiling
vcs -sverilog -full64 -f run.f -o simv_axi_aes && ./simv_axi_aes
```

### UART core, standalone (`axi-lite_uart-ipcore-develop/`)
```bash
cd axi-lite_uart-ipcore-develop
make            # Makefile-driven build/lint/test flow, unmodified from upstream
```

### I2C core, standalone (`i2c-master/`)
```bash
cd i2c-master/sim/i2c_verilog/run
vcs -sverilog -full64 -f run.f -o simv_i2c && ./simv_i2c
```

---

## 8) Verification strategy and covered scenarios

### Interconnect TB ([`tb_axi_interconnect_wrap_2x8.v`](<https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/soc_project_data%20buffering/tb%20files/tb_axi_interconnect_wrap_2x8.v>))
Three directed write/read pairs through the single active master `s00`, with a pass/fail counter:
- **Write 1 / Read 1** — `0x2000_0000` (FIFO) ↔ `0xDEAD_BEEF`
- **Write 2 / Read 2** — `0x3000_0000` (DMA Controller) ↔ `0xCAFE_BABE`
- **Write 3 / Read 3** — `0x4000_0000` (Interrupt Controller) ↔ `0x1234_5678`

The second master port (`s01`) and the other five dummy-slave ports (IMEM, DMEM, UART, TIMER, GPIO) are instantiated by the wrapper but not exercised by this TB yet — a natural next step is extending the test to cover dual-master arbitration and full 8-port coverage.

### AES AXI experiment ([`tb_axi_aes.v`](https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/aes_core-master/bench/verilog/tb_axi_aes.v), [`axi_aes_interconnect_top.v`](https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/aes_core-master/bench/verilog/axi_aes_interconnect_top.v))
Writes an AES-128 key and plaintext over AXI, triggers encryption, polls `STATUS`, reads back the ciphertext; feeds the ciphertext back in, triggers decryption, and confirms the original plaintext is recovered — first against the bare AXI slave, then again through a separate AXI interconnect instance. Both print PASS/FAIL per phase.

### Vendored-core benches (unmodified from upstream)
- [`i2c-master/bench/verilog/tst_bench_top.v`](https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/i2c-master/bench/verilog/tst_bench_top.v) — WISHBONE-level I2C master test with `wb_master_model.v` / `i2c_slave_model.v`
- [`aes_core-master/bench/verilog/test_bench_top.v`](https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/aes_core-master/bench/verilog/test_bench_top.v) — plain AES cipher/inverse-cipher core test, no AXI involved
- [`axi-lite_uart-ipcore-develop/src/rtl/tb_axi_uart_top.v`](https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/axi-lite_uart-ipcore-develop/src/rtl/tb_axi_uart_top.v) — the UART IP's own bench, run through its Makefile

## 9) Wrapper generator usage (`scripts/axi_interconnect_wrap.py`)
Dependency: Python package `jinja2`.
```bash
python "soc_project_data buffering/scripts/axi_interconnect_wrap.py" -p 2 8 -n axi_interconnect_wrap_2x8 -o axi_interconnect_wrap_2x8.v
```
`-p` accepts one value (equal master/slave count) or two values (`m n`) — this is how `axi_interconnect_wrap_2x8.v` itself was generated, and the same script can regenerate a wider wrapper (e.g. `-p 2 11`) once the I2C/AES/UART AXI wrappers and a VeeR-driven master are ready to attach.

## 10) Imported IP notes (I2C / AES / UART) — sources and references

### I2C master — [`i2c-master/`](https://github.com/ganesh05-p/Honours_lab_ganesh_317/tree/main/i2c-master)
| | |
|---|---|
| **Upstream source** | [OpenCores I2C-Master Core](https://opencores.org/projects/i2c) — WISHBONE rev B.2 compliant I2C master, by Richard Herveille |
| **Datasheet** | [`i2c-master/doc/i2c_specs.pdf`](https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/i2c-master/doc/i2c_specs.pdf) |
| **Status in this repo** | RTL (Verilog + VHDL), WISHBONE-level bench, and a software header imported verbatim; **no AXI bridge yet** |

### AES-128 core — [`aes_core-master/`](https://github.com/ganesh05-p/Honours_lab_ganesh_317/tree/main/aes_core-master)
| | |
|---|---|
| **Upstream source** | `asics.ws::aes:1.1` per the committed [`aes_core.core`](https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/aes_core-master/aes_core.core) FuseSoC file (Secworks-style hardware AES core), extended here with an experimental AXI slave wrapper (`aes_axi_slave.v`) |
| **Datasheet** | [`aes_core-master/doc/aes.pdf`](https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/aes_core-master/doc/aes.pdf) |
| **Status in this repo** | RTL, FuseSoC core file, sky130 synthesis scripts, and RTL-sim run collateral included; AXI wrapper + AXI testbenches present but standalone (see [§6](#6-aes-axi-experiment-standalone-not-yet-merged)) |

### AXI-Lite UART IP — [`axi-lite_uart-ipcore-develop/`](https://github.com/ganesh05-p/Honours_lab_ganesh_317/tree/main/axi-lite_uart-ipcore-develop)
| | |
|---|---|
| **Upstream source** | [`axi-lite_uart-ipcore`](https://github.com/m4j0rt0m/axi-lite_uart-ipcore) by Abraham J. Ruiz R. (`m4j0rt0m`) |
| **License** | MIT — [`axi-lite_uart-ipcore-develop/LICENSE`](https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/axi-lite_uart-ipcore-develop/LICENSE) |
| **Diagram** | [`axi-lite_uart-ipcore-develop/documentation/axi-uart.png`](https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/axi-lite_uart-ipcore-develop/documentation/axi-uart.png) |
| **Status in this repo** | Vendored as-is (RTL, headers, TB, Makefile-based build, CI workflow configs, license); **no AXI4-full wrapper yet** |

### VeeR EL2 RISC-V core — referenced in the project title and documentation, not yet imported
The reference PRM ([`soc_project_data buffering/Docs/RISCV-veer-El2 core/RISC-V_VeeR_EL2_PRM.pdf`](<https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/soc_project_data%20buffering/Docs/RISCV-veer-El2%20core/RISC-V_VeeR_EL2_PRM.pdf>)) for [chipsalliance/Cores-VeeR-EL2](https://github.com/chipsalliance/Cores-VeeR-EL2) is already checked in, but no core source tree, generated config headers, or CPU-facing SoC top exist in this repo yet — this is the largest piece of outstanding work implied by the project's title.

### Interconnect RTL — [`soc_project_data buffering/rtl/`](<https://github.com/ganesh05-p/Honours_lab_ganesh_317/tree/main/soc_project_data%20buffering/rtl>)
`axi_interconnect.v`, `axi_interconnect_wrap_2x8.v`, `arbiter.v`, and `priority_encoder.v` are Alex Forencich's `verilog-axi` crossbar components (MIT-style permissive license header in each file), instantiated and wrapped for this project's port count via the wrapper generator.

---

## 11) Known limitations and current status
- **No VeeR EL2 RISC-V core in the repo** — the project title and the checked-in PRM describe the intended end state, but `Cores-VeeR-EL2/` does not exist here yet, and there is no CPU-facing SoC top module
- **No unified `soc_top.v`** — the interconnect is only tested against generic dummy slaves; none of I2C, AES, or UART are actually wired onto `axi_interconnect_wrap_2x8`
- **I2C has no AXI bridge** — `i2c-master/` is vendored WISHBONE RTL only; an `axi_to_wb_bridge`-style module (as would be needed to put I2C on the crossbar) has not been written
- **UART has no AXI4-full wrapper** — `axi-lite_uart-ipcore-develop/` is vendored AXI4-Lite RTL only; an `axi_uart_slave.v`-style AXI4-full-to-Lite wrapper has not been written
- **AES's AXI integration is proven only in isolation** — `aes_axi_slave.v` and its testbenches sit under `aes_core-master/`, tested against a *different* interconnect module (`verilog_axi-interconnect-master`) than the one used elsewhere in this repo, and have not been merged into `soc_project_data buffering`
- `aes_core-master/sim/axi_aes/run/run.f` references an **absolute path on the original author's machine** (`/home/student/Documents/317/IPs/verilog_axi-interconnect-master/interconnect.v`) — this will not resolve on a fresh clone; repoint it locally before running that flow
- `soc_project_data buffering/rtl/axi-lite_uart-ipcore-develop/` is a **duplicate nested copy** of the top-level `axi-lite_uart-ipcore-develop/` and is not referenced by `run/run.f` — safe to remove once confirmed unused
- The interconnect testbench exercises only one of the two available master ports (`s01` is idle) and only 3 of the 8 slave ports — dual-master arbitration and full port coverage are not yet tested
- No top-level SoC block diagram is currently checked into `soc_project_data buffering/Docs/`
- No `LICENSE` file is currently present at the repository root — the vendored sub-projects carry their own licenses/notices (MIT for the UART IP, OpenCores' permissive notice for I2C, and a similar permissive notice for the AES core and the Forencich interconnect files) that should be reconciled if this repo is distributed
- The repository's GitHub "About" field currently has no description or topics set

## 12) Contribution/dev guidance and provenance notes
- Prefer modifying source under `soc_project_data buffering/rtl/`, `soc_project_data buffering/tb files/`, `soc_project_data buffering/run/`, and root-level docs, while treating the vendored third-party IP trees (`i2c-master/`, `aes_core-master/`, `axi-lite_uart-ipcore-develop/`) as upstream unless intentionally patching them
- License/provenance signals in-tree:
  - MIT license file in the UART IP subtree ([`axi-lite_uart-ipcore-develop/LICENSE`](https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/axi-lite_uart-ipcore-develop/LICENSE))
  - OpenCores/Richard Herveille copyright header in `i2c_master_top.v` ("may be used and distributed without restriction provided that this copyright statement is not removed")
  - OpenCores/Rudolf Usselmann copyright header in `aes_cipher_top.v`, under the same permissive terms
  - FuseSoC core metadata (`aes_core.core`, `i2c.core`) for the AES and I2C cores
  - Permissive (MIT-style) copyright header from Alex Forencich in `axi_interconnect.v`, `axi_interconnect_wrap_2x8.v`, `arbiter.v`, `priority_encoder.v`
- The next practical milestones, in dependency order, are: (1) write an `axi_to_wb_bridge` for I2C and an `axi_uart_slave` full-to-Lite wrapper for UART, mirroring the pattern already proven for AES in `aes_axi_slave.v`; (2) fold all three peripherals onto `axi_interconnect_wrap_2x8` (or a regenerated wider wrapper) in place of the dummy slaves, producing a real `soc_top.v`; (3) only then begin VeeR EL2 import and CPU-driven integration
- Before relying on the AES AXI experiment, either vendor `verilog_axi-interconnect-master` properly into the repo to fix the broken absolute path in `sim/axi_aes/run/run.f`, or re-target that testbench at `axi_interconnect_wrap_2x8.v` directly so all AXI work in the repo shares one interconnect implementation

## 13) Quick reference commands
```bash
# AXI4 interconnect standalone test (2 masters x 8 dummy slaves)
cd "soc_project_data buffering/run"
make

# Plain AES-128 core test (no AXI)
cd aes_core-master/sim/rtl_sim/run
vcs -sverilog -full64 -f run.f -o simv_aes && ./simv_aes

# AES behind AXI, standalone (fix the absolute path in run.f first — see §11)
cd aes_core-master/sim/axi_aes/run
vcs -sverilog -full64 -f run.f -o simv_axi_aes && ./simv_axi_aes

# I2C core WISHBONE-level test
cd i2c-master/sim/i2c_verilog/run
vcs -sverilog -full64 -f run.f -o simv_i2c && ./simv_i2c

# AXI-Lite UART IP's own build/test flow
cd axi-lite_uart-ipcore-develop && make

# Wrapper generation (requires jinja2)
python "soc_project_data buffering/scripts/axi_interconnect_wrap.py" -p 2 8 -n axi_interconnect_wrap_2x8 -o axi_interconnect_wrap_2x8.v
```

---

## Documents Index
| File | Type | Description |
|---|---|---|
| [`soc_project_data buffering/Docs/Architecture_Introduction_Control_Path.docx`](<https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/soc_project_data%20buffering/Docs/Architecture_Introduction_Control_Path.docx>) | Word doc | Project architecture / control-path introduction |
| [`soc_project_data buffering/Docs/RISC architecture.pdf`](<https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/soc_project_data%20buffering/Docs/RISC%20architecture.pdf>) | PDF | RISC architecture background reading |
| [`soc_project_data buffering/Docs/RISCV-veer-El2 core/RISC-V_VeeR_EL2_PRM.pdf`](<https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/soc_project_data%20buffering/Docs/RISCV-veer-El2%20core/RISC-V_VeeR_EL2_PRM.pdf>) | PDF | VeeR EL2 core Programmer's Reference Manual (target core, not yet imported) |
| [`soc_project_data buffering/Docs/aes core/aes.pdf`](<https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/soc_project_data%20buffering/Docs/aes%20core/aes.pdf>) | PDF | AES core datasheet/design documentation |
| [`soc_project_data buffering/Docs/i2c master/i2c_specs.pdf`](<https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/soc_project_data%20buffering/Docs/i2c%20master/i2c_specs.pdf>) | PDF | I2C master core specification |
| [`soc_project_data buffering/Docs/uart/axi-uart.png`](<https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/soc_project_data%20buffering/Docs/uart/axi-uart.png>) | Image | AXI-Lite UART IP block diagram (embedded above) |
| [`soc_project_data buffering/Docs/uart/axi-uart.vsdx`](<https://github.com/ganesh05-p/Honours_lab_ganesh_317/blob/main/soc_project_data%20buffering/Docs/uart/axi-uart.vsdx>) | Visio | Editable source diagram for the UART block diagram |

---

<p align="center"><sub>RISC-V VeeR EL2 Based Real-Time Data Buffering SoC — AXI4 interconnect proven, I2C / AES-128 / UART vendored and being integrated, VeeR EL2 CPU integration planned · ganesh05-p</sub></p>
