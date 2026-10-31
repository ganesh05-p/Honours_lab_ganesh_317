// =============================================================================
// Filelist: soc_top.f
// Project : RISC-V VeeR EL2 Real-Time Data Buffering SoC (Project A)
// =============================================================================

// Includes and Preprocessor
+incdir+../rtl/Cores-VeeR-EL2/snapshots/default
+incdir+../rtl/Cores-VeeR-EL2/design/include
+incdir+../rtl/Cores-VeeR-EL2/design/lib
+incdir+../rtl/Cores-VeeR-EL2/design/dmi
+incdir+../rtl/axi-lite_uart-ipcore-develop/src/include
+define+RV_BUILD_AXI4

// VeeR EL2 Package and flist
../rtl/Cores-VeeR-EL2/design/include/el2_def.sv
-f ../rtl/Cores-VeeR-EL2/design/flist

// Interconnect RTL
../rtl/priority_encoder.v
../rtl/arbiter.v
../rtl/axi_interconnect.v
../rtl/axi_interconnect_wrap_2x8.v

// Adapters
../rtl/adapters/axi4_64_to_32_adapter.sv
../rtl/adapters/axi4_to_axilite_32_adapter.sv
../rtl/adapters/axi4_to_dma_reg_adapter.sv
../rtl/adapters/axi4_to_plic_bus_adapter.sv

// FIFO Peripheral
../rtl/fifo/axi_data_buffer_fifo.sv

// DMA Controller
../rtl/dma/dma_pkg.sv
../rtl/dma/dma_fifo.sv
../rtl/dma/dma_reg_file.sv
../rtl/dma/dma_channel.sv
../rtl/dma/dma_arbiter.sv
../rtl/dma/dma_axi_master.sv
../rtl/dma/dma_top.sv
../rtl/wrappers/dma_axi_master_wrapper.sv

// Interrupt Controller (PLIC)
../rtl/interrupt_controller/plic_pkg.sv
../rtl/interrupt_controller/plic_gateway.sv
../rtl/interrupt_controller/plic_target.sv
../rtl/interrupt_controller/plic_priority_resolver.sv
../rtl/interrupt_controller/plic_reg_file.sv
../rtl/interrupt_controller/plic_top.sv

// UART IP Core
../rtl/axi-lite_uart-ipcore-develop/src/rtl/axi_internal_fifo.v
../rtl/axi-lite_uart-ipcore-develop/src/rtl/uart_controller.v
../rtl/axi-lite_uart-ipcore-develop/src/rtl/uart_parity_bit_compute.v
../rtl/axi-lite_uart-ipcore-develop/src/rtl/uart_receiver.v
../rtl/axi-lite_uart-ipcore-develop/src/rtl/uart_transmitter.v
../rtl/axi-lite_uart-ipcore-develop/src/rtl/axi_uart_top.v

// Memory and Peripherals
../rtl/memory/axi_ram.v
../rtl/timer/axi_timer.sv
../rtl/gpio/axi_gpio.sv

// Top-Level and Testbench
../rtl/soc_data_buffering_top.sv
"../tb files/tb_soc_data_buffering_top.sv"
