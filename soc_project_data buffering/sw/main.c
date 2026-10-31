// =============================================================================
// Program : main.c
// Project : RISC-V VeeR EL2 Real-Time Data Buffering SoC
// Task    : Basic Addition Test (10 + 20 + 30 = 60)
// =============================================================================

#include "soc_regs.h"
#include <stdint.h>

// -----------------------------------------------------------------------------
// UART Helper Functions
// Connected to AXI-Lite UART IP (S2 @ 0x2000_0000)
// -----------------------------------------------------------------------------

// Output single character over UART THR (0x2000_0000)
void uart_putc(char c) {
    REG32(UART_REG_DATA) = (uint32_t)c;
    // Small delay for serial pacing
    for (volatile int i = 0; i < 2; i++);
}

// Output null-terminated string over UART
void uart_puts(const char *str) {
    while (*str) {
        uart_putc(*str++);
    }
}

// Output 32-bit integer as decimal string over UART
void uart_print_dec(uint32_t val) {
    char buf[12];
    int i = 0;
    if (val == 0) {
        uart_putc('0');
        return;
    }
    while (val > 0) {
        buf[i++] = (val % 10) + '0';
        val /= 10;
    }
    while (i > 0) {
        uart_putc(buf[--i]);
    }
}

// -----------------------------------------------------------------------------
// Main Firmware Entry Point
// -----------------------------------------------------------------------------
int main(void) {
    // =========================================================================
    // Test 1: Basic Addition Test (10 + 20 + 30 = 60)
    // =========================================================================
    volatile int a = 10;
    volatile int b = 20;
    volatile int c = 30;

    volatile int result = a + b + c;

    // Write final result (60) to Data Memory (DMEM: S1 @ 0x1000_0000)
    REG32(ADDR_DMEM_BASE) = (uint32_t)result;

    // Synchronize memory and allow DMEM write to commit
    asm volatile("fence rw, rw" ::: "memory");
    for (volatile int i = 0; i < 10; i++);

    // =========================================================================
    // Test 2: Peripheral-Path Test (CPU -> AXI Interconnect -> UART Peripheral)
    // Write known verification pattern 0x55 ('U') to UART THR (0x2000_0000)
    // =========================================================================
    REG32(UART_REG_DATA) = 0x55U;

    // Pacing delay and memory fence to prevent store merging with subsequent prints
    for (volatile int i = 0; i < 20; i++);
    asm volatile("fence rw, rw" ::: "memory");

    // -------------------------------------------------------------------------
    // Report Output via UART (S2 @ 0x2000_0000)
    // Transmit characters directly as register immediates
    // -------------------------------------------------------------------------
    uart_putc('\n');
    uart_putc('1');
    uart_putc('0');
    uart_putc(' ');
    uart_putc('+');
    uart_putc(' ');
    uart_putc('2');
    uart_putc('0');
    uart_putc(' ');
    uart_putc('+');
    uart_putc(' ');
    uart_putc('3');
    uart_putc('0');
    uart_putc(' ');
    uart_putc('=');
    uart_putc(' ');
    uart_print_dec((uint32_t)result);
    uart_putc('\n');

    if (result == 60) {
        uart_putc('T');
        uart_putc('E');
        uart_putc('S');
        uart_putc('T');
        uart_putc(' ');
        uart_putc('P');
        uart_putc('A');
        uart_putc('S');
        uart_putc('S');
        uart_putc('\n');
    } else {
        uart_putc('T');
        uart_putc('E');
        uart_putc('S');
        uart_putc('T');
        uart_putc(' ');
        uart_putc('F');
        uart_putc('A');
        uart_putc('I');
        uart_putc('L');
        uart_putc('\n');
    }

    return (result == 60) ? 0 : 1;
}
