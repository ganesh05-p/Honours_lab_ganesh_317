// =============================================================================
// Header: soc_regs.h
// Project: RISC-V VeeR EL2 Real-Time Data Buffering SoC
// Description: Memory map, register structures, and hardware bitfield definitions
// =============================================================================

#ifndef SOC_REGS_H
#define SOC_REGS_H

#include <stdint.h>

// -----------------------------------------------------------------------------
// Base Addresses
// -----------------------------------------------------------------------------
// AXI Interconnect Apertures (16 MiB window per slave port):
#define ADDR_IMEM_BASE          0x00000000UL  // S0: AXI IMEM (64 KiB SRAM)
#define ADDR_DMEM_BASE          0x10000000UL  // S1: AXI DMEM (64 KiB SRAM, DMA Target)
#define ADDR_UART_BASE          0x20000000UL  // S2: AXI-Lite UART
#define ADDR_TIMER_BASE         0x30000000UL  // S3: Timer Peripheral
#define ADDR_GPIO_BASE          0x40000000UL  // S4: GPIO Peripheral
#define ADDR_FIFO_BASE          0x50000000UL  // S5: Real-Time Buffer FIFO
#define ADDR_DMA_BASE           0x60000000UL  // S6: DMA Controller Config
#define ADDR_PLIC_BASE          0x70000000UL  // S7: Platform-Level Interrupt Controller

// VeeR EL2 Closely Coupled Memories (Core Local):
#define ADDR_ICCM_BASE          0xEE000000UL  // 64 KiB ICCM (Executable Boot Region)
#define ADDR_DCCM_BASE          0xF0040000UL  // 64 KiB DCCM (Core Local Stack/Data)

// Direct register access macro
#define REG32(addr)             (*(volatile uint32_t *)(addr))


// -----------------------------------------------------------------------------
// Real-Time Buffer FIFO Registers
// -----------------------------------------------------------------------------
#define FIFO_REG_DATA           (ADDR_FIFO_BASE + 0x00UL)
#define FIFO_REG_STATUS         (ADDR_FIFO_BASE + 0x04UL)
#define FIFO_REG_COUNT          (ADDR_FIFO_BASE + 0x08UL)
#define FIFO_REG_CTRL           (ADDR_FIFO_BASE + 0x0CUL)
#define FIFO_REG_PEAK           (ADDR_FIFO_BASE + 0x10UL)

// FIFO Status Bits
#define FIFO_STATUS_EMPTY       (1U << 0)
#define FIFO_STATUS_FULL        (1U << 1)
#define FIFO_STATUS_ALMOST_EMT  (1U << 2)
#define FIFO_STATUS_ALMOST_FUL  (1U << 3)
#define FIFO_STATUS_THRESH_HIT  (1U << 4)
#define FIFO_STATUS_OVF_STICKY  (1U << 5)
#define FIFO_STATUS_UDF_STICKY  (1U << 6)

// FIFO Control Bits
#define FIFO_CTRL_FLUSH         (1U << 0)
#define FIFO_CTRL_IRQ_EN        (1U << 1)
#define FIFO_CTRL_DREQ_EN       (1U << 2)
#define FIFO_CTRL_THRESH_SHIFT  8
#define FIFO_CTRL_STREAM_EN     (1U << 16)

// -----------------------------------------------------------------------------
// DMA Controller Registers
// -----------------------------------------------------------------------------
#define DMA_CH0_CTRL            (ADDR_DMA_BASE + 0x000UL)
#define DMA_CH0_STATUS          (ADDR_DMA_BASE + 0x004UL)
#define DMA_CH0_SRC             (ADDR_DMA_BASE + 0x008UL)
#define DMA_CH0_DST             (ADDR_DMA_BASE + 0x00CUL)
#define DMA_CH0_LEN             (ADDR_DMA_BASE + 0x010UL)
#define DMA_CH0_DESC            (ADDR_DMA_BASE + 0x014UL)
#define DMA_CH0_CUR_SRC         (ADDR_DMA_BASE + 0x018UL)
#define DMA_CH0_CUR_DST         (ADDR_DMA_BASE + 0x01CUL)

#define DMA_REG_IRQ_STAT        (ADDR_DMA_BASE + 0x100UL)
#define DMA_REG_IRQ_EN          (ADDR_DMA_BASE + 0x104UL)
#define DMA_REG_IRQ_CLR         (ADDR_DMA_BASE + 0x108UL)
#define DMA_REG_VERSION         (ADDR_DMA_BASE + 0x10CUL)

// DMA Channel Control Bits
#define DMA_CTRL_EN             (1U << 0)
#define DMA_CTRL_START          (1U << 1)
#define DMA_CTRL_ABORT          (1U << 2)
#define DMA_CTRL_SG_EN          (1U << 3)
#define DMA_XFER_MEM2MEM        (0x0U << 4)
#define DMA_XFER_MEM2PERIPH     (0x1U << 4)
#define DMA_XFER_PERIPH2MEM     (0x2U << 4)

// DMA Status Codes
#define DMA_STAT_IDLE           0U
#define DMA_STAT_DESC_FETCH     1U
#define DMA_STAT_READ           2U
#define DMA_STAT_WRITE          3U
#define DMA_STAT_DONE           4U
#define DMA_STAT_ERROR          5U

// -----------------------------------------------------------------------------
// PLIC Interrupt Controller Registers
// -----------------------------------------------------------------------------
#define PLIC_PRIO_DMA           (ADDR_PLIC_BASE + 0x0004UL) // Source 1: DMA
#define PLIC_PRIO_FIFO          (ADDR_PLIC_BASE + 0x0008UL) // Source 2: FIFO
#define PLIC_PRIO_UART          (ADDR_PLIC_BASE + 0x000CUL) // Source 3: UART

#define PLIC_PENDING_0          (ADDR_PLIC_BASE + 0x1000UL)
#define PLIC_ENABLE_TGT0        (ADDR_PLIC_BASE + 0x2000UL)
#define PLIC_THRESH_TGT0        (ADDR_PLIC_BASE + 0x200000UL)
#define PLIC_CLAIM_TGT0         (ADDR_PLIC_BASE + 0x200004UL)

// -----------------------------------------------------------------------------
// UART Controller Registers
// -----------------------------------------------------------------------------
#define UART_REG_DATA           (ADDR_UART_BASE + 0x00UL)
#define UART_REG_STATUS         (ADDR_UART_BASE + 0x04UL)
#define UART_REG_CTRL           (ADDR_UART_BASE + 0x08UL)
#define UART_REG_BAUD           (ADDR_UART_BASE + 0x0CUL)

// -----------------------------------------------------------------------------
// Timer Controller Registers (S3 at 0x3000_0000)
// -----------------------------------------------------------------------------
#define TIMER_REG_CTRL          (ADDR_TIMER_BASE + 0x00UL)
#define TIMER_REG_VAL           (ADDR_TIMER_BASE + 0x04UL)
#define TIMER_REG_CMP           (ADDR_TIMER_BASE + 0x08UL)
#define TIMER_REG_STATUS        (ADDR_TIMER_BASE + 0x0CUL)

#define TIMER_CTRL_EN           (1U << 0)
#define TIMER_CTRL_AUTO_RELOAD  (1U << 1)
#define TIMER_CTRL_IRQ_EN       (1U << 2)
#define TIMER_STATUS_MATCH      (1U << 0)

// -----------------------------------------------------------------------------
// GPIO Controller Registers (S4 at 0x4000_0000)
// -----------------------------------------------------------------------------
#define GPIO_REG_DATA_IN        (ADDR_GPIO_BASE + 0x00UL)
#define GPIO_REG_DATA_OUT       (ADDR_GPIO_BASE + 0x04UL)
#define GPIO_REG_DIR            (ADDR_GPIO_BASE + 0x08UL)
#define GPIO_REG_SET            (ADDR_GPIO_BASE + 0x0CUL)
#define GPIO_REG_CLEAR          (ADDR_GPIO_BASE + 0x10UL)

#endif // SOC_REGS_H
