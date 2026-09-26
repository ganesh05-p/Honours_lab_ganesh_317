# RISC-V VeeR EL2 Based Real-Time Data Buffering SoC

A RISC-V based System-on-Chip (SoC) project focused on **real-time data buffering, DMA-based data transfer, interrupt management, and processor-controlled peripheral communication**.

The SoC is based on the **VeeR EL2 RISC-V processor** and is intended for a **real-time industrial motor vibration-monitoring application using a 3-axis accelerometer**.

---

## 🚀 Current Progress

The current integration work has reached:

```text
VeeR EL2 RISC-V
       │
       ▼
System Interconnect
       │
       ▼
UART

Completed
- VeeR EL2 RISC-V processor integration
- System Interconnect integration
- VeeR EL2 to UART communication path
- UART IP development and verification
Next
- Instruction Memory integration
- Data Memory integration
- Timer integration
- GPIO integration
- FIFO integration
- DMA Controller integration
- Interrupt Controller integration
- Complete SoC verification

🎯 Project Objective
The objective is to design a RISC-V based SoC capable of receiving continuous real-time data, temporarily buffering it, transferring it to memory using DMA, handling important events through interrupts, and reporting information through UART.
The target application is:
Real-Time Industrial Motor Vibration Monitoring using a 3-axis accelerometer.
For RTL verification, the accelerometer output is modeled through the testbench using:
